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

@class MSIDWebviewNavigationDecision;
@class MSIDOAuth2EmbeddedWebviewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for handling special redirect schemes in webview navigation.
 * Allows controllers to intercept and process msauth:// and browser:// redirects.
 */
@protocol MSIDWebviewNavigationDelegate <NSObject>

@optional

/**
 * Called when webview encounters a special redirect scheme (msauth://, browser://)
 *
 * @param URL The redirect URL (e.g., msauth://enroll?url=...)
 * @param embeddedWebviewController The controller that drove the navigation, passed
 *        explicitly so the delegate does not have to reach back through shared state
 *        (which can race with session-completion cleanup).
 * @param completion Completion block - MUST be called exactly once
 */
- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion;

/**
 * Caches response headers, processes onboarding telemetry, and detects an
 * ASWebAuthenticationSession hand-off signal.
 * On YES, caller should cancel the WKWebView navigation and invoke the hand-off method below.
 *
 * Security: hand-off is honored only when the response URL is HTTPS and its host is on the allowlist.
 *
 * @param response    The HTTP navigation response containing headers and URL.
 * @param embeddedWebviewController The controller that drove the navigation, passed explicitly
 *        so the delegate does not have to reach back through shared state.
 * @return YES if headers signal a hand-off AND the response URL is from allowed origin; NO otherwise.
 */
- (BOOL)processNavigationResponseAndCheckForASWebAuthHandoff:(NSHTTPURLResponse *)response
                                   embeddedWebviewController:(nullable MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController;

#if !MSID_EXCLUDE_SYSTEMWV

/**
 * Performs the hand-off using the headers cached by the last
 * @c processNavigationResponseAndCheckForASWebAuthHandoff:embeddedWebviewController: call.
 *
 * @param completion Completion block - MUST be called exactly once; failures surface as a @c failWithError decision
 */
- (void)performASWebAuthenticationHandoffWithCompletion:(void (^)(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                  NSError * _Nullable error))completion;
#endif // !MSID_EXCLUDE_SYSTEMWV

@end

NS_ASSUME_NONNULL_END
