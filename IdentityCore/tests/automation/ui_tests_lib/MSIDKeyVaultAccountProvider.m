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

#import "MSIDKeyVaultAccountProvider.h"
#import "MSIDKeyVaultCredentialProvider.h"
#import "MSIDTestAutomationAccount.h"

#if __has_include("MSIDAutomation-Swift.h")
#import "MSIDAutomation-Swift.h"
#elif __has_include("IdentityCore-Swift.h")
#import "IdentityCore-Swift.h"
#else
@class KeyvaultAuthentication;
@class Secret;
#endif

@interface MSIDKeyVaultAccountProvider ()

@property (nonatomic, copy) NSString *keyVaultURL;
@property (nonatomic, strong) MSIDKeyVaultCredentialProvider *credentialProvider;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *cachedAccounts;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

@end

@implementation MSIDKeyVaultAccountProvider

- (instancetype)initWithKeyVaultURL:(NSString *)keyVaultURL
                 credentialProvider:(MSIDKeyVaultCredentialProvider *)credentialProvider
{
    self = [super init];
    if (self) {
        _keyVaultURL = [keyVaultURL copy];
        _credentialProvider = credentialProvider;
        _cacheQueue = dispatch_queue_create("com.microsoft.MSIDKeyVaultAccountProvider.cache", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)hasCachedAccounts
{
    __block BOOL hasCached;
    dispatch_sync(self.cacheQueue, ^{
        hasCached = (self.cachedAccounts != nil);
    });
    return hasCached;
}

- (void)clearCache
{
    dispatch_sync(self.cacheQueue, ^{
        self.cachedAccounts = nil;
    });
    NSLog(@"[MSIDKeyVaultAccountProvider] Cache cleared");
}

- (void)fetchAccountsWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    NSLog(@"[MSIDKeyVaultAccountProvider] Fetching accounts from Key Vault: %@", self.keyVaultURL);
    
    // Get the KeyvaultAuthentication instance
    KeyvaultAuthentication *auth = [self.credentialProvider getKeyvaultAuthentication];
    
    if (!auth) {
        NSError *error = [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No authentication available for Key Vault"}];
        completionHandler(error);
        return;
    }
    
    NSLog(@"[MSIDKeyVaultAccountProvider] Got KeyvaultAuthentication using %@",
          MSIDKeyVaultAuthMethodName(self.credentialProvider.lastSuccessfulMethod));
    
    // Use the Secret class to fetch from Key Vault
    // Secret.get(url:completion:) is the Swift async API
    NSURL *url = [NSURL URLWithString:self.keyVaultURL];
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid Key Vault URL"}];
        completionHandler(error);
        return;
    }
    
    [Secret getWithUrl:url completion:^(NSError * _Nullable fetchError, Secret * _Nullable secret) {
        if (fetchError || !secret) {
            NSError *error = fetchError ?: [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                                               code:-1
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to fetch secret from Key Vault"}];
            completionHandler(error);
            return;
        }
        
        // Parse the secret value as JSON
        NSString *secretValue = secret.value;
        NSData *jsonData = [secretValue dataUsingEncoding:NSUTF8StringEncoding];
        NSError *parseError = nil;
        NSDictionary *accountsJSON = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                     options:0
                                                                       error:&parseError];
        
        if (parseError || ![accountsJSON isKindOfClass:[NSDictionary class]]) {
            NSError *error = parseError ?: [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                                               code:-1
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Could not parse accounts JSON from Key Vault secret"}];
            completionHandler(error);
            return;
        }
        
        // Cache the accounts
        dispatch_sync(self.cacheQueue, ^{
            self.cachedAccounts = accountsJSON;
        });
        
        NSLog(@"[MSIDKeyVaultAccountProvider] Successfully cached %lu account types", (unsigned long)accountsJSON.count);
        
        completionHandler(nil);
    }];
}

- (MSIDTestAutomationAccount *)accountForType:(NSString *)accountType error:(NSError *__autoreleasing *)error
{
    __block NSDictionary *accounts;
    dispatch_sync(self.cacheQueue, ^{
        accounts = self.cachedAccounts;
    });
    
    if (!accounts) {
        if (error) {
            *error = [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Accounts not loaded. Call fetchAccountsWithCompletionHandler first."}];
        }
        return nil;
    }
    
    NSDictionary *accountData = accounts[accountType];
    if (!accountData) {
        if (error) {
            // Filter out __comment_* keys from the available types list
            NSMutableArray *accountTypes = [NSMutableArray array];
            for (NSString *key in [accounts allKeys]) {
                if (![key hasPrefix:@"__comment"]) {
                    [accountTypes addObject:key];
                }
            }
            NSString *availableTypes = [accountTypes componentsJoinedByString:@", "];
            NSString *message = [NSString stringWithFormat:@"Account type '%@' not found in Key Vault JSON. Available types: %@",
                                 accountType, availableTypes];
            *error = [NSError errorWithDomain:@"MSIDKeyVaultAccountProvider"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }
    
    // The Key Vault JSON should already be in MSIDTestAutomationAccount format:
    // {
    //     "upn": "user@domain.com",
    //     "credentialVaultKeyName": "LABNAME",
    //     "objectId": "...",
    //     "homeObjectId": "...",
    //     "tenantID": "...",
    //     "homeTenantID": "...",
    //     "userType": "cloud",
    //     "homeDomain": "domain.com"
    // }
    // Pass the dictionary directly to MSIDTestAutomationAccount
    
    NSError *createError = nil;
    MSIDTestAutomationAccount *account = [[MSIDTestAutomationAccount alloc] initWithJSONDictionary:accountData error:&createError];
    
    if (createError) {
        NSLog(@"[MSIDKeyVaultAccountProvider] Failed to create account from JSON: %@", createError.localizedDescription);
        if (error) {
            *error = createError;
        }
        return nil;
    }
    
    return account;
}

@end
