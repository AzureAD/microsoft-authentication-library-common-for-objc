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
@protocol MSIDSPATokenAcquiring;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for a SPA token acquisition.
/// @param response Serialized browser-native-message response payload (JSON string) on success, otherwise nil.
/// @param error Populated when acquisition fails, otherwise nil.
typedef void (^MSIDSPATokenProviderCompletionBlock)(NSString *_Nullable response, NSError *_Nullable error);

/// Common Core orchestrator that services a browser-native-message GetToken request for a Single Page
/// Application (SPA) host such as OneAuth (embedded in Edge).
///
/// On unmanaged iOS the platform SSO Extension is unavailable, so the host cannot silently invoke the
/// broker through `ASAuthorizationSingleSignOnProvider`. Instead the host hands the GetToken request to
/// this provider, which owns the shared orchestration that would otherwise live behind the SSO Extension:
///   - transforms `MSIDBrowserNativeMessageGetTokenRequest` into the parameters used across Common Core,
///   - attempts silent acquisition when possible,
///   - falls back to interactive acquisition at most once when the request allows UI,
///   - shapes the browser-native-message GetToken response.
///
/// The actual silent/interactive acquisition and the backend-specific request-parameter shaping are
/// delegated to a pluggable `id<MSIDSPATokenAcquiring>` backend so the same orchestration serves both
/// the in-process local app flow (`MSIDLocalSPATokenAcquirer`) and the broker flow. The default backend
/// is `MSIDLocalSPATokenAcquirer`, which redeems a cached BART (Bound App Refresh Token) SPA against
/// ESTS in-process.
///
/// `MSIDBrowserNativeMessageGetTokenRequest.canShowUI` controls fallback behavior. When UI is not
/// allowed, the provider returns `MSIDErrorInteractionRequired` instead of launching interactive acquisition.
@interface MSIDSPATokenProvider : NSObject

/// Creates a provider backed by the default in-process local acquirer (`MSIDLocalSPATokenAcquirer`).
- (instancetype)init;

/// Creates a provider backed by the supplied acquisition backend.
/// @param acquirer The pluggable backend that performs silent/interactive acquisition.
- (instancetype)initWithAcquirer:(id<MSIDSPATokenAcquiring>)acquirer NS_DESIGNATED_INITIALIZER;

/// Acquire a SPA token for the supplied browser-native-message GetToken request.
/// @param request The GetToken request constructed by the host (e.g. OneAuth).
/// @param context Optional request context used for correlation and logging.
/// @param completionBlock Invoked with the serialized response payload or an error.
- (void)acquireTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                        context:(nullable id<MSIDRequestContext>)context
                completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
