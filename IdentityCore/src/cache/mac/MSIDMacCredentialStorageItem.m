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

- (void)storeCredential:(MSIDCredentialCacheItem *)credential forKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        NSString *credentialKey = [self getCredentialKey:key];
        [self.cacheObjects setObject:credential forKey:credentialKey];
    });
}

- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem
{
    dispatch_barrier_async(self.queue, ^{
        for (NSString *key in storageItem.cacheObjects)
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

- (void)removeStoredCredentialForKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        NSString *credentialKey = [self getCredentialKey:key];
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Removing credential for key %@.", MSID_PII_LOG_MASKABLE(credentialKey));
        [self.cacheObjects removeObjectForKey:credentialKey];
    });
}

- (NSArray<MSIDCredentialCacheItem *> *)storedCredentialsForKey:(MSIDDefaultCredentialCacheKey *)key
{
    __block NSArray<MSIDCredentialCacheItem *> *credentials =  @[];
    
    dispatch_sync(self.queue, ^{
        if (key.account && key.service)
        {
            NSString *credentialKey = [self getCredentialKey:key];
            MSIDCredentialCacheItem *credential = [self.cacheObjects objectForKey:credentialKey];
            if (credential)
            {
                credentials = @[credential];
            }
        }
        else
        {
            NSArray *storedCredentials = [self.cacheObjects allValues];
            credentials = [storedCredentials filteredArrayUsingPredicate:[self createPredicateForKey:key]];
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
                    [instance.cacheObjects setObject:credential forKey:credentialKey];
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
        for (NSString *credentialKey in self.cacheObjects)
        {
            MSIDCredentialCacheItem *credential = [self.cacheObjects objectForKey:credentialKey];
            if (credential)
            {
                NSDictionary *credentialDict = [credential jsonDictionary];
                
                if (credentialDict && [credentialDict isKindOfClass:[NSDictionary class]])
                {
                    [dictionary setObject:credentialDict forKey:credentialKey];
                }
            }
        }
    });
    
    return dictionary;
}

- (MSIDDefaultCredentialCacheKey *)getKeyForCredential:(MSIDCredentialCacheItem *)credential
{
    MSIDDefaultCredentialCacheKey *credentialKey = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId environment:credential.environment clientId:credential.clientId credentialType:credential.credentialType];
    
    credentialKey.familyId = credential.familyId;
    credentialKey.realm = credential.realm;
    credentialKey.target = credential.target;
    credentialKey.enrollmentId = credential.enrollmentId;
    return credentialKey;
}

- (NSString *)getCredentialKey:(MSIDDefaultCredentialCacheKey *)key
{
    return [NSString stringWithFormat:@"%@%@%@", key.account, keyDelimiter, key.service];
}

- (NSPredicate *)createPredicateForKey:(MSIDDefaultCredentialCacheKey *)key
{
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    /*
     TODO: Investigate app metadata code to save familyId as nil for apps that are not part of family.
     Refresh token either has family Id as 1 or nil.
     For app refresh token, we pass family id as nil which matches both FRT and RT instead of matching just RT
     For clients that are not part of family, family is saved as empty string and added to refresh token query.
     */
    NSString *familyId;
    if ([NSString msidIsStringNilOrBlank:key.familyId])
    {
        familyId = nil;
    }
    else
    {
        familyId = key.familyId;
    }
    
    [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.familyId == %@", familyId]];
    if (key.clientId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.clientId == %@", key.clientId]];
    if (key.environment)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.environment == %@", key.environment]];
    if (key.homeAccountId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.homeAccountId == %@", key.homeAccountId]];
    if (key.credentialType)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.credentialType == %d", key.credentialType]];
    if (key.realm)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.realm == %@", key.realm]];
    if (key.target && key.targetMatchingOptions == MSIDExactStringMatch)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.target == %@", key.target]];
    /*
     TODO: key.target is passed for look up in ios implementation which does not match the exact target for the stored credential
     key.target is not added as target can be subset , intersect , superset or exact string match and is matched later in the code.
     */
    
    // Combine all sub-predicates with AND:
    return [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
}

@end
