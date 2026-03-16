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

#import "MSIDWebviewResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Response object representing MDM enrollment completion callback.
 * 
 * This response is triggered when user returns from MDM profile installation
 * via ASWebAuthenticationSession callback URL.
 * 
 * Expected URL formats:
 * - msauth://in_app_enrollment_complete?status=success
 * - msauth://enrollmentComplete?status=success&info=...
 * - myscheme://auth/msauth/in_app_enrollment_complete?status=success (system webview)
 * 
 * This signals the broker to:
 * 1. Query SSO Extension for updated device registration info
 * 2. Retry PRT acquisition with new device state
 */
@interface MSIDWebMDMEnrollmentCompletionResponse : MSIDWebviewResponse

/**
 * Status of the MDM enrollment operation.
 * Possible values: "success", "cancelled", "failed"
 * Extracted from "status" query parameter.
 */
@property (atomic, readonly, nullable) NSString *status;

/**
 * Additional information about the enrollment result.
 * May contain error details if enrollment failed or was cancelled.
 * Extracted from "info" or "additionalInfo" query parameter.
 */
//TODO: CHECk if required
@property (atomic, readonly, nullable) NSString *additionalInfo;

/**
 * Convenience property to check if enrollment completed successfully.
 * Returns YES if status is "success" (case-insensitive), NO otherwise.
 */
//TODO: CHECk if required
@property (atomic, readonly) BOOL isSuccess;

@end

NS_ASSUME_NONNULL_END


