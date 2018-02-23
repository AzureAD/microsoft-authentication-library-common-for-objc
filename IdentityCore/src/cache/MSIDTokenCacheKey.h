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

@interface MSIDTokenCacheKey : NSObject <NSCopying, NSSecureCoding>

NS_ASSUME_NONNULL_BEGIN

@property(nullable) NSString *account;
@property(nullable) NSString *service;
@property(nullable) NSNumber *type;

- (nullable id)initWithAccount:(nullable NSString *)account
                       service:(nullable NSString *)service
                          type:(nullable NSNumber *)type;

/*!
 Key for ADFS user tokens, account will be @""
 */
+ (MSIDTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSURL *)authority
                                               clientId:(NSString *)clientId
                                               resource:(NSString *)resource;

/*!
 Key for ADAL tokens
 1. access tokens - single resource, one authority, one clientId and one upn.
 2. FRT & MRRT - null authority, one authority, one clientId and one upn.
 */
+ (MSIDTokenCacheKey *)keyWithAuthority:(NSURL *)authority
                               clientId:(NSString *)clientId
                               resource:(nullable NSString *)resource
                                    upn:(NSString *)upn;

/*!
 Key for MSAL tokens - single authority, one clientId, multiple scopes, and userId.
 Environment is derived from the authority
 */
+ (MSIDTokenCacheKey *)keyForAccessTokenWithAuthority:(NSURL *)authority
                                             clientId:(NSString *)clientId
                                               scopes:(NSOrderedSet<NSString *> *)scopes
                                               userId:(NSString *)userId;

/*!
 Key for getting all MSAL access tokens for a user
 */
+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUserId:(NSString *)userId
                                           environment:(NSString *)environment;

+ (MSIDTokenCacheKey *)keyForAllAccessTokens;

/*!
 Key for MSAL refresh tokens - one user, one clientId, and one environment
 */
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUserId:(NSString *)userId
                                           clientId:(NSString *)clientId
                                        environment:(NSString *)environment;

/*!
 Key for all MSAL refresh tokens for a client
 */
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId;

/*!
 Key for all items in the keychain
 */
+ (MSIDTokenCacheKey *)keyForAllItems;

/*!
 Helper method to get the clientId from the provided familyId
 */
+ (NSString *)familyClientId:(NSString *)familyId;

NS_ASSUME_NONNULL_END

@end
