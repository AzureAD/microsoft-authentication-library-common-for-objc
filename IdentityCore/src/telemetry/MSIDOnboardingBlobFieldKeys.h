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

// JSON field keys owned by platform builders. C++ does NOT use these by name —
// EntityStore dynamically iterates the blob JSON for fan-out.
// Seed creation + aggregation keys come from OnboardingBlobConstants (Djinni-generated).

// Field keys for populated blob
extern NSString * const MSIDOnboardingBlobFieldBlockingErrors;
extern NSString * const MSIDOnboardingBlobFieldLastBlockingError;
extern NSString * const MSIDOnboardingBlobFieldLastLoadedDomain;
extern NSString * const MSIDOnboardingBlobFieldLastCompletedStep;
extern NSString * const MSIDOnboardingBlobFieldRemediationNeeded;
extern NSString * const MSIDOnboardingBlobFieldUxFlowUsed;

// Step ID values not used in C++ aggregation
extern NSString * const MSIDOnboardingBlobStepAuthenticationStarted;
extern NSString * const MSIDOnboardingBlobStepCredentialEntryCompleted;
extern NSString * const MSIDOnboardingBlobStepBrokerInstallPrompted;
extern NSString * const MSIDOnboardingBlobStepBrokerInstallPromptedForMDM;
extern NSString * const MSIDOnboardingBlobStepDeviceRegistrationStarted;
extern NSString * const MSIDOnboardingBlobStepDeviceRegistrationCompleted;
extern NSString * const MSIDOnboardingBlobStepFlowCompleted;
