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

#import "MSIDOnboardingBlobBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDOnboardingBlobBuilder (MSIDTestUtil)

// A builder seeded with stable test defaults (schema 1.0.0, non-brokered mode,
// clientId "clientA", target "resource1"). Use across onboarding-telemetry tests
// instead of re-seeding a builder inline.
+ (instancetype)msidTestBuilder;

// Finalizes the blob and returns the ordered list of stamped step_id values from
// the "steps_list" array. Convenience for asserting which onboarding steps were stamped.
- (NSArray<NSString *> *)msidStampedStepIds;

// Finalizes the blob and returns the list of ux flow tags from the "ux_flow_used"
// array. Convenience for asserting which onboarding ux flows were tagged.
- (NSArray<NSString *> *)msidUxFlowsUsed;

@end

NS_ASSUME_NONNULL_END
