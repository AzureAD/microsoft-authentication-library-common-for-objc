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


#import "MSIDMacCredentialStorageItem.h"

static NSString *keyDelimiter = @"-";

@interface MSIDMacCredentialStorageItem ()

@property (nonatomic) NSMutableDictionary *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MSIDMacCredentialStorageItem

- (instancetype)init
{
    if (self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.universalstorage-%@", [NSUUID UUID].UUIDString];
        self.queue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (void)storeCredential:(MSIDCredentialCacheItem *)credential forKey:(MSIDCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        MSIDCacheKey *storedCredentialKey = [self getStoredCredentialKey:key];
        [self.cacheObjects setObject:credential forKey:storedCredentialKey];
    });
}

- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem
{
    dispatch_barrier_async(self.queue, ^{
        for (MSIDCacheKey *key in storageItem.cacheObjects)
        {
            MSIDCredentialCacheItem *credential = [storageItem.cacheObjects objectForKey:key];
            if (credential)
            {
                [self.cacheObjects setObject:credential forKey:key];
            }
            else
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Credential is nil for key %@ while merging storage credentials.", MSID_PII_LOG_MASKABLE(key));
            }
        }
    });
}

- (void)removeStoredCredentialForKey:(MSIDCacheKey *)key
{
    dispatch_barrier_sync(self.queue, ^{
        [self.cacheObjects removeObjectForKey:key];
    });
}

- (NSArray<MSIDCredentialCacheItem *> *)storedCredentialsForKey:(MSIDCacheKey *)key
{
    __block NSMutableArray<MSIDCredentialCacheItem *> *credentials =  [[NSMutableArray alloc] init];
    
    dispatch_sync(self.queue, ^{
        if (key.account && key.service)
        {
            MSIDCredentialCacheItem *credential = [self.cacheObjects objectForKey:key];
            if (credential)
            {
                [credentials addObject:credential];
            }
        }
        else
        {
            NSArray *storedKeys = [self.cacheObjects allKeys];
            NSArray *filteredKeys = [storedKeys filteredArrayUsingPredicate:[self createPredicateForKey:key]];
            for(MSIDCacheKey *key in filteredKeys)
            {
                MSIDCredentialCacheItem *credential = [self.cacheObjects objectForKey:key];
                if (credential)
                {
                    [credentials addObject:credential];
                }
            }
        }
    });
    
    return credentials;
}

/*
 This api is thread safe only if an immutable object is passed as parameter.
 */
- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    MSIDMacCredentialStorageItem *instance = [self init];
    
    if (instance)
    {
        for (NSString *credentialKey in json)
        {
            NSDictionary *credentialDict = [json msidObjectForKey:credentialKey ofClass:[NSDictionary class]];
            
            if (credentialDict)
            {
                MSIDCredentialCacheItem *credential = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:credentialDict error:error];
                
                if (credential)
                {
                    MSIDDefaultCredentialCacheKey *key = [self getDefaultCredentialCacheKey:credential];
                    if (key)
                    {
                        MSIDCacheKey *storedCredentialKey = [self getStoredCredentialKey:key];
                        if (storedCredentialKey)
                        {
                            [instance.cacheObjects setObject:credential forKey:storedCredentialKey];
                        }
                        else
                        {
                            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to create MSIDCacheKey from MSIDDefaultCredentialCacheKey%@.", MSID_PII_LOG_MASKABLE(key));
                        }
                    }
                    else
                    {
                        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create MSIDDefaultCredentialCacheKey from MSIDCredentialCacheitem");
                    }
                }
            }
        }
    }
    
    return instance;
}

- (NSDictionary *)jsonDictionary
{
    __block NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.queue, ^{
        for (MSIDCacheKey *credentialKey in self.cacheObjects)
        {
            MSIDCredentialCacheItem *credential = [self.cacheObjects objectForKey:credentialKey];
            if (credential)
            {
                NSDictionary *credentialDict = [credential jsonDictionary];
                
                if (credentialDict && [credentialDict isKindOfClass:[NSDictionary class]])
                {
                    [dictionary setObject:credentialDict forKey:[self getCredentialKey:credentialKey]];
                }
            }
        }
    });
    
    return dictionary;
}

- (MSIDDefaultCredentialCacheKey *)getDefaultCredentialCacheKey:(MSIDCredentialCacheItem *)credential
{
    MSIDDefaultCredentialCacheKey *credentialKey = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId environment:credential.environment clientId:credential.clientId credentialType:credential.credentialType];
    
    credentialKey.familyId = credential.familyId;
    credentialKey.realm = credential.realm;
    credentialKey.target = credential.target;
    credentialKey.enrollmentId = credential.enrollmentId;
    return credentialKey;
}

- (MSIDCacheKey *)getStoredCredentialKey:(MSIDCacheKey *)key
{
    MSIDCacheKey *storedCredentialKey = [[MSIDCacheKey alloc] initWithAccount:key.account service:key.service generic:key.generic type:key.type];
    return storedCredentialKey;
}

- (NSString *)getCredentialKey:(MSIDCacheKey *)key
{
    return [NSString stringWithFormat:@"%@%@%@", key.account, keyDelimiter, key.service];
}

- (NSPredicate *)createPredicateForKey:(MSIDCacheKey *)key
{
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    if (key.account)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.account == %@", key.account]];
    if (key.service)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.service == %@", key.service]];
    if (key.generic)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.generic == %@", key.generic]];
    if (key.type)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.type == %@", key.type]];
    
    // Combine all sub-predicates with AND:
    return [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
}

@end
