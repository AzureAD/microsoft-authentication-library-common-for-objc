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
#import "MSIDTokenSerializer.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAdfsToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"

@interface MSIDTestCacheDataSource()
{
    NSMutableDictionary<NSString *, NSData *> *_cacheContents;
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
        _cacheContents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - MSIDTokenCacheDataSource

- (BOOL)setItem:(MSIDBaseToken *)item
            key:(MSIDTokenCacheKey *)key
     serializer:(id<MSIDTokenSerializer>)serializer
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
    
    NSData *serializedItem = [serializer serialize:item];
    
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
        _cacheContents[keyString] = serializedItem;
    }
    
    return YES;
}

- (MSIDBaseToken *)itemWithKey:(MSIDTokenCacheKey *)key
                    serializer:(id<MSIDTokenSerializer>)serializer
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (!key
        || !serializer)
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
        itemData = _cacheContents[keyString];
    }
    
    MSIDBaseToken *token = [serializer deserialize:itemData];
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
        [_cacheContents removeObjectForKey:keyString];
    }
    
    return YES;
}

- (NSArray<MSIDBaseToken *> *)itemsWithKey:(MSIDTokenCacheKey *)key
                                serializer:(id<MSIDTokenSerializer>)serializer
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    if (!key
        || !serializer)
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
        
        for (NSString *dictKey in [_cacheContents allKeys])
        {
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:dictKey
                                                                options:0
                                                                  range:NSMakeRange(0, [dictKey length])];
            
            if (numberOfMatches > 0)
            {
                NSData *object = _cacheContents[dictKey];
                MSIDBaseToken *token = [serializer deserialize:object];
                
                if (token)
                {
                    [resultItems addObject:token];
                }
            }
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

#pragma mark - Helpers

- (NSString *)stringFromKey:(MSIDTokenCacheKey *)key
{
    return [NSString stringWithFormat:@"%@_%@_%@", key.account, key.service, key.type];
}

- (NSString *)regexFromKey:(MSIDTokenCacheKey *)key
{
    NSString *accountStr = key.account ?
        [self absoluteRegexFromString:key.account] : @".*";
    NSString *serviceStr = key.service ?
        [self absoluteRegexFromString:key.service] : @".*";
    NSString *typeStr = key.type ? key.type.stringValue : @".*";
    
    NSString *regexString = [NSString stringWithFormat:@"%@_%@_%@", accountStr, serviceStr, typeStr];
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

#pragma mark - Test methods

- (void)reset
{
    @synchronized (self)  {
        _cacheContents = [NSMutableDictionary dictionary];
        _wipeInfo = nil;
    }
}

- (NSArray *)allLegacyADFSTokens
{
    return [self allTokensWithType:MSIDTokenTypeLegacyADFSToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeLegacyADFSToken]];
}

- (NSArray *)allLegacyAccessTokens
{
    return [self allTokensWithType:MSIDTokenTypeAccessToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken]];
}

- (NSArray *)allLegacyRefreshTokens
{
    return [self allTokensWithType:MSIDTokenTypeRefreshToken
                        serializer:[[MSIDKeyedArchiverSerializer alloc] initForTokenType:MSIDTokenTypeRefreshToken]];
}

- (NSArray *)allDefaultAccessTokens
{
    return [self allTokensWithType:MSIDTokenTypeAccessToken
                        serializer:[[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken]];
}

- (NSArray *)allDefaultRefreshTokens
{
    return [self allTokensWithType:MSIDTokenTypeRefreshToken
                        serializer:[[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeRefreshToken]];
}

- (NSArray *)allTokensWithType:(MSIDTokenType)type
                    serializer:(id<MSIDTokenSerializer>)serializer
{
    NSMutableArray *results = [NSMutableArray array];
    
    @synchronized (self) {
        
        for (NSData *tokenData in [_cacheContents allValues])
        {
            MSIDBaseToken *token = [serializer deserialize:tokenData];
            
            if (token && token.tokenType == type && [self isValidTokenForType:type token:token])
            {
                [results addObject:token];
            }
        }
    }
    
    return results;
}

- (BOOL)isValidTokenForType:(MSIDTokenType)type token:(MSIDBaseToken *)token
{
    switch (type) {
        case MSIDTokenTypeAccessToken:
        {
            MSIDAccessToken *accessToken = (MSIDAccessToken *)token;
            return ![NSString msidIsStringNilOrBlank:accessToken.accessToken];
        }
            
        case MSIDTokenTypeRefreshToken:
        {
            MSIDRefreshToken *refreshToken = (MSIDRefreshToken *)token;
            return ![NSString msidIsStringNilOrBlank:refreshToken.refreshToken];
        }
            
        case MSIDTokenTypeLegacyADFSToken:
        {
            MSIDAdfsToken *adfsToken = (MSIDAdfsToken *)token;
            return ![NSString msidIsStringNilOrBlank:adfsToken.singleResourceRefreshToken]
                && ![NSString msidIsStringNilOrBlank:adfsToken.accessToken];
        }
            
        case MSIDTokenTypeIDToken:
        {
            MSIDIdToken *idToken = (MSIDIdToken *)token;
            return ![NSString msidIsStringNilOrBlank:idToken.rawIdToken];
        }
            
        default:
            break;
    }
}

@end
