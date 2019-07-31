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

#import "MSIDTestCacheDataSource.h"
#import "MSIDCacheKey.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDAccount.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSIDTestCacheDataSource()
{
    NSMutableDictionary<NSString *, NSString *> *_tokenKeys;
    NSMutableDictionary<NSString *, NSString *> *_accountKeys;
    NSMutableDictionary<NSString *, NSData *> *_tokenContents;
    NSMutableDictionary<NSString *, NSData *> *_accountContents;
    NSDictionary *_wipeInfo;
}

@end

@implementation MSIDTestCacheDataSource

#pragma mark - Init

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _tokenKeys = [NSMutableDictionary dictionary];
        _accountKeys = [NSMutableDictionary dictionary];
        _tokenContents = [NSMutableDictionary dictionary];
        _accountContents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - MSIDTokenCacheDataSource

- (BOOL)saveToken:(MSIDCredentialCacheItem *)item
              key:(MSIDCacheKey *)key
       serializer:(id<MSIDCacheItemSerializing>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    if (!item
        || !key
        || !serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSData *serializedItem = [serializer serializeCredentialCacheItem:item];
    return [self saveItemData:serializedItem
                          key:key
                    cacheKeys:_tokenKeys
                 cacheContent:_tokenContents
                      context:context
                        error:error];
}

- (MSIDCredentialCacheItem *)tokenWithKey:(MSIDCacheKey *)key
                               serializer:(id<MSIDCacheItemSerializing>)serializer
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSData *itemData = [self itemDataWithKey:key
                              keysDictionary:_tokenKeys
                           contentDictionary:_tokenContents
                                     context:context
                                       error:error];

    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:itemData];
    return token;
}

- (BOOL)removeTokensWithKey:(MSIDCacheKey *)key
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeAccountsWithKey:(MSIDCacheKey *)key
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeMetadataItemsWithKey:(MSIDCacheKey *)key
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeItemsWithKey:(MSIDCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    if (!key)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSString *uniqueKey = [self uniqueIdFromKey:key];
    
    @synchronized (self) {
        
        NSString *tokenComponentsKey = _tokenKeys[uniqueKey];
        [_tokenKeys removeObjectForKey:uniqueKey];
        
        if (tokenComponentsKey)
        {
            [_tokenContents removeObjectForKey:tokenComponentsKey];
        }
        
        NSString *accountComponentsKey = _accountKeys[uniqueKey];
        [_accountKeys removeObjectForKey:uniqueKey];
        
        if (accountComponentsKey)
        {
            [_accountContents removeObjectForKey:accountComponentsKey];
        }
    }
    
    return YES;
}

- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(MSIDCacheKey *)key
                                           serializer:(id<MSIDCacheItemSerializing>)serializer
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSMutableArray *resultItems = [NSMutableArray array];
    
    NSArray<NSData *> *items = [self itemsWithKey:key
                                   keysDictionary:_tokenKeys
                                contentDictionary:_tokenContents
                                          context:context
                                            error:error];
    
    for (NSData *itemData in items)
    {
        MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:itemData];
        
        if (token)
        {
            [resultItems addObject:token];
        }
    }
    
    return resultItems;
}

- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    _wipeInfo = @{@"wiped": [NSDate date]};
    return YES;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    return _wipeInfo;
}

- (BOOL)saveAccount:(MSIDAccountCacheItem *)item
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!item
        || !serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSData *serializedItem = [serializer serializeCacheItem:item];
    return [self saveItemData:serializedItem
                          key:key
                    cacheKeys:_accountKeys
                 cacheContent:_accountContents
                      context:context
                        error:error];
}

- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSData *itemData = [self itemDataWithKey:key
                              keysDictionary:_accountKeys
                           contentDictionary:_accountContents
                                     context:context
                                       error:error];
    
    MSIDAccountCacheItem *token = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:itemData ofClass:[MSIDAccountCacheItem class]];
    return token;
}

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSMutableArray *resultItems = [NSMutableArray array];
    
    NSArray<NSData *> *items = [self itemsWithKey:key
                                   keysDictionary:_accountKeys
                                contentDictionary:_accountContents
                                          context:context
                                            error:error];
    
    for (NSData *itemData in items)
    {
        MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:itemData ofClass:[MSIDAccountCacheItem class]];
        
        if (account)
        {
            [resultItems addObject:account];
        }
    }
    
    return resultItems;
}

- (NSArray<MSIDJsonObject *> *)jsonObjectsWithKey:(MSIDCacheKey *)key
                                       serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                          context:(id<MSIDRequestContext>)context
                                            error:(NSError *__autoreleasing *)error
{
    // TODO
    return nil;
}


