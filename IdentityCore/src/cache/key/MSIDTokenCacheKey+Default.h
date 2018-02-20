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

#import "MSIDTokenCacheKey.h"
#import "MSIDAccountItem.h"

@interface MSIDTokenCacheKey (Default)

NS_ASSUME_NONNULL_BEGIN

/*!
 Key for MSAL tokens - single authority, one clientId, multiple scopes, and userId.
 Environment is derived from the authority
 */
+ (MSIDTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
                                             environment:(NSString *)environment
                                                clientId:(NSString *)clientId
                                                   realm:(NSString *)realm
                                                  target:(NSString *)target;

+ (MSIDTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
                                               authority:(NSURL *)authority
                                                clientId:(NSString *)clientId
                                                  scopes:(NSOrderedSet<NSString *> *)scopes;

+ (MSIDTokenCacheKey *)keyForIDTokenWithUniqueUserId:(NSString *)userId
                                           authority:(NSURL *)authority
                                            clientId:(NSString *)clientId;

+ (MSIDTokenCacheKey *)keyForAccountWithUniqueUserId:(NSString *)userId
                                           authority:(NSURL *)authority
                                            clientId:(NSString *)clientId
                                         accountType:(MSIDAccountType)accountType;
/*!
 Key for getting all MSAL access tokens for a user, environment and clientId
 */
+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                 environment:(NSString *)environment
                                                    clientId:(NSString *)clientId
                                                       realm:(NSString *)realm;

+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                   authority:(NSURL *)authority
                                                    clientId:(NSString *)clientId;

+ (MSIDTokenCacheKey *)keyForAllAccessTokens;

/*!
 Key for MSAL refresh tokens - one user, one clientId, and one environment
 */
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUniqueUserId:(NSString *)userId
                                              environment:(NSString *)environment
                                                 clientId:(NSString *)clientId;

/*!
 Key for all MSAL refresh tokens for a client
 */
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId;

NS_ASSUME_NONNULL_END

@end
