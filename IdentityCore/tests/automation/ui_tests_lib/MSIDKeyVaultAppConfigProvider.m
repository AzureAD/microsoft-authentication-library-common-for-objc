// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDKeyVaultAppConfigProvider.h"
#import "MSIDKeyVaultCredentialProvider.h"
#import "MSIDTestAutomationApplication.h"

#if __has_include("MSIDAutomation-Swift.h")
#import "MSIDAutomation-Swift.h"
#elif __has_include("IdentityCore-Swift.h")
#import "IdentityCore-Swift.h"
#else
@class KeyvaultAuthentication;
@class Secret;
#endif

@interface MSIDKeyVaultAppConfigProvider ()

@property (nonatomic, copy) NSString *keyVaultURL;
@property (nonatomic, strong) MSIDKeyVaultCredentialProvider *credentialProvider;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *cachedAppConfigs;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

@end

@implementation MSIDKeyVaultAppConfigProvider

- (instancetype)initWithKeyVaultURL:(NSString *)keyVaultURL
                 credentialProvider:(MSIDKeyVaultCredentialProvider *)credentialProvider
{
    self = [super init];
    if (self)
    {
        _keyVaultURL = [keyVaultURL copy];
        _credentialProvider = credentialProvider;
        _cacheQueue = dispatch_queue_create("com.microsoft.MSIDKeyVaultAppConfigProvider.cache", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)hasCachedAppConfigs
{
    __block BOOL hasCached;
    dispatch_sync(self.cacheQueue, ^{
        hasCached = (self.cachedAppConfigs != nil);
    });
    return hasCached;
}

- (void)clearCache
{
    dispatch_sync(self.cacheQueue, ^{
        self.cachedAppConfigs = nil;
    });
    NSLog(@"[MSIDKeyVaultAppConfigProvider] Cache cleared");
}

- (void)fetchAppConfigsWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    NSLog(@"[MSIDKeyVaultAppConfigProvider] Fetching app configurations from Key Vault: %@", self.keyVaultURL);

    KeyvaultAuthentication *auth = [self.credentialProvider getKeyvaultAuthentication];

    if (!auth)
    {
        NSError *error = [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No authentication available for Key Vault"}];
        completionHandler(error);
        return;
    }

    NSLog(@"[MSIDKeyVaultAppConfigProvider] Got KeyvaultAuthentication using %@",
          MSIDKeyVaultAuthMethodName(self.credentialProvider.lastSuccessfulMethod));

    NSURL *url = [NSURL URLWithString:self.keyVaultURL];
    if (!url)
    {
        NSError *error = [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid Key Vault URL"}];
        completionHandler(error);
        return;
    }

    [Secret getWithUrl:url completion:^(NSError * _Nullable fetchError, Secret * _Nullable secret) {
        if (fetchError || !secret)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = fetchError ?: [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                                                   code:-1
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to fetch secret from Key Vault"}];
                completionHandler(error);
            });
            return;
        }

        NSString *secretValue = secret.value;
        NSData *jsonData = [secretValue dataUsingEncoding:NSUTF8StringEncoding];
        NSError *parseError = nil;
        NSDictionary *appConfigsJSON = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                       options:0
                                                                         error:&parseError];

        if (parseError || ![appConfigsJSON isKindOfClass:[NSDictionary class]])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = parseError ?: [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                                                   code:-1
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Could not parse app configurations JSON from Key Vault secret"}];
                completionHandler(error);
            });
            return;
        }

        dispatch_sync(self.cacheQueue, ^{
            self.cachedAppConfigs = appConfigsJSON;
        });

        NSLog(@"[MSIDKeyVaultAppConfigProvider] Successfully cached %lu app configuration types", (unsigned long)appConfigsJSON.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil);
        });
    }];
}

- (MSIDTestAutomationApplication *)appConfigForKey:(NSString *)appConfigKey error:(NSError *__autoreleasing *)error
{
    __block NSDictionary *appConfigs;
    dispatch_sync(self.cacheQueue, ^{
        appConfigs = self.cachedAppConfigs;
    });

    if (!appConfigs)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"App configurations not loaded. Call fetchAppConfigsWithCompletionHandler first."}];
        }
        return nil;
    }

    NSDictionary *appConfigData = appConfigs[appConfigKey];
    if (!appConfigData)
    {
        if (error)
        {
            NSMutableArray *configKeys = [NSMutableArray array];
            for (NSString *key in [appConfigs allKeys])
            {
                if (![key hasPrefix:@"__comment"])
                {
                    [configKeys addObject:key];
                }
            }
            NSString *availableKeys = [configKeys componentsJoinedByString:@", "];
            NSString *message = [NSString stringWithFormat:@"App config key '%@' not found in Key Vault JSON. Available keys: %@",
                                 appConfigKey, availableKeys];
            *error = [NSError errorWithDomain:@"MSIDKeyVaultAppConfigProvider"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSError *createError = nil;
    MSIDTestAutomationApplication *app = [[MSIDTestAutomationApplication alloc] initWithJSONDictionary:appConfigData
                                                                                                error:&createError];

    if (createError)
    {
        NSLog(@"[MSIDKeyVaultAppConfigProvider] Failed to create app config from JSON: %@", createError.localizedDescription);
        if (error)
        {
            *error = createError;
        }
        return nil;
    }

    return app;
}

@end
