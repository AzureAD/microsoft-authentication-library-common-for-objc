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

@interface MSIDTokenCacheKey : NSObject

NS_ASSUME_NONNULL_BEGIN

@property(nullable) NSString *account;
@property(nullable) NSString *service;

- (nullable id)initWithAccount:(nullable NSString *)account
                       service:(nullable NSString *)service;

// adal tokens

// Key for ADFS User tokens
+ (MSIDTokenCacheKey *)keyForAdfsUserTokenWithAuthority:(NSURL *)authority
                                               clientId:(NSString *)clientId
                                               resource:(NSString *)resource;

// Key for ADAL tokens:
//   Single resource,
//   null resource for refresh tokens (FRT, MRRT)
+ (MSIDTokenCacheKey *)keyWithAuthority:(NSURL *)authority
                               clientId:(NSString *)clientId
                               resource:(nullable NSString *)resource
                                    upn:(NSString *)upn;

// msal at
// Single MSAL access token
+ (MSIDTokenCacheKey *)keyForAccessTokenWithAuthority:(NSURL *)authority
                                             clientId:(NSString *)clientId
                                               scopes:(NSOrderedSet<NSString *> *)scopes
                                               userId:(NSString *)userId;


+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUserId:(NSString *)userId
                                           environment:(NSString *)environment;


// rt with uid and utid
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUserId:(NSString *)userId
                                           clientId:(NSString *)clientId
                                        environment:(NSString *)environment;

+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId;

// All items key
+ (MSIDTokenCacheKey *)keyForAllItems;

NS_ASSUME_NONNULL_END

@end
