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

#import "MSIDTestCacheAccessor.h"
#import "MSIDError.h"
#import "MSIDAccount.h"

@interface MSIDTestCacheAccessor()
{
    NSMutableDictionary *_cacheContents;
}

@end

@implementation MSIDTestCacheAccessor

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _cacheContents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (BOOL)saveAccessToken:(MSIDToken *)token
                account:(MSIDAccount *)account
          requestParams:(MSIDRequestParameters *)parameters
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (!parameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    return [self saveTokenForAccount:account token:token context:context error:error];
}

- (MSIDToken *)getATForAccount:(MSIDAccount *)account
                 requestParams:(MSIDRequestParameters *)parameters
                       context:(id<MSIDRequestContext>)context
                         error:(NSError * __autoreleasing *)error
{
    return [self getTokenForAccount:account
                          tokenType:MSIDTokenTypeAccessToken
                             params:parameters
                            context:context
                              error:error];
}

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account
                  refreshToken:(MSIDToken *)refreshToken
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    return [self saveTokenForAccount:account token:refreshToken context:context error:error];
}


- (MSIDToken *)getSharedRTForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    return [self getTokenForAccount:account
                          tokenType:MSIDTokenTypeRefreshToken
                             params:parameters
                            context:context
                              error:error];
}

- (NSArray<MSIDToken *> *)getAllSharedRTsWithParams:(MSIDRequestParameters *)parameters
                                            context:(id<MSIDRequestContext>)context
                                              error:(NSError **)error
{
    if (!parameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSMutableArray *resultTokens = [NSMutableArray array];
    
    @synchronized (self) {
        
        // Filter out tokens based on the clientId
        for (NSString *key in [_cacheContents allKeys])
        {
            NSArray *contents = _cacheContents[key];
            
            for (MSIDToken *token in contents)
            {
                if (token.tokenType == MSIDTokenTypeRefreshToken
                    && [token.clientId isEqualToString:parameters.clientId])
                {
                    [resultTokens addObject:token];
                }
            }
        }
    }
    
    return  resultTokens;
}

- (BOOL)removeSharedRTForAccount:(MSIDAccount *)account
                           token:(MSIDToken *)token
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (!account
        || !token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSString *tokenIdentifier = [self tokenIdentifierForAccount:account tokenType:token.tokenType];
    
    NSMutableArray *accountTokens = nil;
    
    @synchronized (self) {
        accountTokens = _cacheContents[tokenIdentifier];
    }
    
    if (accountTokens)
    {
        [accountTokens removeObject:token];
    }
    
    return YES;
}

#pragma mark - Helpers

- (BOOL)saveTokenForAccount:(MSIDAccount *)account
                      token:(MSIDToken *)token
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    if (!token
        || !account)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSString *tokenIdentifier = [self tokenIdentifierForAccount:account tokenType:token.tokenType];
    
    NSMutableArray *accountTokens = nil;
    
    @synchronized (self) {
        accountTokens = _cacheContents[tokenIdentifier];
    }
    
    if (!accountTokens)
    {
        accountTokens = [NSMutableArray array];
    }
    
    [accountTokens addObject:token];
    
    @synchronized (self) {
        _cacheContents[tokenIdentifier] = accountTokens;
    }
    
    return YES;
}

- (MSIDToken *)getTokenForAccount:(MSIDAccount *)account
                        tokenType:(MSIDTokenType)tokenType
                           params:(MSIDRequestParameters *)parameters
                          context:(id<MSIDRequestContext>)context
                            error:(NSError * __autoreleasing *)error
{
    if (!account
        || !parameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Missing parameter", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSString *tokenIdentifier = [self tokenIdentifierForAccount:account tokenType:tokenType];
    
    NSMutableArray *accountTokens = nil;
    
    @synchronized (self) {
        accountTokens = _cacheContents[tokenIdentifier];
    }
    
    if (!accountTokens || ![accountTokens count])
    {
        return nil;
    }
    
    return accountTokens[0];
}

- (NSString *)tokenIdentifierForAccount:(MSIDAccount *)account
                              tokenType:(MSIDTokenType)tokenType
{
    NSString *userIdentifier = account.userIdentifier;
    
    if (!userIdentifier)
    {
        userIdentifier = account.upn;
    }
    
    return [NSString stringWithFormat:@"%@_%@", userIdentifier, [self tokenTypeAsString:tokenType]];
}

- (NSString *)tokenTypeAsString:(MSIDTokenType)tokenType
{
    NSString *typeIdentifier = @"at";
    
    if (tokenType == MSIDTokenTypeRefreshToken)
    {
        typeIdentifier = @"rt";
    }
    
    return typeIdentifier;
}

#pragma mark - Test Utils

- (void)addToken:(MSIDToken *)token forAccount:(MSIDAccount *)account
{
    [self saveTokenForAccount:account token:token context:nil error:nil];
}

- (void)reset
{
    @synchronized (self) {
        _cacheContents = [NSMutableDictionary dictionary];
    }
}

- (NSArray *)allAccessTokens
{
    return [self allTokensWithType:MSIDTokenTypeAccessToken];
}

- (NSArray *)allRefreshTokens
{
    return [self allTokensWithType:MSIDTokenTypeRefreshToken];
}

- (NSArray *)allTokensWithType:(MSIDTokenType)type
{
    NSMutableArray *resultTokens = [NSMutableArray array];
    
    @synchronized (self) {
       
        // Filter out tokens based on the token type
        for (NSString *key in [_cacheContents allKeys])
        {
            if ([key hasSuffix:[self tokenTypeAsString:type]]
                && _cacheContents[key])
            {
                [resultTokens addObjectsFromArray:_cacheContents[key]];
            }
        }
        
    }
    
    return resultTokens;
}

@end
