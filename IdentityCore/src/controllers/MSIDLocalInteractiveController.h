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

@class MSIDInteractiveTokenRequestParameters;
@class MSIDWebWPJResponse;
@class MSIDInteractiveWebviewHelper;

@interface MSIDLocalInteractiveController : MSIDBaseRequestController <MSIDRequestControlling>

@property (nonatomic, readonly, nullable) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;

/*!
 Helper for special URL handling. Replaces protocol-based approach with shared implementation.
 Created at start of interactive request when specialURLHandlingEnabled is YES.
 */
@property (nonatomic, strong, nullable) MSIDInteractiveWebviewHelper *webviewHelper;

/*!
 Feature flag to enable special URL handling flow.
 Default is NO. Set to YES to enable Intune MDM enrollment and special URL processing.
 */
@property (nonatomic, assign) BOOL specialURLHandlingEnabled;

/*!
 Tracks the current system webview (ASWebAuthenticationSession) if one is active.
 Used when opening system webview for operations like device enrollment.
 */
@property (nonatomic, strong, nullable) id currentSystemWebview;

/*!
 Acquires a Broker Refresh Token (BRT).
 Called by webview helper when BRT is needed.
 @param completion Completion block called with success/failure and optional error.
 */
- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/*!
 Retries the interactive request in broker context.
 Called by webview helper when broker retry is needed.
 @param url The URL that triggered the retry
 @param completion Completion block called with success/failure and optional error.
 */
- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url
                                          completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/*!
 Dismisses the embedded webview if it is currently presented.
 Called by webview helper after transferring flow to broker context.
 */
- (void)dismissEmbeddedWebviewIfPresent;

/*!
 Opens a system webview (ASWebAuthenticationSession) for operations requiring
 system-level authentication, such as device enrollment.
 Called by webview helper when system webview is needed.
 
 @param url The URL to open in the system webview
 @param headers Additional HTTP headers to include in the request
 @param purpose The purpose of the system webview operation
 @param completion Called when system webview completes or fails
 */
- (void)openSystemWebviewWithURL:(NSURL *)url
                         headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         purpose:(MSIDSystemWebviewPurpose)purpose
                      completion:(void (^)(NSURL * _Nullable callbackURL, NSError * _Nullable error))completion;

- (nullable instancetype)initWithInteractiveRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                         tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                        error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end
