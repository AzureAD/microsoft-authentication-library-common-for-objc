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

- (void)storeItem:(id<MSIDJsonSerializable>)item inBucket:(NSString *)bucket forKey:(MSIDCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        
        NSMutableDictionary *items = nil;
        if (bucket && ![self.cacheObjects objectForKey:bucket])
        {
            items = [NSMutableDictionary new];
        }
        else
        {
            items = [self.cacheObjects objectForKey:bucket];
        }
        
        [items setObject:item forKey:key];
        [self.cacheObjects setObject:items forKey:bucket];
    });
}

- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem inBucket:(NSString *)bucket
{
    dispatch_barrier_async(self.queue, ^{
        
        for (NSString *bucketKey in storageItem.cacheObjects)
        {
            NSMutableDictionary *bucketDict = [storageItem.cacheObjects objectForKey:bucketKey];
            NSMutableDictionary *subDict = [self.cacheObjects objectForKey:bucketKey];
            
            if (!subDict)
            {
                [self.cacheObjects setObject:bucketDict forKey:bucketKey];
            }
            else
            {
                for (MSIDCacheKey *key in bucketDict)
                {
                    id<MSIDJsonSerializable> storedItem = [bucketDict objectForKey:key];
                    if (storedItem)
                    {
                        [subDict setObject:storedItem forKey:key];
                    }
                    else
                    {
                        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Item is nil for key %@ while merging storage item.", MSID_PII_LOG_MASKABLE(key));
                    }
                }
                
                [self.cacheObjects setObject:subDict forKey:bucketKey];
            }
        }
    });
}

- (void)removeStoredItemForKey:(MSIDCacheKey *)key inBucket:(NSString *)bucket
{
    dispatch_barrier_sync(self.queue, ^{
        if (bucket && [self.cacheObjects objectForKey:bucket])
        {
            NSMutableDictionary *bucketDict = [self.cacheObjects msidObjectForKey:bucket ofClass:[NSDictionary class]];
            
            if (bucketDict)
            {
                [bucketDict removeObjectForKey:key];
                
                //Update the bucket only if it has one or more items.
                if ([bucketDict count])
                {
                    [self.cacheObjects setObject:bucketDict forKey:bucket];
                }
                else
                {
                    [self.cacheObjects removeObjectForKey:bucket];
                }
            }
        }
    });
}

- (NSArray<id<MSIDJsonSerializable>> *)storedItemsForKey:(MSIDCacheKey *)key inBucket:(NSString *)bucket;
{
    __block NSMutableArray *storedItems =  [[NSMutableArray alloc] init];
    
    dispatch_sync(self.queue, ^{
        
        NSMutableDictionary *bucketDict = [self.cacheObjects objectForKey:bucket];
        if (bucket && [self.cacheObjects objectForKey:bucket])
        {
            if (key.account && key.service)
            {
                id<MSIDJsonSerializable> item = [bucketDict objectForKey:key];
                if (item)
                {
                    [storedItems addObject:item];
                }
            }
            else
            {
                NSArray *storedKeys = [bucketDict allKeys];
                NSArray *filteredKeys = [storedKeys filteredArrayUsingPredicate:[self createPredicateForKey:key]];
                for (MSIDCacheKey *key in filteredKeys)
                {
                    id<MSIDJsonSerializable> item = [bucketDict objectForKey:key];
                    if (item)
                    {
                        [storedItems addObject:item];
                    }
                    else
                    {
                        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Item is nil for key %@.", MSID_PII_LOG_MASKABLE(key));
                    }
                }
            }
        }
    });
    
    return storedItems;
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
        for (NSString *bucketKey in json)
        {
            NSMutableDictionary *bucketDict = [NSMutableDictionary dictionary];
            NSDictionary *subDict = [json msidObjectForKey:bucketKey ofClass:[NSDictionary class]];
            
            if (subDict)
            {
                for (NSString *itemKey in subDict)
                {
                    NSDictionary *itemDict = [subDict msidObjectForKey:itemKey ofClass:[NSDictionary class]];
                    
                    if (itemDict)
                    {
                        id<MSIDJsonSerializable, MSIDKeyGenerator> storedItem = [self getStoredItem:itemDict forKey:bucketKey error:error];
                        
                        if (storedItem && [storedItem conformsToProtocol:@protocol(MSIDJsonSerializable)] && [storedItem conformsToProtocol:@protocol(MSIDKeyGenerator)])
                        {
                            MSIDCacheKey *storedItemKey = [storedItem generateCacheKey];
                            
                            if (storedItemKey)
                            {
                                [bucketDict setObject:storedItem forKey:storedItemKey];
                            }
                            else
                            {
                                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create MSIDDefaultCredentialCacheKey from stored item.");
                            }
                        }
                        else
                        {
                            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to deserialize storage item.");
                        }
                    }
                }
                
                [instance.cacheObjects setObject:bucketDict forKey:bucketKey];
            }
        }
    }

    return instance;
}

- (NSDictionary *)jsonDictionary
{
    __block NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.queue, ^{
        
        for (NSString *bucketKey in self.cacheObjects)
        {
            NSMutableDictionary *bucketDict = [NSMutableDictionary dictionary];
            NSMutableDictionary *subDict = [self.cacheObjects objectForKey:bucketKey];
            
            for (MSIDCacheKey *cacheKey in subDict)
            {
                id<MSIDJsonSerializable> cacheItem = [subDict objectForKey:cacheKey];
                if (cacheItem && [cacheItem conformsToProtocol:@protocol(MSIDJsonSerializable)])
                {
                    NSDictionary *cacheItemDict = [cacheItem jsonDictionary];
                    
                    if (cacheItemDict && [cacheItemDict isKindOfClass:[NSDictionary class]])
                    {
                        [bucketDict setObject:cacheItemDict forKey:[self getItemKey:cacheKey]];
                    }
                }
                else
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to serialize storage item.");
                }
            }
            
            [dictionary setObject:bucketDict forKey:bucketKey];
        }
    });
    
    return dictionary;
}

- (NSString *)getItemKey:(MSIDCacheKey *)key
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

- (id<MSIDJsonSerializable, MSIDKeyGenerator>)getStoredItem:(NSDictionary *)itemDict forKey:(NSString *)bucketKey error:(NSError * __autoreleasing *)error
{
    if ([bucketKey isEqualToString:MSID_ACCESS_TOKEN_CACHE_TYPE])
    {
        return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if ([bucketKey isEqualToString:MSID_ID_TOKEN_CACHE_TYPE])
    {
        return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([bucketKey isEqualToString:MSID_REFRESH_TOKEN_CACHE_TYPE])
    {
         return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([bucketKey isEqualToString:MSID_ACCOUNT_CACHE_TYPE])
    {
        return [[MSIDAccountCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([bucketKey isEqualToString:MSID_APPLICATION_METADATA_CACHE_TYPE])
    {
        return [[MSIDAppMetadataCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([bucketKey isEqualToString:MSID_ACCOUNT_METADATA_CACHE_TYPE])
    {
        return [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    
    return nil;
}

- (NSUInteger)count
{
    __block NSUInteger count;
    
    dispatch_sync(self.queue, ^{
        count = (NSUInteger)[self.cacheObjects count];
    });
    
    return count;
}

@end
