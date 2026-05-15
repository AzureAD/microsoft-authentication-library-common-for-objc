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
 * @param completion Completion block - MUST be called exactly once
 */
- (void)handleSpecialRedirectURL:(NSURL *)URL
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion;

/**
 * Inspects HTTP response headers and, if a hand-off (e.g. ASWebAuthenticationSession)
 * is initiated, returns YES so the caller cancels the current WKWebView navigation.
 *
 * The asynchronous result of the hand-off is delivered via @c completion. If no
 * hand-off is initiated, returns NO and @c completion is NOT invoked.
 *
 * @param headers    HTTP response headers (raw `allHeaderFields`).
 * @param completion Invoked once when the hand-off resolves (only when YES is returned).
 * @return YES if a hand-off was initiated; NO otherwise.
 */
- (BOOL)processResponseHeaders:(NSDictionary *)headers
                    completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable decision,
                                         NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
