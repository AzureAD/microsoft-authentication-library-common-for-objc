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
/// `finalizeBlob` returns populated JSON only if blocking errors were recorded
/// (empty string otherwise).
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

- (void)setRemediationNeeded:(BOOL)needed;

- (void)addUxFlowUsed:(NSString *)flowTag;

/// Returns populated blob JSON if blocking errors were recorded, empty string otherwise.
- (NSString *)finalizeBlob;

@end

NS_ASSUME_NONNULL_END
