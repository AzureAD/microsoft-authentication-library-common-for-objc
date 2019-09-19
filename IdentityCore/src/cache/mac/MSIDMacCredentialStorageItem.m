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

- (void)storeItem:(id<MSIDJsonSerializable>)item forKey:(MSIDCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        NSString *type = [self getItemTypeFromCacheKey:key];
        
        if (type)
        {
            NSMutableDictionary *items = [self.cacheObjects objectForKey:type];
            
            if (!items)
            {
                items = [NSMutableDictionary new];
            }
            
            [items setObject:item forKey:key];
            [self.cacheObjects setObject:items forKey:type];
        }
    });
}

- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem
{
    dispatch_barrier_async(self.queue, ^{
        
        for (NSString *typeKey in storageItem.cacheObjects)
        {
            NSMutableDictionary *typeDict = [storageItem.cacheObjects msidObjectForKey:typeKey ofClass:[NSDictionary class]];
            NSMutableDictionary *subDict = [self.cacheObjects msidObjectForKey:typeKey ofClass:[NSDictionary class]];
            
            if (typeDict)
            {
                if (!subDict)
                {
                    [self.cacheObjects setObject:typeDict forKey:typeKey];
                }
                else
                {
                    [subDict addEntriesFromDictionary:typeDict];
                }
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to get type dictionary from key for stored credential.");
            }
        }
    });
}

- (void)removeStoredItemForKey:(MSIDCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        NSString *type = [self getItemTypeFromCacheKey:key];
        
        if (type)
        {
            NSMutableDictionary *typeDict = [self.cacheObjects msidObjectForKey:type ofClass:[NSDictionary class]];
            if (typeDict)
            {
                [typeDict removeObjectForKey:key];
                
                //Update the bucket only if it has one or more items.
                if (![typeDict count])
                {
                    [self.cacheObjects removeObjectForKey:type];
                }
            }
        }
        else
        {
            NSArray *keys = [self.cacheObjects allKeys];
            for (NSString *typeKey in keys)
            {
                NSMutableDictionary *subDict = [self.cacheObjects objectForKey:typeKey];
                NSArray *filteredKeys = [self getFilteredKeys:subDict forKey:key];
                [subDict removeObjectsForKeys:filteredKeys];
                if (![subDict count])
                {
                    [self.cacheObjects removeObjectForKey:typeKey];
                }
            }
        }
    });
}

- (NSArray<id<MSIDJsonSerializable>> *)storedItemsForKey:(MSIDCacheKey *)key
{
    __block NSArray *storedItems = [[NSMutableArray alloc] init];
    
    dispatch_sync(self.queue, ^{
        NSString *type = [self getItemTypeFromCacheKey:key];
        
        if (type)
        {
            NSMutableDictionary *typeDict = [self.cacheObjects msidObjectForKey:type ofClass:[NSDictionary class]];
            
            if (typeDict)
            {
                if (key.account && key.service)
                {
                    id<MSIDJsonSerializable> item = [typeDict objectForKey:key];
                    if (item)
                    {
                        storedItems = [[NSMutableArray alloc] initWithObjects:item, nil];
                    }
                }
                else
                {
                    // If passed key is not exact match, filter storage items based on given key attributes.
                    storedItems = [self getFilteredItems:typeDict forKey:key];
                }
            }
        }
        else
        {
            NSMutableArray *matchingCredentials = [NSMutableArray new];
            //Unknown key type passed i.e. key.credentialType = MSIDCredentialTypeOther. Need to go through each key for the blob.
            for (NSString *typeKey in self.cacheObjects)
            {
                NSMutableDictionary *subDict = [self.cacheObjects objectForKey:typeKey];
                NSArray *filteredCredentials = [self getFilteredItems:subDict forKey:key];
                [matchingCredentials addObjectsFromArray:filteredCredentials];
            }
            
            storedItems = [matchingCredentials copy];
        }
    });
    
    return storedItems;
}

- (NSUInteger)count
{
    __block NSUInteger count;
    
    dispatch_sync(self.queue, ^{
        count = (NSUInteger)[self.cacheObjects count];
    });
    
    return count;
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
        for (NSString *typeKey in json)
        {
            NSMutableDictionary *typeDict = [NSMutableDictionary dictionary];
            NSDictionary *subDict = [json msidObjectForKey:typeKey ofClass:[NSDictionary class]];
            
            if (subDict)
            {
                for (NSString *itemKey in subDict)
                {
                    NSDictionary *itemDict = [subDict msidObjectForKey:itemKey ofClass:[NSDictionary class]];
                    
                    if (itemDict)
                    {
                        id<MSIDJsonSerializable, MSIDKeyGenerator> storedItem = [self getItemWithType:itemDict forKey:typeKey error:error];
                        
                        if (storedItem)
                        {
                            MSIDCacheKey *storedItemKey = [storedItem generateCacheKey];
                            
                            if (storedItemKey)
                            {
                                [typeDict setObject:storedItem forKey:storedItemKey];
                            }
                            else
                            {
                                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create cache key from stored item.");
                            }
                        }
                        else
                        {
                            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to deserialize storage item.");
                        }
                    }
                }
                
                [instance.cacheObjects setObject:typeDict forKey:typeKey];
            }
        }
    }

    return instance;
}

