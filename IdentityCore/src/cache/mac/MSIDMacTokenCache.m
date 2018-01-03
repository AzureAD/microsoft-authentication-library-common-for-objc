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

#import "MSIDMacTokenCache.h"
#import "MSIDToken.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDTokenSerializer.h"
#import "MSIDUserInformation.h"

#define CURRENT_WRAPPER_CACHE_VERSION 1.0

#define RETURN_ERROR_IF_CONDITION_FALSE(_cond, _code, _details) { \
    if (!(_cond)) { \
        NSError* _MSID_ERROR = MSIDCreateError(MSIDErrorDomain, _code, _details, nil, nil, nil, nil, nil); \
        if (error) { *error = _MSID_ERROR; } \
        return NO; \
    } \
}

@interface MSIDMacTokenCache ()

@property (nonatomic) NSMutableDictionary *cache;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDMacTokenCache

- (dispatch_queue_t)synchronizationQueue
{
    if (!_synchronizationQueue) {
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidmactokencache-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }
    
    return _synchronizationQueue;
}

+ (MSIDMacTokenCache *)defaultCache
{
    static dispatch_once_t once;
    static MSIDMacTokenCache *cache = nil;
    
    dispatch_once(&once, ^{
        cache = [MSIDMacTokenCache new];
    });
    
    return cache;
}

- (nullable NSData *)serialize
{
    if (!self.cache)
    {
        return nil;
    }
    
    __block NSData *result = nil;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        NSDictionary *cacheCopy = [self.cache mutableCopy];
        
        // Using the dictionary @{ key : value } syntax here causes _cache to leak. Yay legacy runtime!
        NSDictionary *wrapper = [NSDictionary dictionaryWithObjectsAndKeys:cacheCopy, @"tokenCache",@CURRENT_WRAPPER_CACHE_VERSION, @"version", nil];
        
        @try
        {
            NSMutableData *data = [NSMutableData data];
            
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
            // Maintain backward compatibility with ADAL.
            [archiver setClassName:@"ADTokenCacheKey" forClass:MSIDTokenCacheKey.class];
            [archiver setClassName:@"ADTokenCacheStoreItem" forClass:MSIDToken.class];
            [archiver setClassName:@"ADUserInformation" forClass:MSIDUserInformation.class];
            [archiver encodeObject:wrapper forKey:NSKeyedArchiveRootObjectKey];
            [archiver finishEncoding];
            
            result = data;
        }
        @catch (id exception)
        {
            // This should be exceedingly rare as all of the objects in the cache we placed there.
            MSID_LOG_ERROR(nil, @"Failed to serialize the cache!");
        }
    });
    
    return result;
}

- (BOOL)deserialize:(nullable NSData*)data
              error:(NSError **)error
{
    __block BOOL result = NO;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        NSDictionary *cache = nil;
        
        @try
        {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
            // Maintain backward compatibility with ADAL.
            [unarchiver setClass:MSIDTokenCacheKey.class forClassName:@"ADTokenCacheKey"];
            [unarchiver setClass:MSIDToken.class forClassName:@"ADTokenCacheStoreItem"];
            [unarchiver setClass:MSIDUserInformation.class forClassName:@"ADUserInformation"];
            cache = [unarchiver decodeObjectOfClass:NSDictionary.class forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
        }
        @catch (id expection)
        {
            if (error) {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheBadFormat, @"Failed to unarchive data blob from -deserialize!", nil, nil, nil, nil, nil);
            }
        }
        
        if (!cache)
        {
            result = NO;
        }
        
        if (![self validateCache:cache error:error])
        {
            result = NO;
        }
        
        self.cache = [cache objectForKey:@"tokenCache"];
        result = YES;
    });
    
    return result;
}

- (NSMutableDictionary *)cache
{
    if (!_cache)
    {
        _cache = [NSMutableDictionary new];
    }
    
    if (!_cache[@"tokens"])
    {
        NSMutableDictionary *tokens = [NSMutableDictionary new];
        _cache[@"tokens"] = tokens;
    }
    
    return _cache;
}

- (void)clear
{
    self.cache = nil;
}

