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

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebviewNavigationAction.h"
#import "MSIDConstants.h"

@class MSIDOAuth2EmbeddedWebviewController;
@class MSIDASWebAuthenticationSessionHandler;
@class MSIDViewController;


NS_ASSUME_NONNULL_BEGIN

/**
 * Handles transitions between embedded WKWebView and ASWebAuthenticationSession.
 * Used primarily for flows where authentication must temporarily
 * switch to system webview for security, then return to embedded webview (MDM profile installation).
 *
 * This is generic and can be used for any flow requiring ASWebAuthenticationSession transition.
 *
 * Responsibilities:
 * - Suspend embedded webview (hide but keep alive)
 * - Launch ASWebAuthenticationSession with configuration
 * - Resume embedded webview after ASWebAuth completes
 * - Cleanup resources
 */
@interface MSIDWebviewTransitionHandler : NSObject

/**
 * Suspends the embedded webview by hiding it while keeping it alive in memory.
 * The webview can be resumed later with resumeSuspendedEmbeddedWebview.
 *
 * @param embeddedWebview The webview to suspend
 */
- (void)suspendEmbeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebview;

/**
 * Launches ASWebAuthenticationSession and returns navigation action.
 *
 * @param url The URL to load in ASWebAuthenticationSession
 * @param parentController The parent view controller to present from (iOS only)
 * @param additionalHeaders Optional headers to pass (e.g., x-ms-intune-token)
 * @param purpose The purpose of the system webview (e.g., install profile)
 * @param context Request context for logging and telemetry
 * @param completion Completion handler with navigation action or error
 */
- (void)launchASWebAuthenticationSessionWithUrl:(NSURL *)url
                               parentController:(MSIDViewController *)parentController
                              additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                       MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)purpose
                                        context:(id<MSIDRequestContext>)context
                                     completion:(void (^)(MSIDWebviewNavigationAction * _Nonnull action, NSError * _Nonnull error))completion;

/**
 * Resumes the previously suspended embedded webview.
 * Makes it visible again and restores its state.
 */
- (void)resumeSuspendedEmbeddedWebview;

/**
 * Dismisses the ASWebAuthenticationSession if it is currently active.
 * This will cancel the session and clean up the session handler reference.
 */
- (void)dismissASWebAuthenticationSession;

/**
 * Dismisses the suspended embedded webview by canceling it and releasing the reference.
 * Use this when you need to completely abandon the embedded webview and switch to a different flow.
 */
- (void)dismissSuspendedEmbeddedWebview;

/**
 * Cleans up resources.
 * Dismisses ASWebAuthenticationSession if active and releases suspended webview reference.
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END

#endif
