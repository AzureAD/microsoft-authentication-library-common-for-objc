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
 * Manages launching and lifecycle of system webviews (ASWebAuthenticationSession, SFSafariViewController, etc.)
 *
 * Singleton - enforces that only one system webview is active app-wide at a time,
 * since iOS only allows one active system webview session at any given time.
 */
@interface MSIDSystemWebviewManager : NSObject

/**
 * Returns the shared singleton instance.
 */
+ (instancetype)sharedInstance;

#if (TARGET_OS_IPHONE || TARGET_OS_OSX) && !MSID_EXCLUDE_SYSTEMWV

/**
 * Whether a system webview session is currently in progress.
 * Derived from internal state - YES when a session is active, NO otherwise.
 */
@property (nonatomic, readonly) BOOL isSessionInProgress;

/**
 * Launches a system webview session for the given URL.
 * If a session is already in progress, the completion block is called with an error.
 *
 * @param URL                  The URL to load in the system webview
 * @param redirectURL           The redirect URI to listen for as the callback
 * @param parentController       The parent view controller to present from
 * @param useAuthenticationSession Whether to use ASWebAuthenticationSession
 * @param allowSafariViewController Whether SFSafariViewController is allowed as fallback
 * @param additionalHeaders      Optional HTTP headers (iOS 18+ ASWebAuthenticationSession only)
 * @param useEphemeralSession    Whether to use an ephemeral session (ASWebAuthenticationSession only)
 * @param context                Request context for logging and telemetry
 * @param completionBlock        Called with the callback URL on success, or an error on failure/cancellation
 */
- (void)launchSystemWebviewWithURL:(NSURL *)URL
                       redirectURI:(NSString *)redirectURL
                  parentController:(MSIDViewController *)parentController
          useAuthenticationSession:(BOOL)useAuthenticationSession
         allowSafariViewController:(BOOL)allowSafariViewController
               useEphemeralSession:(BOOL)useEphemeralSession
                 additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                           context:(id<MSIDRequestContext>)context
                   completionBlock:(MSIDWebUICompletionHandler)completionBlock;

#endif

@end

NS_ASSUME_NONNULL_END
