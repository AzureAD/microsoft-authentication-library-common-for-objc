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

#import "MSIDOnboardingBlobFieldKeys.h"

// IPC envelope key (kept in sync with broker IPC contract).
NSString * const MSIDOnboardingBlobIPCKey = @"onboardingBlob";

// Field keys for populated blob
NSString * const MSIDOnboardingBlobFieldBlockingErrors = @"blocking_errors";
NSString * const MSIDOnboardingBlobFieldLastBlockingError = @"last_blocking_error";
NSString * const MSIDOnboardingBlobFieldLastLoadedDomain = @"last_loaded_domain";
NSString * const MSIDOnboardingBlobFieldLastCompletedStep = @"last_completed_step";
NSString * const MSIDOnboardingBlobFieldUxFlowUsed = @"ux_flow_used";

// Step ID values not used in C++ aggregation
NSString * const MSIDOnboardingBlobStepAuthenticationStarted = @"AuthenticationStarted";
NSString * const MSIDOnboardingBlobStepCredentialEntryCompleted = @"CredentialEntryCompleted";
NSString * const MSIDOnboardingBlobStepBrokerInstallPrompted = @"BrokerInstallPrompted";
NSString * const MSIDOnboardingBlobStepBrokerAppInstall = @"BrokerAppInstall";
NSString * const MSIDOnboardingBlobStepBrokerInstallPromptedForMDM = @"BrokerInstallPromptedForMDM";
NSString * const MSIDOnboardingBlobStepDeviceRegistrationStarted = @"DeviceRegistrationStarted";
NSString * const MSIDOnboardingBlobStepDeviceRegistrationCompleted = @"DeviceRegistrationCompleted";
NSString * const MSIDOnboardingBlobStepFlowCompleted = @"FlowCompleted";

// Step ID values used in C++ aggregation (must match MSAIOnboardingBlobConstants)
NSString * const MSIDOnboardingBlobStepStrongAuthSetupStarted = @"StrongAuthSetupStarted";
NSString * const MSIDOnboardingBlobStepStrongAuthSetupCompleted = @"StrongAuthSetupCompleted";
NSString * const MSIDOnboardingBlobStepMdmEnrollmentRequired = @"MDMEnrollmentRequired";
NSString * const MSIDOnboardingBlobStepMdmEnrollmentStarted = @"MDMEnrollmentStarted";
NSString * const MSIDOnboardingBlobStepMdmEnrollmentFinished = @"MDMEnrollmentFinished";
NSString * const MSIDOnboardingBlobStepRemediationStarted = @"RemediationStarted";
NSString * const MSIDOnboardingBlobStepRemediationFinished = @"RemediationFinished";
