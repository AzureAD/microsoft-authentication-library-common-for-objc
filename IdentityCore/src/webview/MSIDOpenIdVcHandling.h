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

@class MSIDAADOAuthEmbeddedWebviewController;

NS_ASSUME_NONNULL_BEGIN

/// Optional delegate for embedded-webview hosts that want to handle
/// `openid-vc://` navigations themselves instead of letting the controller
/// bounce out via `UIApplication.openURL` to a system-registered wallet.
///
/// The intended consumer is the Microsoft Authenticator SSO extension when
/// it eventually hosts the VID flow in-process. In that scenario the handler
/// presents the VID UI as a modal on top of the embedded webview so the
/// webview stays alive throughout — no cross-process round trip, no second
/// `acquireToken` call from the calling app.
///
/// When no handler is attached, the controller falls back to its default
/// behavior of mutating the `openid-vc://` URL with `x_ms_*` extension
/// parameters and dispatching `UIApplication.openURL` to a registered wallet
/// app (today's non-SSO-extension path).
@protocol MSIDOpenIdVcHandling <NSObject>

/// Called on the main thread when the embedded webview detects a navigation
/// to an `openid-vc://` URL. The webview navigation is cancelled by the
/// controller, but the webview itself is left presented and the auth session
/// is not terminated — the verifier's page is expected to drive the flow to
/// completion after the VID interaction resolves (typically via polling /
/// SSE / WebSocket), eventually navigating to the calling app's MSAL
/// redirect URI.
///
/// Implementations may:
///   * present in-process VID UI on top of `webviewController` (e.g. inside
///     the Authenticator SSO extension)
///   * hand off to a separately registered wallet app
///   * resolve the VID exchange in any other way
///
/// @param url                The full `openid-vc://` URL the webview
///                           attempted to navigate to. The controller has
///                           NOT mutated it with `x_ms_*` parameters before
///                           handing it off — the handler is responsible for
///                           any mutation it needs.
/// @param webviewController  The hosting controller. UI implementations
///                           should present modals on this controller. Do
///                           not retain it strongly.
/// @param callerRedirectUri  The calling app's MSAL redirect URI (the
///                           webview's `endURL`). Useful for handlers that
///                           need to construct a bounce-back URL when
///                           handing off externally.
/// @param correlationId      The current request's correlation ID, for
///                           telemetry / logging.
/// @param completion         Invoked when the handler is done. Pass an error
///                           if the handoff failed in a way that should
///                           terminate the auth session (the controller will
///                           then surface it to MSAL via
///                           `-endWebAuthWithURL:error:`); pass nil
///                           otherwise — the webview stays presented and the
///                           auth session remains alive.
- (void)handleOpenIdVcURL:(NSURL *)url
        webviewController:(MSIDAADOAuthEmbeddedWebviewController *)webviewController
        callerRedirectUri:(nullable NSString *)callerRedirectUri
            correlationId:(nullable NSUUID *)correlationId
               completion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
