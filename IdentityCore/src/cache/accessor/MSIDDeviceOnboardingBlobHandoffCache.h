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
/// is no (unexpired, matching) entry. Implementations validate that the stored envelope's
/// session correlation id equals the argument and that the entry is within TTL.
- (nullable NSString *)readBlobJsonForSessionCorrelationId:(NSString *)sessionCorrelationId;

/// Removes the hand-off entry for @c sessionCorrelationId. Callers clear immediately after a
/// successful read so a stale blob can never bleed into a later request.
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
/// Storage: a single keychain item in @c MSIDKeychainTokenCache.defaultKeychainGroup (the same
/// shared access group @c MSIDOnboardingStatusCache already relies on). A single slot is
/// sufficient — at most one interactive request is in flight per app, and the read validates
/// @c session_correlation_id so an unrelated request can never consume a stale slot.
///
/// Envelope (JSON):
///   {
///     "version":                <int>,     // schema version of THIS envelope (== envelopeVersion)
///     "session_correlation_id": "<uuid>",  // MUST equal the seed's session correlation id
///     "onboardingBlob":         "<blob>",  // the finalized onboarding blob JSON string
///     "written_at":             <epoch s>  // unix time; the reader enforces the TTL
///   }
@interface MSIDDeviceOnboardingBlobHandoffCache : NSObject <MSIDDeviceOnboardingBlobHandoffReading>

/// Shared instance backed by the default keychain group.
+ (instancetype)sharedInstance;

/// Time-to-live applied to hand-off entries. Kept short: the entry only needs to survive the
/// user's round trip through the system browser back into OneAuth.
+ (NSTimeInterval)defaultTtlSeconds;

/// Envelope schema version stamped into every write.
+ (NSInteger)envelopeVersion;

/// Extracts @c session_correlation_id from a finalized onboarding blob JSON string, or nil if
/// the blob is missing/unparseable or carries no session id. Used to key the keychain slot.
+ (nullable NSString *)sessionCorrelationIdFromBlobJson:(nullable NSString *)blobJson;

/// Write side. In production the BROKER is the writer. @c blobJson must be a non-empty JSON
/// string whose @c session_correlation_id equals @c sessionCorrelationId. Overwrites any prior
/// slot (single-item cache). Returns NO on invalid input or a keychain failure.
- (BOOL)writeBlobJson:(NSString *)blobJson
forSessionCorrelationId:(NSString *)sessionCorrelationId;

@end

NS_ASSUME_NONNULL_END
