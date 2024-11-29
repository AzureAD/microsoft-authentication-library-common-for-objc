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
#import "MSIDTokenRequestProviding.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"

@class MSIDWebviewResponse;
@class MSIDInteractiveRequestParameters;
@class MSIDOauth2Factory;
@class MSIDInteractiveTokenRequestParameters;

@interface MSIDWebResponseBaseOperation : NSObject

- (nullable instancetype)initWithResponse:(nonnull MSIDWebviewResponse *)response
                                    error:(NSError * _Nullable __autoreleasing *_Nullable)error;

- (void)invokeWithInteractiveTokenRequestParameters:(nonnull MSIDInteractiveRequestParameters *)interactiveTokenRequestParameters
                               tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                         completion:(nonnull MSIDRequestCompletionBlock)completion;

- (BOOL)doActionWithCorrelationId:(nullable NSUUID *)correlationId
                            error:(NSError * _Nullable __autoreleasing *_Nullable)error;

- (void)invokeWithRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)requestParameters
                       oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
  decidePolicyForBrowserActionBlock:(nullable MSIDExternalDecidePolicyForBrowserActionBlock)decidePolicyForBrowserActionBlock
                    completionBlock:(nonnull MSIDWebviewAuthCompletionHandler)completionBlock;
@end
