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
#import "MSIDTokenCacheKey.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAdfsToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDJsonSerializer.h"

@interface MSIDTestCacheDataSource()
{
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
        _tokenContents = [NSMutableDictionary dictionary];
        _accountContents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - MSIDTokenCacheDataSource

- (BOOL)saveToken:(MSIDTokenCacheItem *)item
              key:(MSIDTokenCacheKey *)key
       serializer:(id<MSIDTokenItemSerializer>)serializer
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
    
    NSData *serializedItem = [serializer serializeTokenCacheItem:item];
    return [self saveItemData:serializedItem key:key cacheDictionary:_tokenContents context:context error:error];
}

- (MSIDTokenCacheItem *)tokenWithKey:(MSIDTokenCacheKey *)key
                          serializer:(id<MSIDTokenItemSerializer>)serializer
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
                             cacheDictionary:_tokenContents
                                     context:context
                                       error:error];

    MSIDTokenCacheItem *token = [serializer deserializeTokenCacheItem:itemData];
    return token;
}

- (BOOL)removeItemsWithKey:(MSIDTokenCacheKey *)key
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
    
    NSString *keyString = [self stringFromKey:key];
    
    @synchronized (self) {
        [_tokenContents removeObjectForKey:keyString];
    }
    
    return YES;
}

- (NSArray<MSIDTokenCacheItem *> *)tokensWithKey:(MSIDTokenCacheKey *)key
                                      serializer:(id<MSIDTokenItemSerializer>)serializer
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
    
    NSArray<NSData *> *items = [self itemsWithKey:key cacheDictionary:_tokenContents context:context error:error];
    
    for (NSData *itemData in items)
    {
        MSIDTokenCacheItem *token = [serializer deserializeTokenCacheItem:itemData];
        
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
                key:(MSIDTokenCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
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
    
    NSData *serializedItem = [serializer serializeAccountCacheItem:item];
    return [self saveItemData:serializedItem key:key cacheDictionary:_accountContents context:context error:error];
}

- (MSIDAccountCacheItem *)accountWithKey:(MSIDTokenCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
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
                             cacheDictionary:_accountContents
                                     context:context
                                       error:error];
    
    MSIDAccountCacheItem *token = [serializer deserializeAccountCacheItem:itemData];
    return token;
}

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDTokenCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
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
    
    NSArray<NSData *> *items = [self itemsWithKey:key cacheDictionary:_accountContents context:context error:error];
    
    for (NSData *itemData in items)
    {
        MSIDAccountCacheItem *account = [serializer deserializeAccountCacheItem:itemData];
        
        if (account)
        {
            [resultItems addObject:account];
        }
    }
    
    return resultItems;
}

#pragma mark - Helpers

- (NSString *)stringFromKey:(MSIDTokenCacheKey *)key
{
    NSString *generic = key.generic ? [[NSString alloc] initWithData:key.generic encoding:NSUTF8StringEncoding] : nil;
    return [NSString stringWithFormat:@"%@_%@_%@_%@", key.account, key.service, key.type, generic];
}

- (NSString *)regexFromKey:(MSIDTokenCacheKey *)key
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

- (NSData *)itemDataWithKey:(MSIDTokenCacheKey *)key
            cacheDictionary:(NSDictionary *)cache
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!key || !cache)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSString *keyString = [self stringFromKey:key];
    NSData *itemData = nil;
    
    @synchronized (self) {
        itemData = cache[keyString];
    }
    
    return itemData;
}

- (BOOL)saveItemData:(NSData *)serializedItem
                 key:(MSIDTokenCacheKey *)key
     cacheDictionary:(NSMutableDictionary *)cache
             context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    if (!key || !cache)
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
    
    NSString *keyString = [self stringFromKey:key];
    
    @synchronized (self) {
        cache[keyString] = serializedItem;
    }
    
    return YES;
}

- (NSArray<NSData *> *)itemsWithKey:(MSIDTokenCacheKey *)key
                    cacheDictionary:(NSDictionary *)cache
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    if (!key
        || !cache)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSMutableArray *resultItems = [NSMutableArray array];
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[self regexFromKey:key]
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    @synchronized (self) {
        
        for (NSString *dictKey in [cache allKeys])
        {
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:dictKey
                                                                options:0
                                                                  range:NSMakeRange(0, [dictKey length])];
            
            if (numberOfMatches > 0)
            {
                NSData *object = cache[dictKey];
                [resultItems addObject:object];
            }
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

- (NSArray *)allLegacyADFSTokens
{
    return [self allTokensWithType:MSIDTokenTypeLegacyADFSToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allLegacyAccessTokens
{
    return [self allTokensWithType:MSIDTokenTypeAccessToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allLegacyRefreshTokens
{
    return [self allTokensWithType:MSIDTokenTypeRefreshToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] init]];
}

- (NSArray *)allDefaultAccessTokens
{
    return [self allTokensWithType:MSIDTokenTypeAccessToken
                        serializer:[[MSIDJsonSerializer alloc] init]];
}

- (NSArray *)allDefaultRefreshTokens
{
    return [self allTokensWithType:MSIDTokenTypeRefreshToken
                        serializer:[[MSIDJsonSerializer alloc] init]];
}

- (NSArray *)allTokensWithType:(MSIDTokenType)type
                    serializer:(id<MSIDTokenItemSerializer>)serializer
{
    NSMutableArray *results = [NSMutableArray array];
    
    @synchronized (self) {
        
        for (NSData *tokenData in [_tokenContents allValues])
        {
            MSIDTokenCacheItem *token = [serializer deserializeTokenCacheItem:tokenData];
            
            if (token && token.tokenType == type)
            {
                [results addObject:token];
            }
        }
    }
    
    return results;
}

- (NSArray *)allAccounts
{
    NSMutableArray *results = [NSMutableArray array];
    
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    @synchronized (self) {
        
        for (NSData *accountData in [_accountContents allValues])
        {
            MSIDAccountCacheItem *account = [serializer deserializeAccountCacheItem:accountData];
            
            if (account)
            {
                [results addObject:account];
            }
        }
    }
    
    return results;
}

@end
