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

#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDOpenIdVcHandling.h"

#if !MSID_EXCLUDE_WEBKIT

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAADOAuthEmbeddedWebviewController : MSIDOAuth2EmbeddedWebviewController

- (id)init NS_UNAVAILABLE;

/// Optional handler for `openid-vc://` navigations encountered by the embedded
/// webview. When set, the controller delegates handoff entirely to the handler
/// (allowing in-process VID UI to be presented on top of the webview without
/// any cross-process round trip). When nil, the controller falls back to its
/// default behavior of mutating the URL with Microsoft-namespaced query
/// parameters and dispatching `UIApplication.openURL` to a registered wallet.
@property (nonatomic, weak, nullable) id<MSIDOpenIdVcHandling> openIdVcHandler;

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(nullable void (^)(WKNavigationActionPolicy))decisionHandler;

@end

NS_ASSUME_NONNULL_END

#endif
