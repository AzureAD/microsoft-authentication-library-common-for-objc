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

NS_ASSUME_NONNULL_BEGIN

/// Read side of the broker <-> OneAuth device-onboarding-blob hand-off, factored into a
/// protocol so a consumer's telemetry layer can be unit-tested against a fake keychain.
@protocol MSIDDeviceOnboardingBlobHandoffReading <NSObject>

/// Returns the onboarding blob JSON persisted for @c sessionCorrelationId, or nil when there
/// is no entry. The keychain slot is keyed by @c sessionCorrelationId, so a read can only ever
/// surface the blob written for this exact request. The read is intentionally TTL-free: a blob is
/// always returned to its own session, even after a long detour through the system browser, so
/// late-returning users still get the broker-built steps. Residency is bounded by the clear-time
/// sweep, not by read.
- (nullable NSString *)readBlobJsonForSessionCorrelationId:(NSString *)sessionCorrelationId;

/// Removes the hand-off entry for @c sessionCorrelationId. Callers clear immediately after a
/// successful read so a stale blob can never bleed into a later request. As a side effect this
/// also garbage-collects EVERY other entry whose TTL has elapsed (e.g. a request the consumer never
/// read back), so abandoned blobs don't linger in the shared keychain.
- (void)clearBlobForSessionCorrelationId:(NSString *)sessionCorrelationId;

@end

/// Shared-keychain accessor that hands a device onboarding telemetry blob across the
/// broker <-> OneAuth process boundary when there is no IPC response to carry it.
///
/// Context: when the broker's embedded webview navigation resolves to a @c browser:// URL,
/// @c MSIDWebOpenBrowserResponseOperation foregrounds the system browser and fails the
/// interactive session with @c MSIDErrorSessionCanceledProgrammatically WITHOUT app-switching
/// a URL-scheme response back to OneAuth. OneAuth later synthesizes
/// @c MSIDErrorBrokerResponseNotReceived on becoming active, and the broker-built onboarding
/// blob would otherwise be lost. The broker persists its finalized blob here before the
/// hand-off; OneAuth recovers it on the error path and merges it with its own seed.
///
/// This type lives in the shared identity layer (alongside @c MSIDOnboardingStatusCache) so the
/// broker and OneAuth share ONE definition of the wire contract — the broker consumes it as
/// @c MSIDDeviceOnboardingBlobHandoffCache, OneAuth as the prefixed fork.
///
/// Storage: one keychain item per in-flight request in @c MSIDKeychainTokenCache.defaultKeychainGroup
/// (the same shared access group @c MSIDOnboardingStatusCache relies on), keyed by the request's
/// @c session_correlation_id. Keying by session id means a read only ever surfaces the blob for
/// that exact request and a clear only ever removes its own entry — no single-slot contention and
/// no need to validate a stored id against the caller.
///
/// Envelope (JSON):
///   {
///     "version":                <int>,     // schema version of THIS envelope (== envelopeVersion)
///     "session_correlation_id": "<uuid>",  // stored only so the clear-time TTL sweep can address
///                                          //   an expired entry by its key; the read path keys
///                                          //   off the keychain slot, not this field
///     "onboardingBlob":         "<blob>",  // the finalized onboarding blob JSON string
///     "written_at":             <epoch s>  // unix time; the clear-time sweep bounds residency
///                                          //   against the TTL (read does NOT enforce a TTL)
///   }
@interface MSIDDeviceOnboardingBlobHandoffCache : NSObject <MSIDDeviceOnboardingBlobHandoffReading>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Shared instance backed by the default keychain group.
+ (instancetype)sharedInstance;

/// TTL used only by the clear-time garbage-collection sweep to decide when an abandoned entry
/// (a request the consumer never read back) may be evicted. The read path does NOT apply this.
+ (NSTimeInterval)defaultTtlSeconds;

/// Envelope schema version stamped into every write.
+ (NSInteger)envelopeVersion;

/// Extracts @c session_correlation_id from a finalized onboarding blob JSON string, or nil if
/// the blob is missing/unparseable or carries no session id. Used to key the keychain slot.
+ (nullable NSString *)sessionCorrelationIdFromBlobJson:(nullable NSString *)blobJson;

/// Write side. In production the BROKER is the writer. @c blobJson is the finalized onboarding
/// blob JSON string and @c sessionCorrelationId is the request's session correlation id (the
/// broker derives it from the blob via @c sessionCorrelationIdFromBlobJson:). Stores under the
/// per-session key, overwriting any prior entry for the same id. Returns NO on blank input, a
/// @c blobJson that is not a valid JSON object, or a keychain failure.
- (BOOL)writeBlobJson:(NSString *)blobJson
forSessionCorrelationId:(NSString *)sessionCorrelationId;

@end

NS_ASSUME_NONNULL_END
