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

/// Classifies a candidate seed JSON before instantiating a builder.
/// Callers (e.g. the broker) use this to decide whether to build, passthrough, or drop.
typedef NS_ENUM(NSInteger, MSIDOnboardingSeedClassification)
{
    /// Seed is missing, empty, not valid JSON, or not a JSON object. Drop entirely.
    MSIDOnboardingSeedClassificationMalformed = 0,

    /// Seed parsed as a JSON object, but `schema_version` is not the supported one.
    /// Caller should pass the original seed back unchanged in the response.
    MSIDOnboardingSeedClassificationUnknownVersion = 1,

    /// Seed parsed and `schema_version` is the supported one. Caller should build a builder.
    MSIDOnboardingSeedClassificationSupported = 2,
};

/// Builds the onboarding telemetry blob from a seed JSON provided by the xplat core.
/// Records steps with timestamps, blocking errors, and domain tracking.
/// `finalizeBlob` always returns a populated JSON blob carrying whatever has been
/// accumulated (seed fields, steps, blocking errors, ux flow, last loaded domain) so
/// the broker can round-trip its added telemetry on both the success and failure paths.
@interface MSIDOnboardingBlobBuilder : NSObject

/// Inspects the candidate seed JSON without producing a builder. Use to decide between
/// building (Supported), echoing back unchanged (UnknownVersion), or skipping (Malformed).
+ (MSIDOnboardingSeedClassification)classifySeedJson:(nullable NSString *)json;

- (instancetype)initWithSeedJson:(NSString *)json
                        clientId:(NSString *)clientId
                          target:(NSString *)target;

- (void)addStep:(NSString *)stepId timestamp:(NSDate *)timestamp;

- (void)addBlockingError:(NSString *)errorCode;

- (void)setLastLoadedDomain:(NSString *)domain;

- (void)addUxFlowUsed:(NSString *)flowTag;

/// Stamps `onboarding_mode` as `brokered` if and only if it is currently set to anything
/// other than `brokered` (including empty/missing). Idempotent — invoking again when the
/// mode is already `brokered` is a no-op. Used by the broker to take ownership of the blob
/// just before finalizing the response: the fact that the seed reached the broker is, by
/// itself, sufficient evidence that this session is brokered.
- (void)ensureBrokeredOnboardingMode;

/// Processes navigation response data for onboarding telemetry signals.
/// Extracts last-loaded domain from the URL host, reads blocking errors
/// from the x-ms-clitelem header, and records remediation steps for known error codes.
/// This consolidates the logic previously in the base webview controller so it can be
/// called from both the base webview controller and the navigation handler.
- (void)processResponseHeaders:(NSDictionary *)headers
                   responseURL:(NSURL *)responseURL;

/// Flag indicating whether the strong-auth (MFA) setup step has been recorded during
/// the session. `finalizeForEndURL:error:` reads this to decide whether to stamp
/// StrongAuthSetupCompleted on the success path; MDM completion is stamped elsewhere.
@property (nonatomic, readonly) BOOL strongAuthSetupStarted;

/// Records the terminal onboarding steps when the web flow ends. On the success path
/// (non-nil `endURL` and nil `error`) stamps StrongAuthSetupCompleted if the strong-auth
/// setup step was recorded during the session. Independently, if `endURL` points at a
/// well-known MDM-enrollment fwlink, stamps the mapped enrollment step. Safe to call on
/// either the success or failure path.
- (void)finalizeForEndURL:(nullable NSURL *)endURL error:(nullable NSError *)error;

/// Maps a terminal `endURL` that points at a well-known go.microsoft.com fwlink
/// (browser://go.microsoft.com/fwlink[/]?...LinkId=<id>...) to the onboarding step
/// that should be recorded. Returns nil for any URL that is not a recognized fwlink.
+ (nullable NSString *)onboardingStepForEndURL:(nullable NSURL *)endURL;

/// Returns the accumulated blob serialized as JSON. Always populated when the builder
/// was constructed (carries the seed fields plus any recorded steps, blocking errors,
/// ux flow, and last loaded domain). Returns @"" only if JSON serialization fails.
- (NSString *)finalizeBlob;

@end

NS_ASSUME_NONNULL_END
