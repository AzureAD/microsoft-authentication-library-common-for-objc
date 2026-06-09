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
#import "MSIDBaseRequestController.h"
#import "MSIDTokenRequestProviding.h"
#import "MSIDRequestControlling.h"
#import "MSIDWebviewNavigationDelegate.h"

@class MSIDInteractiveTokenRequestParameters;
@class MSIDWebWPJResponse;
@class MSIDExternalRedirectContext;

/**
 * Block invoked fire-and-forget when the webview encounters a special redirect
 * (e.g. msauth://enroll) during an interactive sign-in.
 *
 * Higher-level SDKs (OneAuth) inject an implementation that performs silent
 * BRT acquisition using the snapshot in @c context.
 */
typedef void (^MSIDBRTAcquisitionBlock)(MSIDExternalRedirectContext * _Nonnull context);

@interface MSIDLocalInteractiveController : MSIDBaseRequestController <MSIDRequestControlling, MSIDWebviewNavigationDelegate>

@property (nonatomic, readonly, nullable) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;

/**
 * Optional block that is called fire-and-forget when a special redirect URL
 * is intercepted during the interactive flow.
 *
 * Set by the host SDK (e.g. OneAuth) before calling @c acquireToken:.
 */
@property (nonatomic, copy, nullable) MSIDBRTAcquisitionBlock brtAcquisitionBlock;

- (nullable instancetype)initWithInteractiveRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                         tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                        error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end
