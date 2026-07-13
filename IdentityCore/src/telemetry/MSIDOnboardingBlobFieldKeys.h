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

// IPC envelope key under which the blob (seed on request, finalized on response)
// travels between MSAL/OneAuth and the broker. Both sides reference this constant.
extern NSString * const MSIDOnboardingBlobIPCKey;

// Onboarding mode values (seed `onboarding_mode` field). Used by builders/consumers to
// decide whether a session is brokered before finalizing the blob.
extern NSString * const MSIDOnboardingModeBrokered;

// UX flow tags (appended to the `ux_flow_used` array). Records which onboarding UX a session went through.
extern NSString * const MSIDOnboardingUxFlowMobileOnboardingPhase1;

// Field keys for populated blob
extern NSString * const MSIDOnboardingBlobFieldBlockingErrors;
extern NSString * const MSIDOnboardingBlobFieldLastBlockingError;
extern NSString * const MSIDOnboardingBlobFieldLastLoadedDomain;
extern NSString * const MSIDOnboardingBlobFieldLastCompletedStep;
extern NSString * const MSIDOnboardingBlobFieldUxFlowUsed;

// Step ID values not used in C++ aggregation
extern NSString * const MSIDOnboardingBlobStepAuthenticationStarted;
extern NSString * const MSIDOnboardingBlobStepDeviceNotCompliant;
extern NSString * const MSIDOnboardingBlobStepCredentialEntryCompleted;
extern NSString * const MSIDOnboardingBlobStepBrokerInstallPrompted;
extern NSString * const MSIDOnboardingBlobStepBrokerAppInstall;
extern NSString * const MSIDOnboardingBlobStepBrokerInstallPromptedForMAM;
extern NSString * const MSIDOnboardingBlobStepDeviceRegistrationRequired;
extern NSString * const MSIDOnboardingBlobStepDeviceRegistrationStarted;
extern NSString * const MSIDOnboardingBlobStepDeviceRegistrationCompleted;
extern NSString * const MSIDOnboardingBlobStepJITRegistrationStarted;
extern NSString * const MSIDOnboardingBlobStepJITRegistrationCompleted;
extern NSString * const MSIDOnboardingBlobStepJITLinkingStarted;
extern NSString * const MSIDOnboardingBlobStepJITLinkingCompleted;
extern NSString * const MSIDOnboardingBlobStepJITRemediationStarted;
extern NSString * const MSIDOnboardingBlobStepJITRemediationCompleted;
extern NSString * const MSIDOnboardingBlobStepJITComplianceBitSetStarted;
extern NSString * const MSIDOnboardingBlobStepJITComplianceBitSetCompleted;
extern NSString * const MSIDOnboardingBlobStepTokenIssued;

// New mobile-onboarding funnel steps (free-form passthrough; not C++-aggregated).
extern NSString * const MSIDOnboardingBlobStepProfileDownloadCompleted;
extern NSString * const MSIDOnboardingBlobStepComplianceRemediationStarted;
extern NSString * const MSIDOnboardingBlobStepMobileOnboardingClientDisabledFallback;
extern NSString * const MSIDOnboardingBlobStepMdmProfileInstallNotificationScheduled;
extern NSString * const MSIDOnboardingBlobStepSSOExtensionUnavailable;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentCompletionStarted;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentCompletionFallbackErrorUrlLoaded;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentRequestMalformed;
extern NSString * const MSIDOnboardingBlobStepComplianceRequestMalformed;
extern NSString * const MSIDOnboardingBlobStepProfileInstallUrlMalformed;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentFailed;
extern NSString * const MSIDOnboardingBlobStepEnrollmentCheckInTimedOut;
extern NSString * const MSIDOnboardingBlobStepNonHttpsRedirectFailed;
extern NSString * const MSIDOnboardingBlobStepASWebAuthSessionStarted;
extern NSString * const MSIDOnboardingBlobStepASWebAuthenticationCompleted;
extern NSString * const MSIDOnboardingBlobStepASWebAuthCallbackUrlReceived;
extern NSString * const MSIDOnboardingBlobStepASWebAuthUserCancelled;
extern NSString * const MSIDOnboardingBlobStepASWebAuthSessionStartFailed;

// Token-request retry after MDM enrollment completes (free-form passthrough; not C++-aggregated).
extern NSString * const MSIDOnboardingBlobStepTokenRequestRetryStarted;
extern NSString * const MSIDOnboardingBlobStepTokenRequestRetrySucceeded;
extern NSString * const MSIDOnboardingBlobStepTokenRequestRetryFailed;

// Step ID values used in C++ aggregation. Values must match
// MSAIOnboardingBlobConstants (Djinni-generated) byte-for-byte.
extern NSString * const MSIDOnboardingBlobStepStrongAuthSetupStarted;
extern NSString * const MSIDOnboardingBlobStepStrongAuthSetupCompleted;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentRequired;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentStarted;
extern NSString * const MSIDOnboardingBlobStepMdmEnrollmentFinished;
extern NSString * const MSIDOnboardingBlobStepRemediationStarted;
extern NSString * const MSIDOnboardingBlobStepRemediationFinished;
