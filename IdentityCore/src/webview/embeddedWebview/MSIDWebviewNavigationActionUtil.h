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
#import "MSIDOAuth2EmbeddedWebviewController.h"

@class MSIDWebviewNavigationAction;

NS_ASSUME_NONNULL_BEGIN

/**
 * Utility class for resolving webview navigation actions from special URLs.
 * Parses msauth:// URLs and determines appropriate navigation actions based on
 * URL host, query parameters, and HTTP response headers.
 */
@interface MSIDWebviewNavigationActionUtil : NSObject

/**
 * Shared singleton instance.
 */
+ (instancetype)sharedInstance;

/**
 * Resolves navigation action for special redirect URLs.
 *
 * Supported schemes:
 * - msauth:// - Handles enrollment, compliance, and enrollment completion flows
 * - browser:// - Returns continueDefaultAction for legacy browser flow
 * - other - Returns continueDefaultAction for unknown schemes
 *
 * Supported msauth:// hosts:
 * - enroll: MDM enrollment flow
 * - compliance: Compliance check flow
 * - in_app_enrollment_complete: Profile installation completion
 *
 * @param url The special redirect URL to resolve (msauth://, browser://, etc.)
 * @param webviewController The webview controller handling the navigation
 * @param responseHeaders HTTP response headers for additional context
 * @param appName Name of the client app
 * @param appVersion The version of the client app
 * @param externalNavigationBlock Callback for controller-specific navigation logic
 * @return Navigation action to execute, or nil if URL cannot be processed
 */
- (MSIDWebviewNavigationAction * _Nullable)resolveActionForURL:(NSURL *)url
                                             webviewController:(id<MSIDWebviewInteracting>)webviewController
                                               responseHeaders:(NSDictionary<NSString *, NSString *> * _Nullable)responseHeaders
                                                       appName:(NSString *)appName
                                                    appVersion:(NSString *)appVersion
                                       externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock;
@end
NS_ASSUME_NONNULL_END
