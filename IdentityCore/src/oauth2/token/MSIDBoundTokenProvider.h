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
#import "MSIDRequestContext.h"

@class MSIDBrowserNativeMessageGetTokenRequest;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for a bound-token acquisition.
/// @param response Serialized browser-native-message response payload (JSON string) on success, otherwise nil.
/// @param error Populated when acquisition fails, otherwise nil.
typedef void (^MSIDBoundTokenProviderCompletionBlock)(NSString *_Nullable response, NSError *_Nullable error);

/// Common Core orchestrator that services a browser-native-message GetToken request for a host such as
/// OneAuth (embedded in Edge).
///
/// On unmanaged iOS the platform SSO Extension is unavailable, so the host cannot silently invoke the
/// broker through `ASAuthorizationSingleSignOnProvider`. Instead the host hands the GetToken request to
/// this provider, which owns the orchestration that would otherwise live behind the SSO Extension:
///   - transforms `MSIDBrowserNativeMessageGetTokenRequest` into the parameters used across Common Core,
///   - decides whether to service the request silently or interactively,
///   - silent path: redeems a cached BART SPA against ESTS in-process (no broker flip),
///   - interactive path: flips to the broker (Authenticator) via URL scheme to mint the initial token.
@interface MSIDBoundTokenProvider : NSObject

/// Acquire a bound token for the supplied browser-native-message GetToken request.
/// @param request The GetToken request constructed by the host (e.g. OneAuth).
/// @param context Optional request context used for correlation and logging.
/// @param completionBlock Invoked with the serialized response payload or an error.
- (void)acquireBoundTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                             context:(nullable id<MSIDRequestContext>)context
                     completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock;

/// Completes an in-flight interactive broker flip when the host app receives the broker callback URL
/// (e.g. Edge receives `msauth.<edge-bundle-id>://auth?...`). The host's app delegate routes the URL
/// here, which correlates the response back to the controller that started the flip and drives the
/// completion block supplied to `acquireBoundTokenWithRequest:context:completionBlock:`.
/// @param url The callback URL delivered to the host app.
/// @param sourceApplication The bundle id of the app that opened the URL (the broker), if known.
/// @param context Optional request context used for correlation and logging.
/// @return YES if the callback was consumed as a broker response, otherwise NO.
+ (BOOL)completeInteractiveRequestWithURL:(NSURL *)url
                        sourceApplication:(nullable NSString *)sourceApplication
                                  context:(nullable id<MSIDRequestContext>)context;

@end

NS_ASSUME_NONNULL_END