- (BOOL)saveJsonObject:(MSIDJsonObject *)jsonObject
            serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                   key:(MSIDCacheKey *)key
               context:(id<MSIDRequestContext>)context
                 error:(NSError *__autoreleasing *)error
{
    // TODO
    return NO;
}


#pragma mark - Helpers

- (NSString *)uniqueIdFromKey:(MSIDCacheKey *)key
{
    // Simulate keychain behavior by using account and service as unique key
    return [NSString stringWithFormat:@"%@_%@", key.account, key.service];
}

- (NSString *)keyComponentsStringFromKey:(MSIDCacheKey *)key
{
    NSString *generic = key.generic ? [[NSString alloc] initWithData:key.generic encoding:NSUTF8StringEncoding] : nil;
    return [NSString stringWithFormat:@"%@_%@_%@_%@", key.account, key.service, key.type, generic];
}

- (NSString *)regexFromKey:(MSIDCacheKey *)key
{
    NSString *accountStr = key.account ?
        [self absoluteRegexFromString:key.account] : @".*";
    NSString *serviceStr = key.service ?
        [self absoluteRegexFromString:key.service] : @".*";
    NSString *typeStr = key.type ? key.type.stringValue : @".*";
    NSString *generic = key.generic ? [[NSString alloc] initWithData:key.generic encoding:NSUTF8StringEncoding] : nil;
    NSString *genericStr = generic ? [self absoluteRegexFromString:generic] : @".*";
    
    NSString *regexString = [NSString stringWithFormat:@"%@_%@_%@_%@", accountStr, serviceStr, typeStr, genericStr];
    return regexString;
}

- (NSString *)absoluteRegexFromString:(NSString *)string
{
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
    string = [string stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    return string;
}

#pragma mark - Private

- (NSData *)itemDataWithKey:(MSIDCacheKey *)key
             keysDictionary:(NSDictionary *)cacheKeys
          contentDictionary:(NSDictionary *)cacheContent
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!key || !cacheKeys || !cacheContent)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSArray<NSData *> *items = [self itemsWithKey:key
                                   keysDictionary:cacheKeys
                                contentDictionary:cacheContent
                                          context:context
                                            error:error];
    
    if ([items count] == 1)
    {
        NSData *itemData = items[0];
        return itemData;
    }
    
    return nil;
}

- (BOOL)saveItemData:(NSData *)serializedItem
                 key:(MSIDCacheKey *)key
           cacheKeys:(NSMutableDictionary *)cacheKeys
        cacheContent:(NSMutableDictionary *)cacheContent
             context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    if (!key || !cacheKeys || !cacheContent)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    if (!serializedItem)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Couldn't serialize the MSIDBaseToken item", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    /*
     This is trying to simulate keychain behavior for generic password type,
     where account and service are used as unique key, but both type and generic
     can be used for queries. So, cache keys will store key to the item in the cacheContent dictionary.
     That way there can be only one item with unique combination of account and service,
     but we'll still be able to query by generic and type.
     */
    
    NSString *uniqueIdKey = [self uniqueIdFromKey:key];
    NSString *componentsKey = [self keyComponentsStringFromKey:key];
    
    @synchronized (self) {
        cacheKeys[uniqueIdKey] = componentsKey;
    }
    
    @synchronized (self) {
        cacheContent[componentsKey] = serializedItem;
    }
    
    return YES;
}

- (NSArray<NSData *> *)itemsWithKey:(MSIDCacheKey *)key
                     keysDictionary:(NSDictionary *)cacheKeys
                  contentDictionary:(NSDictionary *)cacheContent
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    if (!key
        || !cacheKeys
        || !cacheContent)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSData *itemData = nil;
    
    if (key.account
        && key.service
        && key.generic
        && key.type)
    {
        // If all key attributes are set, look for an exact match
        NSString *componentsKey = [self keyComponentsStringFromKey:key];
        itemData = cacheContent[componentsKey];
    }
    else if (key.account
             && key.service)
    {
        // If all key attributes that are part of unique id are set, look for an exact match in keys
        NSString *uniqueId = [self uniqueIdFromKey:key];
        NSString *itemKey = cacheKeys[uniqueId];
        itemData = cacheContent[itemKey];
    }
    
    if (itemData)
    {
        // Direct match, return without additional lookup
        return @[itemData];
    }
    
    // If no direct match found, do a partial query
    NSMutableArray *resultItems = [NSMutableArray array];
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[self regexFromKey:key]
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    @synchronized (self) {
        
        for (NSString *dictKey in [cacheContent allKeys])
        {
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:dictKey
                                                                options:0
                                                                  range:NSMakeRange(0, [dictKey length])];
            
            if (numberOfMatches > 0)
            {
                NSData *object = cacheContent[dictKey];
                [resultItems addObject:object];
            }
        }
        
    }
    
    return resultItems;
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context error:(NSError **)error
{
    [self reset];
    return YES;
}

