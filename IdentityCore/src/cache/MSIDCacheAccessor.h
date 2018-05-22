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

@class MSIDOauth2Factory;
@class MSIDConfiguration;
@protocol MSIDRequestContext;
@class MSIDTokenResponse;
@class MSIDRefreshToken;
@class MSIDAccountIdentifier;
@protocol MSIDRefreshableToken;
@protocol MSIDTokenCacheDataSource;
@class MSIDBrokerResponse;
@class MSIDBaseToken;
@class MSIDAccount;

@protocol MSIDCacheAccessor <NSObject>

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
               otherCacheAccessors:(NSArray<id<MSIDCacheAccessor>> *)otherAccessors;

/*!
 This method saves all tokens to the cache based on the token response.
 All tokens include: access tokens, refresh tokens, id tokens, accounts depending on the SDK
 */
- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                configuration:(MSIDConfiguration *)configuration
                     response:(MSIDTokenResponse *)response
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error;

/*!
 This method saves all tokens to the cache based on the broker response.
 All tokens include: access tokens, refresh tokens, id tokens, accounts depending on the SDK
 If saveSSOStateOnly flag is passed, it only saves SSO artifacts (refresh tokens and accounts)
 */
- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
               brokerResponse:(MSIDBrokerResponse *)response
             saveSSOStateOnly:(BOOL)saveSSOStateOnly
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error;

/*!
 This method saves only the SSO artifacts to the cache based on the broker response.
 */
- (BOOL)saveSSOStateWithFactory:(MSIDOauth2Factory *)factory
                  configuration:(MSIDConfiguration *)configuration
                       response:(MSIDTokenResponse *)response
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(MSIDAccountIdentifier *)account
                                        familyId:(NSString *)familyId
                                   configuration:(MSIDConfiguration *)configuration
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error;

- (NSArray<MSIDAccount *> *)allAccountsForEnvironment:(NSString *)environment
                                             clientId:(NSString *)clientId
                                             familyId:(NSString *)familyId
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error;

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error;

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error;

@end
