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

#import <Foundation/Foundation.h>
#import "MSIDTokenType.h"

@class MSIDAccount;
@class MSIDRequestParameters;
@class MSIDBaseToken;
@class MSIDTokenResponse;
@class MSIDRefreshToken;
@class MSIDOauth2Factory;
@class MSIDAccessToken;
@protocol MSIDAccountIdentifiers;

@protocol MSIDSharedCacheAccessor <NSObject>

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                requestParams:(MSIDRequestParameters *)requestParams
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error;

- (BOOL)saveSSOStateWithFactory:(MSIDOauth2Factory *)factory
                  requestParams:(MSIDRequestParameters *)requestParams
                       response:(MSIDTokenResponse *)response
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error;

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error;

// Retrieval
- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                            account:(id<MSIDAccountIdentifiers>)account
                      requestParams:(MSIDRequestParameters *)parameters
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error;

- (MSIDBaseToken *)getUpdatedToken:(MSIDBaseToken *)token
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error;

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error;

- (NSArray *)getAllTokensOfType:(MSIDTokenType)tokenType
                   withClientId:(NSString *)clientId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

// Removal
- (BOOL)removeToken:(MSIDBaseToken *)token
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error;

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error;

- (BOOL)removeAllTokensForAccount:(id<MSIDAccountIdentifiers>)account
                      environment:(NSString *)environment
                         clientId:(NSString *)clientId
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error;

/*
 It is supposed to be used in test apps only.
 */
- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error;

@end
