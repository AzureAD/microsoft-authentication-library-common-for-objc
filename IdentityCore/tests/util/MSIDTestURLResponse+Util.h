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

#import "MSIDTestURLResponse.h"

@interface MSIDTestURLResponse (Util)

+ (NSDictionary *)msidDefaultRequestHeaders;

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority;
+ (MSIDTestURLResponse *)discoveryResponseForAuthority:(NSString *)authority;

+ (NSDictionary *)tokenResponseWithAT:(NSString *)responseAT
                           responseRT:(NSString *)responseRT
                           responseID:(NSString *)responseID
                        responseScope:(NSString *)responseScope
                   responseClientInfo:(NSString *)responseClientInfo
                            expiresIn:(NSString *)expiresIn
                                 foci:(NSString *)foci
                         extExpiresIn:(NSString *)extExpiresIn;

//Overloaded method to avoid impact on other tests without refreshIn
+ (NSDictionary *)tokenResponseWithAT:(NSString *)responseAT
                           responseRT:(NSString *)responseRT
                           responseID:(NSString *)responseID
                        responseScope:(NSString *)responseScope
                   responseClientInfo:(NSString *)responseClientInfo
                            expiresIn:(NSString *)expiresIn
                                 foci:(NSString *)foci
                         extExpiresIn:(NSString *)extExpiresIn
                            refreshIn:(NSString *)refreshIn;


+ (MSIDTestURLResponse *)refreshTokenGrantResponseWithRT:(NSString *)requestRT
                                           requestClaims:(NSString *)requestClaims
                                           requestScopes:(NSString *)requestScopes
                                              responseAT:(NSString *)responseAT
                                              responseRT:(NSString *)responseRT
                                              responseID:(NSString *)responseID
                                           responseScope:(NSString *)responseScope
                                      responseClientInfo:(NSString *)responseClientInfo
                                                     url:(NSString *)url
                                            responseCode:(NSUInteger)responseCode
                                               expiresIn:(NSString *)expiresIn;

+ (MSIDTestURLResponse *)errorRefreshTokenGrantResponseWithRT:(NSString *)requestRT
                                                requestClaims:(NSString *)requestClaims
                                                requestScopes:(NSString *)requestScopes
                                                responseError:(NSString *)oauthError
                                                  description:(NSString *)oauthDescription
                                                     subError:(NSString *)subError
                                                          url:(NSString *)url
                                                 responseCode:(NSUInteger)responseCode;

+ (MSIDTestURLResponse *)refreshTokenGrantResponseForThrottling:(NSString *)requestRT
                                                  requestClaims:(NSString *)requestClaims
                                                  requestScopes:(NSString *)requestScopes
                                                     responseAT:(NSString *)responseAT
                                                     responseRT:(NSString *)responseRT
                                                     responseID:(NSString *)responseID
                                                  responseScope:(NSString *)responseScope
                                             responseClientInfo:(NSString *)responseClientInfo
                                                            url:(NSString *)url
                                                   responseCode:(NSUInteger)responseCode
                                                      expiresIn:(NSString *)expiresIn
                                                   enrollmentId:(NSString *)enrollmentId
                                                    redirectUri:(NSString *)redirectUri
                                                       clientId:(NSString *)clientId;

@end
