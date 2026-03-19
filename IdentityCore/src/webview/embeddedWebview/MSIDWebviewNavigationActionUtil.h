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
 * Resolves navigation action for msauth:// URL.
 *
 * Supported msauth:// hosts:
 * - enroll: MDM enrollment flow
 * - compliance: Compliance check flow
 * - installprofile: Profile installation flow
 * - in_app_enrollment_complete: Profile installation completion
 *
 * @param url The msauth:// URL to resolve
 * @param responseHeaders HTTP response headers for additional context
 * @param intuneAuthToken Optional Intune auth token for compliance checks
 * @param isBrokerContext YES if called from broker context, NO if called from local controller
 * @param externalNavigationBlock Optional block to handle external navigation (e.g., browser URLs)
 * @return Navigation action to execute
 */
- (MSIDWebviewNavigationAction * _Nullable)resolveActionForMSAuthURL:(NSURL *)url
                                                   webviewController:(id<MSIDWebviewInteracting>)webviewController
                                                     responseHeaders:(NSDictionary<NSString *, NSString *> * _Nullable)responseHeaders
                                                     intuneAuthToken:(NSString * _Nullable)intuneAuthToken
                                                     isBrokerContext:(BOOL)isBrokerContext
                                             externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock;
@end
NS_ASSUME_NONNULL_END