#pragma mark - MSIDTokenCacheDataSource

- (BOOL)setItem:(MSIDToken *)item
            key:(MSIDTokenCacheKey *)key
     serializer:(id<MSIDTokenSerializer>)serializer
        context:(id<MSIDRequestContext>)context
          error:(NSError **)error
{
    [self.delegate willWriteCache:self];
    __block BOOL result = NO;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
       result = [self setItemImpl:item key:key serializer:serializer context:context error:error];
    });
    [self.delegate didWriteCache:self];
    
    return result;
}

- (MSIDToken *)itemWithKey:(MSIDTokenCacheKey *)key
                serializer:(id<MSIDTokenSerializer>)serializer
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    MSID_LOG_INFO(context, @"itemWithKey:serializer:context:error:");
    NSArray<MSIDToken *> *items = [self itemsWithKey:key serializer:serializer context:context error:error];
    
    if (items.count > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"The token cache store for this resource contains more than one user.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return items.firstObject;
}

- (BOOL)removeItemsWithKey:(MSIDTokenCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    [self.delegate willWriteCache:self];
    __block BOOL result = NO;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        result = [self removeItemsWithKeyImpl:key context:context error:error];
    });
    [self.delegate didWriteCache:self];
    
    return result;
}

- (NSArray<MSIDToken *> *)itemsWithKey:(MSIDTokenCacheKey *)key
                            serializer:(id<MSIDTokenSerializer>)serializer
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    [self.delegate willAccessCache:self];
    __block NSArray *result = nil;
    dispatch_sync(self.synchronizationQueue, ^{
        result = [self itemsWithKeyImpl:key serializer:serializer context:nil error:error];
    });
    [self.delegate didAccessCache:self];
    
    return result;
}

- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    return NO;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    return nil;
}

#pragma mark - Private

- (void)addToItems:(nonnull NSMutableArray *)items
    fromDictionary:(nonnull NSDictionary *)dictionary
               key:(nonnull MSIDTokenCacheKey *)key
{
    MSIDToken *item = [dictionary objectForKey:[self keyWithoutAccount:key]];
    if (item)
    {
        item = [item copy];
        [items addObject:item];
    }
}

- (void)addToItems:(nonnull NSMutableArray *)items
         forUserId:(nonnull NSString *)userId
            tokens:(nonnull NSDictionary *)tokens
               key:(MSIDTokenCacheKey *)key
{
    NSDictionary *userTokens = [tokens objectForKey:userId];
    if (!userTokens)
    {
        return;
    }
    
    // Add items matching the key for this user
    if (key.service)
    {
        [self addToItems:items fromDictionary:userTokens key:key];
    }
    else
    {
        for (id adkey in userTokens)
        {
            [self addToItems:items fromDictionary:userTokens key:adkey];
        }
    }
}

- (BOOL)validateCache:(NSDictionary *)dict
                error:(NSError **)error
{
    RETURN_ERROR_IF_CONDITION_FALSE([dict isKindOfClass:[NSDictionary class]], MSIDErrorCacheBadFormat, @"Root level object of cache is not a NSDictionary!");
    RETURN_ERROR_IF_CONDITION_FALSE(dict[@"version"], MSIDErrorCacheBadFormat, @"Missing version number from cache.");
    RETURN_ERROR_IF_CONDITION_FALSE([dict[@"version"] floatValue] <= CURRENT_WRAPPER_CACHE_VERSION, MSIDErrorCacheBadFormat, @"Cache is a future unsupported version.");
    
    NSDictionary *cache = dict[@"tokenCache"];
    RETURN_ERROR_IF_CONDITION_FALSE(cache, MSIDErrorCacheBadFormat, @"Missing token cache from data.");
    RETURN_ERROR_IF_CONDITION_FALSE([cache isKindOfClass:[NSMutableDictionary class]], MSIDErrorCacheBadFormat, @"Cache is not a mutable dictionary!");
    
    NSDictionary *tokens = cache[@"tokens"];
    
    if (tokens)
    {
        RETURN_ERROR_IF_CONDITION_FALSE([tokens isKindOfClass:[NSMutableDictionary class]], MSIDErrorCacheBadFormat, @"tokens must be a mutable dictionary.");
        for (id userId in tokens)
        {
            // On the second level we're expecting NSDictionaries keyed off of the user ids (an NSString*)
            RETURN_ERROR_IF_CONDITION_FALSE([userId isKindOfClass:[NSString class]], MSIDErrorCacheBadFormat, @"User ID key is not of the expected class type.");
            id userDict = [tokens objectForKey:userId];
            RETURN_ERROR_IF_CONDITION_FALSE([userDict isKindOfClass:[NSMutableDictionary class]], MSIDErrorCacheBadFormat, @"User ID should have mutable dictionaries in the cache.");
            
            for (id key in userDict)
            {
                // On the first level we're expecting NSDictionaries keyed off of ADTokenCacheStoreKey
                RETURN_ERROR_IF_CONDITION_FALSE([key isKindOfClass:[MSIDTokenCacheKey class]], MSIDErrorCacheBadFormat, @"Key is not of the expected class type.");
                id token = [userDict objectForKey:key];
                RETURN_ERROR_IF_CONDITION_FALSE([token isKindOfClass:[MSIDToken class]], MSIDErrorCacheBadFormat, @"Token is not of the expected class type!");
            }
        }
    }
    
    return YES;
}

