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
#import "MSIDInteractiveRequestControlling.h"

@class MSIDInteractiveTokenRequest;
@class MSIDSilentTokenRequest;
@class MSIDInteractiveTokenRequestParameters;
@class MSIDRequestParameters;
@class MSIDBrokerTokenRequest;
@class MSIDBrokerInvocationOptions;

@protocol MSIDTokenRequestProviding <NSObject>

- (nullable id<MSIDInteractiveRequestControlling>)interactiveTokenRequestWithParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters;
- (nullable MSIDSilentTokenRequest *)silentTokenRequestWithParameters:(nonnull MSIDRequestParameters *)parameters
                                                         forceRefresh:(BOOL)forceRefresh;

- (nullable MSIDBrokerTokenRequest *)brokerTokenRequestWithParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                                            brokerKey:(nonnull NSString *)brokerKey
                                               brokerApplicationToken:(NSString * _Nullable )brokerApplicationToken
                                                      sdkCapabilities:(nullable NSArray *)sdkCapabilities
                                                                error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (nullable MSIDInteractiveTokenRequest *)interactiveSSOExtensionTokenRequestWithParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters;

- (nullable MSIDInteractiveTokenRequest *)interactiveXpcTokenRequestWithParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters;

- (nullable MSIDSilentTokenRequest *)silentSSOExtensionTokenRequestWithParameters:(nonnull MSIDRequestParameters *)parameters
                                                                        forceRefresh:(BOOL)forceRefresh;

- (nullable MSIDSilentTokenRequest *)silentXpcTokenRequestWithParameters:(nonnull MSIDRequestParameters *)parameters
                                                                        forceRefresh:(BOOL)forceRefresh;

@end
