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

#import "MSIDTokenResponse.h"
#import "MSIDClientInfo.h"

@interface MSIDAADTokenResponse : MSIDTokenResponse

// Default properties for an AAD error response
@property (nonatomic, readonly, nullable) NSString *correlationId;

// Default properties for an AAD successful response
@property (nonatomic, readonly) NSInteger expiresOn;
@property (nonatomic, readonly) NSInteger extendedExpiresIn;
@property (nonatomic, readonly, nullable) MSIDClientInfo *clientInfo;
@property (nonatomic, readonly, nullable) NSString *familyId;
@property (nonatomic, readonly, nullable) NSString *suberror;
@property (nonatomic, readonly, nullable) NSString *additionalUserId;

// Custom properties that ADAL/MSAL handles
@property (nonatomic, readonly, nullable) NSString *speInfo;

// Derived properties
@property (nonatomic, readonly, nullable) NSDate *extendedExpiresOnDate;

- (nullable instancetype)initWithAccessToken:(nonnull NSString *)accessToken
                                refreshToken:(nullable NSString *)refreshToken
                                   expiresIn:(NSInteger)expiresIn
                                   expiresOn:(NSInteger)expiresOn
                           extendedExpiresIn:(NSInteger)extendedExpiresIn
                           extendedExpiresOn:(NSInteger)extendedExpiresOn
                                   tokenType:(nonnull NSString *)tokenType
                                       scope:(nullable NSString *)scope
                                       state:(nullable NSString *)state
                                     idToken:(nullable NSString *)idToken
                        additionalServerInfo:(nullable NSDictionary *)additionalServerInfo
                                       error:(nullable NSString *)error
                                    suberror:(nullable NSString *)suberror
                            errorDescription:(nullable NSString *)errorDescription
                                  clientInfo:(nullable MSIDClientInfo *)clientInfo
                                    familyId:(nullable NSString *)familyId
                            additionalUserId:(nullable NSString *)additionalUserId
                                     speInfo:(nullable NSString *)speInfo
                               correlationId:(nullable NSString *)correlationId;

@end