- (BOOL)removeItemsWithKeyImpl:(MSIDTokenCacheKey *)key
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (!key)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Key is nil.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    NSString *userId = key.account;
    if (!userId)
    {
        userId = @"";
    }
    
    NSMutableDictionary *userTokens = [self.cache[@"tokens"] objectForKey:userId];
    if (!userTokens)
    {
        return YES;
    }
    
    if (![userTokens objectForKey:[self keyWithoutAccount:key]])
    {
        return YES;
    }
    
    [userTokens removeObjectForKey:[self keyWithoutAccount:key]];
    
    // Check to see if we need to remove the overall dict
    if (!userTokens.count)
    {
        [self.cache[@"tokens"] removeObjectForKey:userId];
    }
    
    return YES;
}

- (BOOL)setItemImpl:(MSIDToken *)item
                key:(MSIDTokenCacheKey *)key
         serializer:(id<MSIDTokenSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    assert(key);
    
    MSID_LOG_INFO(context, @"Set item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set item, key info (account: %@ service: %@)", key.account, key.service);
    MSID_LOG_INFO_PII(context, @"Item info %@", item);
    
    if (!key)
    {
        return NO;
    }
    
    if (!item)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Item is nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set nil item.");
        
        return NO;
    }
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    if (!key.service || !key.account)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure service and account are not nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }
    
    // Grab the token dictionary for this user id.
    NSMutableDictionary *userDict = self.cache[@"tokens"][key.account];
    if (!userDict)
    {
        userDict = [NSMutableDictionary new];
        self.cache[@"tokens"][key.account] = userDict;
    }
    
    userDict[[self keyWithoutAccount:key]] = item;
    
    return YES;
}

- (NSArray<MSIDToken *> *)itemsWithKeyImpl:(MSIDTokenCacheKey *)key
                                serializer:(id<MSIDTokenSerializer>)serializer
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    MSID_LOG_INFO(context, @"Get items, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Get items, key info (account: %@ service: %@)", key.account, key.service);
    
    NSDictionary *tokens = [self.cache objectForKey:@"tokens"];
    if (!tokens)
    {
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    if (key.account)
    {
        // If we have a specified userId then we only look for that one
        [self addToItems:items forUserId:key.account tokens:tokens key:key];
    }
    else
    {
        // Otherwise we have to traverse all of the users in the cache
        for (NSString* userId in tokens)
        {
            [self addToItems:items forUserId:userId tokens:tokens key:key];
        }
    }
    
    return items;
}

- (MSIDTokenCacheKey *)keyWithoutAccount:(MSIDTokenCacheKey *)key
{
    // In order to be backward compatible with ADAL,
    // we need to store keys into dictionary without 'account'.
    MSIDTokenCacheKey *newKey = [key copy];
    newKey.account = nil;
    
    return newKey;
}

@end
