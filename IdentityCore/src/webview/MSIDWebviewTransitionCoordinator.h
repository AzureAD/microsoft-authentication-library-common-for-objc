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

#import "MSIDWebviewNavigationAction.h"
#import "MSIDConstants.h"

@class MSIDOAuth2EmbeddedWebviewController;
@class MSIDASWebAuthenticationSessionHandler;
@class MSIDViewController;


NS_ASSUME_NONNULL_BEGIN

/**
 * Coordinates seamless transitions between embedded webview and ASWebAuthenticationSession
 * for flows that require external authentication without canceling the authentication request.
 * This coordinator is generic and can be used for any flow requiring ASWebAuthenticationSession transition.
 */
@interface MSIDWebviewTransitionCoordinator : NSObject

/// The currently suspended embedded webview (kept alive during transition)
@property (nonatomic, nullable) MSIDOAuth2EmbeddedWebviewController *suspendedEmbeddedWebview;

/// The ASWebAuthenticationSession handler for external authentication flow
@property (nonatomic, nullable) MSIDASWebAuthenticationSessionHandler *aSWebAuthenticationSessionHandler;

/// Whether a transition is currently in progress
@property (nonatomic, readonly) BOOL isTransitioning;


/**
 * Suspends the embedded webview (hides UI but keeps it alive)
 * @param webview The embedded webview to suspend
 */
- (void)suspendEmbeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)webview;

/**
 * Launches ASWebAuthenticationSession for external authentication flow
 * @param url The URL to open in ASWebAuthenticationSession
 * @param parentController The parent view controller
 * @param additionalHeaders Optional HTTP headers to include in the request (iOS 18+)
 *
 */
- (void)launchASWebAuthenticationSession:(NSURL *)url
                        parentController:(MSIDViewController *)parentController
                       additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                 context:(id<MSIDRequestContext>)context
                              completion:(MSIDRequestCompletionBlock)completionBlock;
                       

- (void)launchASWebAuthenticationSessionWithUrl:(NSURL *)url
                               parentController:(MSIDViewController *)parentController
                              additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                       MSIDSystemWebviewPurpose:(MSIDSystemWebviewPurpose)systemWebViewPurpose
                                        context:(id<MSIDRequestContext>)context
                                     completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion;

/**
 * Resumes the suspended embedded webview (shows UI and continues flow)
 */
- (void)resumeSuspendedEmbeddedWebview;

/**
 * Dismisses the ASWebAuthenticationSession if active
 */
- (void)dismissASWebAuthenticationSession;

/**
 * Dismisses the suspended embedded webview (cancels and releases it)
 * Use this when you need to completely abandon the embedded webview and switch to a different flow
 */
- (void)dismissSuspendedEmbeddedWebview;

/**
 * Cleans up all state (call when authentication completes or fails)
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END

#endif
