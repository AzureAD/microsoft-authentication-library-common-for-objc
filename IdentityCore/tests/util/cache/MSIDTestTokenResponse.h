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

@class MSIDAADV2TokenResponse;
@class MSIDAADV1TokenResponse;
@class MSIDTokenResponse;

@interface MSIDTestTokenResponse : NSObject

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponse;
+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithFamilyId:(NSString *)familyId;
+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithScopes:(NSOrderedSet<NSString *> *)scopes;
+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithRefreshToken:(NSString *)token;
+ (MSIDAADV2TokenResponse *)v2TokenResponseWithAT:(NSString *)accessToken
                                               RT:(NSString *)refreshToken
                                           scopes:(NSOrderedSet<NSString *> *)scopes
                                          idToken:(NSString *)idToken
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                         familyId:(NSString *)familyId;


+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponse;

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithAdditionalFields:(NSDictionary *)additionalFields;

+ (MSIDAADV1TokenResponse *)v1TokenResponseWithAT:(NSString *)accessToken
                                               rt:(NSString *)refreshToken
                                         resource:(NSString *)resource
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                              upn:(NSString *)upn
                                         tenantId:(NSString *)tenantId
                                 additionalFields:(NSDictionary *)additionalFields;

+ (MSIDAADV1TokenResponse *)v1TokenResponseWithAT:(NSString *)accessToken
                                               rt:(NSString *)refreshToken
                                         resource:(NSString *)resource
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                          idToken:(NSString *)idToken
                                 additionalFields:(NSDictionary *)additionalFields;

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithoutClientInfo;
+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithFamilyId:(NSString *)familyId;
+ (MSIDAADV1TokenResponse *)v1SingleResourceTokenResponse;
+ (MSIDAADV1TokenResponse *)v1SingleResourceTokenResponseWithAccessToken:(NSString *)accessToken
                                                            refreshToken:(NSString *)refreshToken;

+ (MSIDTokenResponse *)defaultTokenResponseWithAT:(NSString *)accessToken
                                               RT:(NSString *)refreshToken
                                           scopes:(NSOrderedSet<NSString *> *)scopes
                                         username:(NSString *)username
                                          subject:(NSString *)subject;

@end
