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

#import "MSIDJsonSerializable.h"
#import "MSIDIdTokenClaims.h"
#import "MSIDAccountType.h"
#import "MSIDConfiguration.h"
#import "MSIDError.h"

@protocol MSIDRefreshableToken;
@class MSIDBaseToken;

@interface MSIDTokenResponse : NSObject <MSIDJsonSerializable>

// Default properties for an openid error response
@property (nonatomic, readonly, nullable) NSString *error;
@property (nonatomic, readonly, nullable) NSString *errorDescription;
// Default properties for a successful openid response
@property (nonatomic, readonly) NSInteger expiresIn;
@property (nonatomic, readonly, nonnull) NSString *accessToken;
@property (nonatomic, readonly, nonnull) NSString *tokenType;
@property (nonatomic, readonly, nullable) NSString *refreshToken;
@property (nonatomic, readonly, nullable) NSString *scope;
@property (nonatomic, readonly, nullable) NSString *state;
@property (nonatomic, readonly, nullable) NSString *idToken;
// Additional properties that server sends
@property (nonatomic, readonly, nullable) NSDictionary *additionalServerInfo;

/* Derived properties */

// Error code based on oauth error response
@property (nonatomic, readonly) MSIDErrorCode oauthErrorCode;

// NSDate derived from expiresIn property and time received
@property (nonatomic, readonly, nullable) NSDate *expiryDate;

// Specifies if token in the token response is multi resource
@property (nonatomic, readonly) BOOL isMultiResource;

// Wrapper object around ID token
@property (nonatomic, readonly, nullable) MSIDIdTokenClaims *idTokenObj;

// Generic target of the access token, scope for base token response, resource for AAD v1
@property (nonatomic, readonly, nullable) NSString *target;

// Account type for an account generated from this response
@property (nonatomic, readonly) MSIDAccountType accountType;

- (nullable instancetype)initWithJSONDictionary:(nonnull NSDictionary *)json
                                   refreshToken:(nullable MSIDBaseToken<MSIDRefreshableToken> *)token
                                          error:(NSError * _Nullable __autoreleasing *_Nullable)error;

- (nullable instancetype)initWithAccessToken:(nonnull NSString *)accessToken
                                refreshToken:(nullable NSString *)refreshToken
                                   expiresIn:(NSInteger)expiresIn
                                   tokenType:(nonnull NSString *)tokenType
                                       scope:(nullable NSString *)scope
                                       state:(nullable NSString *)state
                                     idToken:(nullable NSString *)idToken
                        additionalServerInfo:(nullable NSDictionary *)additionalServerInfo
                                       error:(nullable NSString *)error
                            errorDescription:(nullable NSString *)errorDescription;

@end
