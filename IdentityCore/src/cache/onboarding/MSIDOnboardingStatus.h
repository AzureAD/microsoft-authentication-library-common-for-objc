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
#import "MSIDJsonSerializable.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MSIDOnboardingPhase)
{
    MSIDOnboardingPhaseNone = 0,
    MSIDOnboardingPhaseBrokerInteractiveInProgress,
    MSIDOnboardingPhaseMdmEnrollmentInProgress,
    MSIDOnboardingPhaseFailed
};

typedef NS_ENUM(NSInteger, MSIDOnboardingContext)
{
    MSIDOnboardingContextUnknown = 0,
    MSIDOnboardingContextBroker,
    MSIDOnboardingContextInAppWebview
};

typedef NS_ENUM(NSInteger, MSIDOnboardingReasonCode)
{
    MSIDOnboardingReasonCodeNone = 0,
    MSIDOnboardingReasonCodeUserCancel,
    MSIDOnboardingReasonCodeNetwork,
    MSIDOnboardingReasonCodePolicy,
    MSIDOnboardingReasonCodeUnknown
};

@interface MSIDOnboardingReason : NSObject <MSIDJsonSerializable>

@property (nonatomic, readonly) MSIDOnboardingReasonCode code;
@property (nonatomic, readonly, nullable) NSString *message;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCode:(MSIDOnboardingReasonCode)code
                     message:(nullable NSString *)message;

@end

@interface MSIDOnboardingStatus : NSObject <MSIDJsonSerializable>

@property (nonatomic, readonly) NSInteger version;
@property (nonatomic, readwrite) MSIDOnboardingPhase phase;
@property (nonatomic, readonly) MSIDOnboardingContext onboardingContext;
@property (nonatomic, readonly) NSString *ownerBundleId;
@property (nonatomic, readonly) NSString *originatingBundleId;
@property (nonatomic, readonly, nullable) NSString *originatingDisplayName;
@property (nonatomic, readonly, nullable) NSUUID *correlationId;
@property (nonatomic, readonly, nullable) NSDate *startedAt;
@property (nonatomic, readonly) NSInteger ttlSeconds;
@property (nonatomic, readwrite, nullable) MSIDOnboardingReason *reason;

- (instancetype)initWithPhase:(MSIDOnboardingPhase)phase
              onboardingContext:(MSIDOnboardingContext)onboardingContext
                  ownerBundleId:(NSString *)ownerBundleId
                  correlationId:(nullable NSUUID *)correlationId;

#pragma mark - String/enum helpers

+ (MSIDOnboardingPhase)onboardingPhaseFromString:(NSString *)onboardingPhaseString;
+ (NSString *)stringFromPhase:(MSIDOnboardingPhase)phase;

+ (MSIDOnboardingContext)onboardingContextFromString:(NSString *)onboardingContextString;
+ (NSString *)stringFromContext:(MSIDOnboardingContext)context;

+ (MSIDOnboardingReasonCode)reasonCodeFromString:(NSString *)reasonCodeString;
+ (NSString *)stringFromReasonCode:(MSIDOnboardingReasonCode)code;

@end

NS_ASSUME_NONNULL_END
