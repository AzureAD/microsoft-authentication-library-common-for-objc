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

@class MSIDInteractiveTokenRequestParameters;
@class MSIDBrowserNativeMessageGetTokenRequest;
@class MSIDTokenResult;
@class MSIDAccountIdentifier;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/// Normalized acquisition outcome produced by an @c MSIDSPATokenAcquiring backend and consumed by
/// @c MSIDSPATokenProvider, which feeds it to @c MSIDBrowserNativeMessageGetTokenResponse so response
/// shaping stays single-sourced.
///
/// The outcome carries a single canonical @c tokenResult. A broker backend maps its freshly redeemed
/// @c MSIDBrokerOperationTokenResponse into a @c MSIDTokenResult via the
/// @c MSIDTokenResult+MSIDBrokerOperationTokenResponse category before populating this outcome.
@interface MSIDSPATokenAcquisitionResult : NSObject

@property (nonatomic, nullable) MSIDTokenResult *tokenResult;

/// Backend-supplied fallback account UPN used when the token result does not carry a username.
/// Local supplies @c result.account.username ?: request.loginHint; a broker backend can supply
/// @c request.accountId.displayableId.
@property (nonatomic, nullable) NSString *fallbackRequestAccountUpn;

@end

/// Backend pre-route decision, evaluated by @c MSIDSPATokenProvider before the shared
/// @c MSIDBrowserNativeMessageGetTokenRoutingPolicy runs. This is where backend-specific behavior the
/// shared routing policy does not model lives (for a broker backend: a missing PRT forcing
/// interactive, a signed-out early error, or a resolved default account). The local backend returns
/// an all-defaults instance, so routing follows the shared @c MSIDBrowserNativeMessageGetTokenRoutingPolicy.
@interface MSIDSPAPreRouteDecision : NSObject

/// When YES, skip the silent attempt and route straight to interactive.
@property (nonatomic) BOOL forceInteractive;

/// Optionally overrides the account identifier used for routing.
@property (nonatomic, nullable) MSIDAccountIdentifier *resolvedAccountIdentifier;

/// If non-nil, short-circuit the flow and return this error to the caller.
@property (nonatomic, nullable) NSError *earlyError;

@end

/// Completion block for a single silent or interactive acquisition attempt.
/// @param result Normalized outcome on success, otherwise nil.
/// @param error Populated when acquisition fails, otherwise nil.
typedef void (^MSIDSPATokenAcquirerCompletionBlock)(MSIDSPATokenAcquisitionResult *_Nullable result,
                                                     NSError *_Nullable error);

/// Pluggable acquisition backend for @c MSIDSPATokenProvider. It owns the backend-specific pieces of a
/// browser-native-message GetToken flow (request-parameter shaping plus the actual silent/interactive
/// acquisition) while the provider owns the shared orchestration (validation, routing, the
/// silent → interactive fallback, and response shaping).
///
/// Two implementations are planned: @c MSIDLocalSPATokenAcquirer (IdentityCore, in-process app flow)
/// and a broker acquirer (over the broker's silent/interactive token operations).
@protocol MSIDSPATokenAcquiring <NSObject>

/// Build the shared @c MSIDInteractiveTokenRequestParameters for this backend. Implementations call
/// the @c MSIDInteractiveTokenRequestParameters (BrowserNativeMessageGetToken) category with
/// backend-specific arguments and apply any backend augmentations.
- (nullable MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                        context:(nullable id<MSIDRequestContext>)context
                                                                          error:(NSError *_Nullable *_Nullable)error;

/// Pre-route decision (see @c MSIDSPAPreRouteDecision). The local backend returns an all-defaults
/// instance.
- (MSIDSPAPreRouteDecision *)preRouteDecisionForParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                   context:(nullable id<MSIDRequestContext>)context;

/// Attempt silent acquisition. Implementations return a normalized outcome, or an error. An
/// @c MSIDErrorInteractionRequired error signals the provider to run its interactive fallback.
- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(nullable id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock;

/// Attempt interactive acquisition.
- (void)acquireInteractiveWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(nullable id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
