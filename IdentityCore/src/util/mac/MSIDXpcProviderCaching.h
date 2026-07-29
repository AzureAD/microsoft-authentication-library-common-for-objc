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
#import "MSIDDeviceInfo.h"

@class MSIDXpcConfiguration;

NS_ASSUME_NONNULL_BEGIN

@protocol MSIDXpcProviderCaching <NSObject>

// cachedXpcProvider is the Xpc provider's identifier from cache. This value can be updated through SsoExtension request
@property (nonatomic) MSIDSsoProviderType cachedXpcProviderType;

// xpcConfiguration will be used for the Xpc flow, the value will be determined based on the cachedXpcProvider
@property (nonatomic) MSIDXpcConfiguration *xpcConfiguration;

// Cached NSXPCListenerEndpoint pointing at the broker instance. When non-nil, callers may build an
// instance NSXPCConnection directly from this endpoint and skip the dispatcher round-trip. The
// endpoint is in-memory only (not persisted) and must be cleared on connection interruption,
// invalidation, transport failure, or provider-type switch. Read-only externally; use
// setCachedBrokerInstanceEndpoint:forProviderType: to populate.
@property (nonatomic, readonly, nullable) NSXPCListenerEndpoint *cachedBrokerInstanceEndpoint;

- (BOOL)isXpcProviderInstalledOnDevice;
- (BOOL)validateCacheXpcProvider;

// Atomically stores the broker instance endpoint, but only if the cache's current
// cachedXpcProviderType still matches `providerType`. Returns YES on store, NO if the cache has
// switched providers since the dispatcher round-trip began (in which case the caller should
// discard the endpoint without retrying through the cache for this request).
//
// Use the cachedXpcProviderType captured before the dispatcher round-trip as `providerType`.
- (BOOL)setCachedBrokerInstanceEndpoint:(nullable NSXPCListenerEndpoint *)endpoint
                        forProviderType:(MSIDSsoProviderType)providerType;

// Clears the cached broker instance endpoint. Safe to call from any thread.
- (void)clearCachedBrokerInstanceEndpoint;

@end

NS_ASSUME_NONNULL_END
