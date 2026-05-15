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
#import "MSIDWebviewInteracting.h"

#if !MSID_EXCLUDE_WEBKIT
#import "MSIDOAuth2EmbeddedWebviewController.h"
#endif

@class MSIDWebviewNavigationDecision;

NS_ASSUME_NONNULL_BEGIN

/**
 * Resolver that maps special redirect URLs (msauth://, browser://) to a
 * MSIDWebviewNavigationDecision.
 *
 * Parses msauth:// URLs and determines the appropriate navigation decision
 * based on URL host, query parameters, and HTTP response headers.
 */
@interface MSIDWebviewNavigationDecisionResolver : NSObject

/**
 * Shared singleton instance.
 */
+ (instancetype)sharedInstance;

#if !MSID_EXCLUDE_WEBKIT
/**
 * Resolves a navigation decision for a special redirect URL.
 *
 * Supported schemes:
 * - msauth:// - Handles enrollment, compliance, profile download, and in-app enrollment completion flows
 * - browser:// - Returns continueDefault for legacy browser flow
 * - other - Returns continueDefault for unknown schemes
 *
 * Supported msauth:// hosts:
 * - enroll: MDM enrollment flow
 * - compliance: Compliance check flow
 * - profile_download_complete: Profile download completion flow
 * - in_app_enrollment_complete: In-app enrollment completion flow
 *
 * @param URL The special redirect URL to resolve (msauth://, browser://, etc.). If nil, returns nil.
 * @param embeddedWebviewController The webview controller handling the navigation. May be nil for flows that do not require it.
 * @param responseHeaders HTTP response headers for additional context
 * @param appName Name of the client app
 * @param appVersion The version of the client app
 * @return Navigation decision to apply, or nil if the URL cannot be processed
 */
- (MSIDWebviewNavigationDecision * _Nullable)resolveDecisionForURL:(NSURL * _Nullable)URL
                                         embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                                                   responseHeaders:(NSDictionary<NSString *, NSString *> * _Nullable)responseHeaders
                                                           appName:(NSString *)appName
                                                        appVersion:(NSString *)appVersion;
#endif // !MSID_EXCLUDE_WEBKIT

@end
NS_ASSUME_NONNULL_END
