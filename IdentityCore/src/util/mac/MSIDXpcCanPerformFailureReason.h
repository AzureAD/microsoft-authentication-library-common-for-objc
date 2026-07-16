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

// Distinguishes why +[MSIDXpcSingleSignOnProvider canPerformRequest:] returned NO,
// so telemetry/logging can disambiguate which of the client-side static gates rejected the request.
//
// Kept in a lightweight standalone header (no SSOExtension/broker dependencies) so that consumers
// which only need the failure-reason type (e.g. the Xpc token request controllers and their
// downstream callers) do not have to import the full MSIDXpcSingleSignOnProvider interface.
typedef NS_ENUM(NSInteger, MSIDXpcCanPerformFailureReason)
{
    // canPerformRequest succeeded, no failure occurred.
    MSIDXpcCanPerformFailureReasonNone = 0,
    // Neither the MacBrokerApp nor the CompanyPortal Xpc component is installed on the device.
    MSIDXpcCanPerformFailureReasonNoProviderInstalled,
    // Failed to construct the SSOExtension getDeviceInfo request object.
    MSIDXpcCanPerformFailureReasonDeviceInfoRequestCreationFailed,
    // SSOExtension getDeviceInfo handshake completed with a hard error.
    MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeError,
    // SSOExtension getDeviceInfo handshake did not complete before the 1 second timeout expired.
    MSIDXpcCanPerformFailureReasonDeviceInfoHandshakeTimeout,
    // No installed Xpc provider matches the cached/available Xpc configuration.
    MSIDXpcCanPerformFailureReasonValidateCacheProviderFailed,
    // The Xpc broker flow is gated behind macOS 13+ (or otherwise unsupported on this OS version) and was rejected before reaching MSIDXpcSingleSignOnProvider.
    MSIDXpcCanPerformFailureReasonUnsupportedOSVersion,
};

// Returns a human readable, non-PII name for the given failure reason, suitable for logging.
extern NSString *MSIDXpcCanPerformFailureReasonToString(MSIDXpcCanPerformFailureReason reason);

NS_ASSUME_NONNULL_END
