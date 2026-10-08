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

#import <Foundation/Foundation.h>
#import "MSIDConstants.h"

@class MSIDRequestParameters;
@class MSIDExternalSSOContext;
@class MSIDHttpRequest;
@class MSIDWPJKeyPairWithCert;
@class MSIDDeviceTokenResponseHandler;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

typedef void (^MSIDDeviceTokenRequestCompletionBlock)(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error);

@interface MSIDDeviceTokenUtil : NSObject

+ (nullable NSURL *)getDeviceTokenEndpoint:(nonnull MSIDRequestParameters *)requestParameters
                                  tenantId:(nonnull NSString *)tenantId;

+ (void)getDeviceTokenRequest:(nonnull MSIDRequestParameters *)requestParameters
                     tenantId:(nonnull NSString *)tenantId
                     resource:(nonnull NSString *)resource
                 enrollmentId:(nullable NSString *)enrollmentId
              extraParameters:(nullable NSDictionary *)extraParameters
                   ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
              completionBlock:(nonnull MSIDDeviceTokenRequestCompletionBlock)completionBlock;

+ (nullable NSString *)getDeviceTokenRequestJwtForResource:(nonnull NSString *)resource
                                                    scopes:(nullable NSSet *)scopes
                                               redirectUri:(nonnull NSString *)redirectUri
                                                  audience:(nonnull NSString *)audience
                                                  clientId:(nonnull NSString *)clientId
                                                     nonce:(nullable NSString *)nonce
                                   registrationInformation:(nonnull MSIDWPJKeyPairWithCert *)registrationInformation
                                        extraPayloadClaims:(nullable NSDictionary *)extraPayloadClaims
                                                   context:(nullable id<MSIDRequestContext>)context
                                                     error:(NSError *__nullable __autoreleasing *__nullable)error;

/// Builds the device token request body parameters shared by the request builder and the grant request.
+ (nonnull NSMutableDictionary *)deviceTokenRequestBodyParametersWithJwt:(nonnull NSString *)signedJwt
                                                           enrollmentId:(nullable NSString *)enrollmentId
                                                        extraParameters:(nullable NSDictionary *)extraParameters;

+ (void)handleDeviceTokenResponse:(nullable NSDictionary *)tokenJsonResponse
                requestParameters:(nonnull MSIDRequestParameters *)requestParameters
                  responseHandler:(nullable MSIDDeviceTokenResponseHandler *)responseHandler
                            error:(nullable NSError *)error
                  completionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END

