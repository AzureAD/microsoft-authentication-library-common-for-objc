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
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.universalstorage-%@", [NSUUID UUID].UUIDString];
        self.queue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (void)storeCredential:(MSIDCredentialCacheItem *)credential forKey:(NSString *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects setObject:credential forKey:key];
    });
}

- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem
{
    NSArray *keys = [storageItem allKeys];
    for (NSString *key in keys)
    {
        if (![self storedCredentialForKey:key])
        {
            MSIDCredentialCacheItem *item = [storageItem.cacheObjects objectForKey:key];
            if (item)
            {
                [self storeCredential:item forKey:key];
            }
        }
    }
}

- (MSIDCredentialCacheItem *)storedCredentialForKey:(NSString *)key
{
    __block MSIDCredentialCacheItem *credential = nil;
    
    dispatch_sync(self.queue, ^{
        credential = [self.cacheObjects objectForKey:key];
    });
    
    return credential;
}

- (void)removeStoredCredentialForKey:(NSString *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects removeObjectForKey:key];
    });
}

- (NSArray<MSIDCredentialCacheItem *> *)storedCredentialsForKey:(MSIDDefaultCredentialCacheKey *)key
{
    if (key.account && key.service)
    {
        NSString *credentialKey = [NSString stringWithFormat:@"%@%@%@", key.account, keyDelimiter, key.service];
        MSIDCredentialCacheItem *credential = [self storedCredentialForKey:credentialKey];
        if (credential)
        {
            return @[credential];
        }
        
        return nil;
    }
    
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    /*
     Refresh token either has family Id as 1 or nil.
     For app refresh token, we pass family id as nil which matches both FRT and RT instead of matching just RT
     For clients that are not part of family, family is saved as empty string and added to refresh token query.
     */
    if ([NSString msidIsStringNilOrBlank:key.familyId])
    {
        key.familyId = nil;
    }

    [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.familyId == %@", key.familyId]];
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
    /*
     key.target is not added as target can be subset , intersect , superset or exact string match and is matched later in the code.
     */
    
    // Combine all sub-predicates with AND:
    NSPredicate *matchAttributes = [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
    
    NSArray *storedCredentials = [self allValues];
    NSArray *filteredCredentials = [storedCredentials filteredArrayUsingPredicate:matchAttributes];
    return filteredCredentials;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [self init]))
    {
        return nil;
    }
    
    for (NSString *credentialKey in json)
    {
        NSDictionary *rtDict = [json objectForKey:credentialKey];
        
        if (rtDict)
        {
            MSIDCredentialCacheItem *credential = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:rtDict error:error];
            
            if (credential)
            {
                [self storeCredential:credential forKey:credentialKey];
            }
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSArray *credentialKeys = [self allKeys];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *credentialKey in credentialKeys)
    {
        MSIDCredentialCacheItem *credential = [self storedCredentialForKey:credentialKey];
        if (credential)
        {
            NSDictionary *atDict = [credential jsonDictionary];
            
            if (atDict)
            {
                [dictionary setObject:atDict forKey:credentialKey];
            }
        }
    }
    
    return dictionary;
}

- (NSArray *)allKeys
{
    __block NSArray *keys;
    /* make your READs sychronous */
    dispatch_sync(self.queue, ^{
        keys = [self.cacheObjects allKeys];
    });
    
    return keys;
}

- (NSArray *)allValues
{
    __block NSArray *values;
    /* make your READs sychronous */
    dispatch_sync(self.queue, ^{
        values = [self.cacheObjects allValues];
    });
    
    return values;
}

- (NSUInteger)storedCredentialsCount
{
    __block NSUInteger count;
    dispatch_sync(self.queue, ^{
        count = (NSUInteger)[self.cacheObjects count];
    });
    
    return count;
}

@end