- (NSDictionary *)jsonDictionary
{
    __block NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.queue, ^{
        
        for (NSString *typeKey in self.cacheObjects)
        {
            NSMutableDictionary *typeDict = [NSMutableDictionary dictionary];
            NSMutableDictionary *subDict = [self.cacheObjects objectForKey:typeKey];
            
            for (MSIDCacheKey *cacheKey in subDict)
            {
                id<MSIDJsonSerializable> cacheItem = [subDict objectForKey:cacheKey];
                if (cacheItem && [cacheItem conformsToProtocol:@protocol(MSIDJsonSerializable)])
                {
                    NSDictionary *cacheItemDict = [cacheItem jsonDictionary];
                    
                    if (cacheItemDict)
                    {
                        [typeDict setObject:cacheItemDict forKey:[self getItemKey:cacheKey]];
                    }
                }
                else
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to serialize storage item.");
                }
            }
            
            [dictionary setObject:typeDict forKey:typeKey];
        }
    });
    
    return dictionary;
}

- (NSArray<id<MSIDJsonSerializable>> *)getFilteredItems:(NSMutableDictionary *)itemDict forKey:(MSIDCacheKey *)cacheKey
{
    NSMutableArray *storedItems =  [[NSMutableArray alloc] init];
    
    NSArray *storedKeys = [itemDict allKeys];
    NSArray *filteredKeys = [storedKeys filteredArrayUsingPredicate:[self createPredicateForKey:cacheKey]];
    for (MSIDCacheKey *key in filteredKeys)
    {
        id<MSIDJsonSerializable> item = [itemDict objectForKey:key];
        if (item)
        {
            [storedItems addObject:item];
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Item is nil for key %@.", MSID_PII_LOG_MASKABLE(key));
        }
    }
    
    return [storedItems copy];
}

- (NSArray<id<MSIDJsonSerializable>> *)getFilteredKeys:(NSMutableDictionary *)itemDict forKey:(MSIDCacheKey *)cacheKey
{
    NSArray *storedKeys = [itemDict allKeys];
    NSArray *filteredKeys = [storedKeys filteredArrayUsingPredicate:[self createPredicateForKey:cacheKey]];
    return filteredKeys;
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

- (id<MSIDJsonSerializable, MSIDKeyGenerator>)getItemWithType:(NSDictionary *)itemDict forKey:(NSString *)typeKey error:(NSError * __autoreleasing *)error
{
    if ([typeKey isEqualToString:MSID_ACCESS_TOKEN_CACHE_TYPE])
    {
        return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if ([typeKey isEqualToString:MSID_ID_TOKEN_CACHE_TYPE])
    {
        return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([typeKey isEqualToString:MSID_REFRESH_TOKEN_CACHE_TYPE])
    {
        return [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([typeKey isEqualToString:MSID_ACCOUNT_CACHE_TYPE])
    {
        return [[MSIDAccountCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([typeKey isEqualToString:MSID_APPLICATION_METADATA_CACHE_TYPE])
    {
        return [[MSIDAppMetadataCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    else if([typeKey isEqualToString:MSID_ACCOUNT_METADATA_CACHE_TYPE])
    {
        return [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:itemDict error:error];
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Unknown key type passed %@.", MSID_PII_LOG_MASKABLE(typeKey));
    return nil;
}

- (NSString *)getItemTypeFromCacheKey:(MSIDCacheKey *)itemKey
{
    if ([itemKey isKindOfClass:[MSIDDefaultCredentialCacheKey class]])
    {
        MSIDDefaultCredentialCacheKey *key = (MSIDDefaultCredentialCacheKey *)itemKey;
        if (key.credentialType == MSIDIDTokenType)
        {
            return MSID_ID_TOKEN_CACHE_TYPE;
        }
        else if (key.credentialType == MSIDAccessTokenType)
        {
            return MSID_ACCESS_TOKEN_CACHE_TYPE;
        }
        else if (key.credentialType == MSIDRefreshTokenType)
        {
            return MSID_REFRESH_TOKEN_CACHE_TYPE;
        }
    }
    else if ([itemKey isKindOfClass:[MSIDDefaultAccountCacheKey class]])
    {
        return MSID_ACCOUNT_CACHE_TYPE;
    }
    else if ([itemKey isKindOfClass:[MSIDAppMetadataCacheKey class]])
    {
        return MSID_APPLICATION_METADATA_CACHE_TYPE;
    }
    else if ([itemKey isKindOfClass:[MSIDAccountMetadataCacheKey class]])
    {
        return MSID_ACCOUNT_METADATA_CACHE_TYPE;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Unknown key type passed %@.", MSID_PII_LOG_MASKABLE(itemKey));
    return nil;
}

@end