- (MSIDAccountMetadataCacheItem *)accountMetadataWithKey:(MSIDCacheKey *)key serializer:(id<MSIDExtendedCacheItemSerializing>)serializer context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSData *data = [self itemDataWithKey:key keysDictionary:_accountKeys contentDictionary:_accountContents context:context error:error];
    return (MSIDAccountMetadataCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAccountMetadataCacheItem class]];
}


- (BOOL)removeAccountMetadataForKey:(MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    return [self removeItemsWithKey:key context:context error:error];
}


- (BOOL)saveAccountMetadata:(MSIDAccountMetadataCacheItem *)item key:(MSIDCacheKey *)key serializer:(id<MSIDExtendedCacheItemSerializing>)serializer context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    if (!item || !serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    NSData *serializedItem = [serializer serializeCacheItem:item];
    return [self saveItemData:serializedItem
                          key:key
                    cacheKeys:_accountKeys
                 cacheContent:_accountContents
                      context:context
                        error:error];
}


- (BOOL)saveAppMetadata:(MSIDAppMetadataCacheItem *)item
                    key:(MSIDCacheKey *)key
             serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (!item
        || !serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSData *serializedItem = [serializer serializeCacheItem:item];
    return [self saveItemData:serializedItem
                          key:key
                    cacheKeys:_accountKeys
                 cacheContent:_accountContents
                      context:context
                        error:error];
}

- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(MSIDCacheKey *)key
                                                        serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error;
{
    if (!serializer)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSMutableArray *resultItems = [NSMutableArray array];
    
    NSArray<NSData *> *items = [self itemsWithKey:key
                                   keysDictionary:_accountKeys
                                contentDictionary:_accountContents
                                          context:context
                                            error:error];
    
    for (NSData *itemData in items)
    {
        MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)[serializer deserializeCacheItem:itemData ofClass:[MSIDAppMetadataCacheItem class]];
        
        if (appMetadata)
        {
            [resultItems addObject:appMetadata];
        }
    }
    
    return resultItems;
}

#pragma mark - Test methods

- (void)reset
{
    @synchronized (self)  {
        _tokenContents = [NSMutableDictionary dictionary];
        _wipeInfo = nil;
    }
}

- (NSArray *)allLegacySingleResourceTokens
{
    return [self allTokensWithType:MSIDLegacySingleResourceTokenType
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allLegacyAccessTokens
{
    return [self allTokensWithType:MSIDAccessTokenType
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allLegacyRefreshTokens
{
    return [self allTokensWithType:MSIDRefreshTokenType
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allDefaultAccessTokens
{
    return [self allTokensWithType:MSIDAccessTokenType
                        serializer:[[MSIDCacheItemJsonSerializer alloc] init]];
}

- (NSArray *)allDefaultRefreshTokens
{
    return [self allTokensWithType:MSIDRefreshTokenType
                        serializer:[[MSIDCacheItemJsonSerializer alloc] init]];
}

- (NSArray *)allDefaultIDTokens
{
    return [self allTokensWithType:MSIDIDTokenType
                        serializer:[[MSIDCacheItemJsonSerializer alloc] init]];
}

- (NSArray *)allTokensWithType:(MSIDCredentialType)type
                    serializer:(id<MSIDCacheItemSerializing>)serializer
{
    NSMutableArray *results = [NSMutableArray array];
    
    @synchronized (self) {
        
        for (NSData *tokenData in [_tokenContents allValues])
        {
            MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:tokenData];
            
            if (token)
            {
                MSIDBaseToken *baseToken = [token tokenWithType:type];
                
                if (baseToken)
                {
                    [results addObject:baseToken];
                }
            }
        }
    }
    
    return results;
}

- (NSArray *)allAccounts
{
    NSMutableArray *results = [NSMutableArray array];
    
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    @synchronized (self) {
        
        for (NSData *accountData in [_accountContents allValues])
        {
            MSIDAccountCacheItem *accountCacheItem = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:accountData ofClass:[MSIDAccountCacheItem class]];
            
            if (accountCacheItem)
            {
                MSIDAccount *account = [[MSIDAccount alloc] initWithAccountCacheItem:accountCacheItem];
                
                if (account)
                {
                    [results addObject:account];
                }
            }
        }
    }
    
    return results;
}

@end
