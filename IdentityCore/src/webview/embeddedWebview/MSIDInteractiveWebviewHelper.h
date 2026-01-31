//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@class MSIDWebviewAction;
@class MSIDWebviewResponse;
@class MSIDSpecialURLViewActionResolver;
@protocol MSIDRequestContext;

typedef NS_ENUM(NSInteger, MSIDSystemWebviewPurpose);

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDInteractiveWebviewHelper is a shared implementation class for handling
 special URL interception in embedded webviews.
 
 This helper class consolidates all special URL handling logic (msauth://, browser://)
 and eliminates code duplication between broker and non-broker controllers.
 
 The helper:
 - Orchestrates BRT acquisition and retry logic based on broker context
 - Manages session state inline (BRT tracking, response headers)
 - Delegates actual BRT acquisition and broker retry to the parent controller
 - Resolves special URLs to webview actions
 - Handles system webview management
 
 This replaces the protocol-based approach (MSIDInteractiveWebviewHandler) with
 a cleaner helper pattern that avoids duplication and simplifies architecture.
 */
@interface MSIDInteractiveWebviewHelper : NSObject

#pragma mark - Properties

/*!
 Whether this helper is running in broker context.
 Set at initialization and readonly thereafter.
 Determines whether BRT acquisition and broker retry logic should be applied.
 */
@property (nonatomic, assign, readonly) BOOL isRunningInBrokerContext;

/*!
 Whether BRT acquisition has been attempted in this session.
 BRT acquisition logic (simplified):
 - Acquired on FIRST msauth:// or browser:// redirect if needed
 - Only ONE attempt per session (no retry)
 
 Check before acquisition: !brtAcquired && !brtAttemptAttempted
 */
@property (nonatomic, assign) BOOL brtAttemptAttempted;

/*! Whether BRT was successfully acquired in this session */
@property (nonatomic, assign) BOOL brtAcquired;

/*!
 HTTP response headers captured from the most recent navigation response.
 These headers may be needed for various flows:
 - msauth://installProfile: X-Intune-AuthToken, X-Install-Url
 - Telemetry: X-MS-Telemetry and other diagnostic headers
 - Future special URL flows that require header access
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *capturedResponseHeaders;

/*!
 Weak reference to parent controller (InteractiveController).
 Helper delegates BRT acquisition and broker retry back to controller.
 Generic type supports both MSIDLocalInteractiveController and ADBrokerInteractiveControllerWithPRT.
 */
@property (nonatomic, weak, nullable) id parentController;

/*!
 Weak reference to parent view controller for presenting UI.
 Used for openSystemWebviewWithURL to present ASWebAuthenticationSession.
 */
@property (nonatomic, weak, nullable) UIViewController *parentViewController;

/*!
 Weak reference to embedded webview controller for dismissal.
 Used for dismissEmbeddedWebviewIfPresent.
 */
@property (nonatomic, weak, nullable) id embeddedWebviewController;

/*!
 Weak reference to request context for logging.
 */
@property (nonatomic, weak, nullable) id<MSIDRequestContext> context;

/*!
 URL action resolver for mapping special URLs to actions.
 */
@property (nonatomic, strong, nullable) MSIDSpecialURLViewActionResolver *urlResolver;

/*!
 Tracks the current system webview (ASWebAuthenticationSession) if one is active.
 Used when opening system webview for operations like device enrollment.
 */
@property (nonatomic, strong, nullable) id currentSystemWebview;

#pragma mark - Initialization

/*!
 Initializes the helper with broker context flag.
 
 @param isRunningInBrokerContext YES if running in broker context, NO for non-broker (local)
 @return Initialized helper instance
 */
- (instancetype)initWithBrokerContext:(BOOL)isRunningInBrokerContext;

#pragma mark - Special URL Processing

/*!
 Processes special URL with full orchestration including async BRT acquisition if needed.
 
 This method handles the complete special URL processing flow:
 1. Checks if BRT acquisition is needed (non-broker only)
 2. Acquires BRT asynchronously if needed (network call)
 3. Resolves URL to appropriate action after BRT completes
 4. Returns action via completion block
 
 All business logic (BRT checks, async acquisition, retry decisions) is in the helper.
 Webview calls this method and simply executes the returned action.
 
 @param url The special URL to process (msauth:// or browser:// scheme)
 @param completion Called with action to execute (async if BRT needed) or error
 */
- (void)processSpecialURL:(NSURL *)url
               completion:(void (^)(MSIDWebviewAction * _Nullable action, NSError * _Nullable error))completion;

#pragma mark - Header Capture

/*!
 Called when HTTP response headers are received during webview navigation.
 
 This callback allows the helper to capture and store headers immediately as they arrive.
 Headers are received before navigation policy decisions, making them available for
 special URL processing.
 
 @param headers The HTTP response headers dictionary from the navigation response
 */
- (void)didReceiveHTTPResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers;

#pragma mark - System Webview Management

/*!
 Opens a system webview (ASWebAuthenticationSession) for operations requiring
 system-level authentication, such as device enrollment.
 
 @param url The URL to open in the system webview
 @param headers Additional HTTP headers to include in the request (e.g., X-Intune-AuthToken)
 @param purpose The purpose of the system webview operation
 @param completion Called when system webview completes or fails with callback URL or error
 */
- (void)openSystemWebviewWithURL:(NSURL *)url
                         headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                         purpose:(MSIDSystemWebviewPurpose)purpose
                      completion:(void (^)(NSURL * _Nullable callbackURL, NSError * _Nullable error))completion;

/*!
 Dismisses the embedded webview if it is currently presented.
 This is typically called after transferring the flow to broker context.
 */
- (void)dismissEmbeddedWebviewIfPresent;

#pragma mark - Telemetry

/*!
 Handles webview response for telemetry purposes.
 @param response The webview response to record.
 */
- (void)handleWebviewResponseForTelemetry:(MSIDWebviewResponse *)response;

@end

NS_ASSUME_NONNULL_END
