//
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

#import "MSIDTokenRequest.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDConstants.h"

@class MSIDRequestParameters;
@class MSIDDeviceTokenResponseHandler;

NS_ASSUME_NONNULL_BEGIN
@interface MSIDDeviceTokenGrantRequest : MSIDTokenRequest

@property (nonatomic, readonly) MSIDWPJKeyPairWithCert *wpjInfo;

- (instancetype _Nullable)initWithEndpoint:(nonnull NSURL *)endpoint
                         requestParameters:(nonnull MSIDRequestParameters *)requestParameters
                                    scopes:(nullable NSString *)scope
                   registrationInformation:(nonnull MSIDWPJKeyPairWithCert *)registrationInformation
                                  resource:(nonnull NSString *)resource
                              enrollmentId:(nullable NSString *)enrollmentId
                           extraParameters:(nullable NSDictionary *)extraParameters
                                ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                      tokenResponseHandler:(nonnull MSIDDeviceTokenResponseHandler *)tokenResponseValidator
                                     error:(NSError **)error NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable)initWithEndpoint:(nonnull NSURL *)endpoint
                                authScheme:(nonnull MSIDAuthenticationScheme *)authScheme
                                  clientId:(nonnull NSString *)clientId
                                     scope:(nullable NSString *)scope
                                ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                                   context:(nullable id<MSIDRequestContext>)context NS_UNAVAILABLE;


- (void)executeRequestWithCompletion:(nonnull MSIDRequestCompletionBlock)completionBlock;

@end
NS_ASSUME_NONNULL_END
