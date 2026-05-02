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
#import "MSIDWebviewInteracting.h"
#import "MSIDConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Manages system webview sessions (ASWebAuthenticationSession,
 * SFSafariViewController) used for authentication transition flows from
 * embedded WKWebView navigation to system webview session.
 *
 * Ensures only one system webview session is active at any given time,
 * as required by iOS (one active ASWebAuthenticationSession per process).
 *
 * It is used when authentication transitions from an embedded WKWebView flow
 * to a system webview session and then returns control back to the
 * original WKWebView navigation via callback URL.
 *
 * Singleton:
 * - Provides a single shared instance to enforce serialized access to system
 *   webview sessions across the application process.
 */
@interface MSIDSystemWebviewTransitionManager : NSObject

/**
 * Returns the shared singleton instance.
 */
+ (instancetype)sharedInstance;

#if (TARGET_OS_IPHONE || TARGET_OS_OSX) && !MSID_EXCLUDE_SYSTEMWV

/**
 * Returns YES if a system web authentication session is currently active.
 */
@property (nonatomic, readonly) BOOL isSessionInProgress;

/**
 * Transitions to a system webview (ASWebAuthenticationSession or SFSafariViewController) with provided URL and parameters, and handles callback via completion block.
 *
 * If a session is already in progress, the completion block is invoked with an error.
 *
 * @param URL                        The URL to load in the system webview
 * @param redirectURI               The redirect URI used for callback interception
 * @param parentController          The view controller used for presentation
 * @param useAuthenticationSession  Whether to use ASWebAuthenticationSession
 * @param allowSafariViewController Whether SFSafariViewController fallback is allowed
 * @param useEphemeralSession       Whether to use an ephemeral session (ASWebAuthenticationSession only)
 * @param additionalHeaders         Optional HTTP headers (iOS 18+ and maOS 15+)
 * @param context                   Request context for logging and telemetry
 * @param completionBlock          Completion with callback URL or error (failure/cancellation)
 */
- (void)transitionToSystemWebviewWithURL:(NSURL *)URL
                             redirectURI:(NSString *)redirectURI
                        parentController:(MSIDViewController *)parentController
                useAuthenticationSession:(BOOL)useAuthenticationSession
               allowSafariViewController:(BOOL)allowSafariViewController
                     useEphemeralSession:(BOOL)useEphemeralSession
                       additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                                 context:(id<MSIDRequestContext>)context
                         completionBlock:(MSIDWebUICompletionHandler)completionBlock;

/**
 * Cancels the active system web authentication session, if any.
 *
 * If a session is active, it is terminated and the original completion block
 * is invoked with a cancellation error.
 *
 * No-op if no session is active.
 */
- (void)cancel;

#endif

@end

NS_ASSUME_NONNULL_END
