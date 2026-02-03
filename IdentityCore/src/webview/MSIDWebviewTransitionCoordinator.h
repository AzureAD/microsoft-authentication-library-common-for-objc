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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

#if !MSID_EXCLUDE_WEBKIT

@class MSIDOAuth2EmbeddedWebviewController;
@class MSIDASWebAuthenticationSessionHandler;
@class MSIDViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Coordinates seamless transitions between embedded webview and ASWebAuthenticationSession
 * for profile installation flows without canceling the authentication request.
 */
@interface MSIDWebviewTransitionCoordinator : NSObject

/// The currently suspended embedded webview (kept alive during transition)
@property (nonatomic, nullable) MSIDOAuth2EmbeddedWebviewController *suspendedEmbeddedWebview;

/// The ASWebAuthenticationSession handler for profile installation
@property (nonatomic, nullable) MSIDASWebAuthenticationSessionHandler *profileSessionHandler;

/// Whether a transition is currently in progress
@property (nonatomic, readonly) BOOL isTransitioning;

/**
 * Suspends the embedded webview (hides UI but keeps it alive)
 * @param webview The embedded webview to suspend
 */
- (void)suspendEmbeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)webview;

/**
 * Launches ASWebAuthenticationSession with the profile installation URL
 * @param profileURL The URL to open for profile installation
 * @param parentController The parent view controller
 * @param callbackScheme The callback URL scheme (e.g., "msauth")
 * @param completionHandler Called when ASWebAuthenticationSession completes
 */
- (void)launchProfileInstallationSession:(NSURL *)profileURL
                        parentController:(MSIDViewController *)parentController
                          callbackScheme:(NSString *)callbackScheme
                       completionHandler:(void (^)(NSURL * _Nullable callbackURL, NSError * _Nullable error))completionHandler;

/**
 * Resumes the suspended embedded webview (shows UI and continues flow)
 */
- (void)resumeSuspendedEmbeddedWebview;

/**
 * Dismisses the ASWebAuthenticationSession if active
 */
- (void)dismissProfileInstallationSession;

/**
 * Cleans up all state (call when authentication completes or fails)
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END

#endif
