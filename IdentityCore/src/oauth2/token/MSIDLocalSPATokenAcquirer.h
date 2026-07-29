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
#import "MSIDSPATokenAcquiring.h"

@class MSIDDefaultTokenCacheAccessor;
@class MSIDAccountMetadataCacheAccessor;
@class MSIDDefaultSilentTokenRequest;

NS_ASSUME_NONNULL_BEGIN

/// Builds the token cache accessor used by the silent engine. Returns nil when a cache is
/// unavailable (e.g. non-iOS platforms), which the acquirer surfaces as interaction-required.
typedef MSIDDefaultTokenCacheAccessor *_Nullable (^MSIDLocalSPATokenCacheProvider)(id<MSIDRequestContext> _Nullable context);

/// Builds the account metadata cache accessor used by the silent engine.
typedef MSIDAccountMetadataCacheAccessor *_Nullable (^MSIDLocalSPAAccountMetadataCacheProvider)(id<MSIDRequestContext> _Nullable context);

/// Builds the silent token request (engine) for the supplied parameters and caches.
typedef MSIDDefaultSilentTokenRequest *_Nonnull (^MSIDLocalSPASilentTokenRequestProvider)(MSIDInteractiveTokenRequestParameters *_Nonnull parameters,
                                                                                          MSIDDefaultTokenCacheAccessor *_Nonnull tokenCache,
                                                                                          MSIDAccountMetadataCacheAccessor *_Nonnull accountMetadataCache);

/// Local-app (no SSO extension) acquisition backend for @c MSIDSPATokenProvider.
///
/// This backend owns the in-process silent engine wiring that was previously inlined in
/// @c MSIDBoundTokenProvider: it builds a bound-token request (BART requested), constructs the
/// default silent token request against the shared adalcache keychain, and redeems a cached BART
/// against ESTS. Interactive acquisition (the broker app flip) is not yet implemented and currently
/// surfaces @c MSIDErrorInteractionRequired.
///
/// The cache and silent-engine dependencies are constructor-injected so tests can substitute
/// in-memory caches and a canned silent engine without subclassing. Passing nil for any provider
/// uses the production default.
@interface MSIDLocalSPATokenAcquirer : NSObject <MSIDSPATokenAcquiring>

/// Production initializer: builds real keychain-backed caches and the real silent engine.
- (instancetype)init;

/// Designated initializer. Any nil provider falls back to the production default.
- (instancetype)initWithTokenCacheProvider:(nullable MSIDLocalSPATokenCacheProvider)tokenCacheProvider
              accountMetadataCacheProvider:(nullable MSIDLocalSPAAccountMetadataCacheProvider)accountMetadataCacheProvider
                silentTokenRequestProvider:(nullable MSIDLocalSPASilentTokenRequestProvider)silentTokenRequestProvider NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
