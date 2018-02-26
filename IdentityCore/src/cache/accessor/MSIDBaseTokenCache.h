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
#import "MSIDSSOStateShareable.h"

@protocol MSIDTokenCacheDataSource;
@protocol MSIDRefreshableToken;
@class MSIDTokenResponse;
@class MSIDBrokerResponse;
@class MSIDRefreshToken;
@class MSIDAccessToken;
@class MSIDTokenCacheItem;

@interface MSIDBaseTokenCache : NSObject <MSIDSSOStateShareable>

@property (nonatomic, readonly) id<MSIDTokenCacheDataSource> dataSource;
@property (nonatomic, readonly) NSArray<id<MSIDSSOStateShareable>> *allAccessors;

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
                secondaryAccessors:(NSArray<id<MSIDSSOStateShareable>> *)secondaryAccessors;

// Save operations
- (BOOL)saveTokensWithRequestParams:(MSIDRequestParameters *)requestParams
                           response:(MSIDTokenResponse *)response
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error;

- (BOOL)saveTokensWithBrokerResponse:(MSIDBrokerResponse *)response
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error;

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
             withAccount:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error;

- (MSIDAccessToken *)getATForAccount:(MSIDAccount *)account
                       requestParams:(MSIDRequestParameters *)parameters
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error;

/*!
 Returns a Multi-Resource Refresh Token (MRRT) Cache Item for the given parameters. A MRRT can
 potentially be used for many resources for that given user, client ID and authority.
 */
- (MSIDRefreshToken *)getRTForAccount:(MSIDAccount *)account
                        requestParams:(MSIDRequestParameters *)parameters
                              context:(id<MSIDRequestContext>)context
                                error:(NSError **)error;

/*!
 Returns a Family Refresh Token for the given authority, user and family ID, if available. A FRT can
 be used for many resources within a given family of client IDs.
 */
- (MSIDRefreshToken *)getFRTforAccount:(MSIDAccount *)account
                         requestParams:(MSIDRequestParameters *)parameters
                              familyId:(NSString *)familyId
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error;

/*!
 Returns all refresh tokens for a given client.
 */
- (NSArray<MSIDRefreshToken *> *)getAllClientRTs:(NSString *)clientId
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error;

// Removal operations for RT or ADFS RT
- (BOOL)removeRTForAccount:(MSIDAccount *)account
                     token:(MSIDBaseToken<MSIDRefreshableToken> *)token
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error;

// Protected
- (MSIDTokenCacheItem *)getLatestTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
                                        account:(MSIDAccount *)account
                                        context:(id<MSIDRequestContext>)context
                                          error:(NSError **)error;

- (BOOL)removeTokenCacheItem:(MSIDTokenCacheItem *)cacheItem
                     account:(MSIDAccount *)account
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error;

@end


