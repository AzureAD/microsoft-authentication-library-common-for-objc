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

/**
 * Purpose for launching ASWebAuthenticationSession.
 * Determines session configuration and required parameters.
 */
typedef NS_ENUM(NSInteger, MSIDASWebAuthenticationPurpose)
{
    // Unknown or unspecified purpose
    MSIDASWebAuthenticationPurposeUnknown = 0,
    
    // MDM enrollment flow
    MSIDASWebAuthenticationPurposeMDMEnrollment = 1
};

#pragma mark - Constants

#pragma mark - URL Schemes

extern NSString * const MSID_SCHEME_MSAUTH;
extern NSString * const MSID_SCHEME_BROWSER;

#pragma mark - URL Hosts

extern NSString * const MSID_MDM_ENROLL_HOST;
extern NSString * const MSID_COMPLIANCE_HOST;
extern NSString * const MSID_MDM_ENROLLMENT_COMPLETION_HOST;

#pragma mark - Enrollment Query Parameters

extern NSString * const MSID_INTUNE_URL_KEY;
extern NSString * const MSID_IN_APP_KEY;

#pragma mark - Enrollment Completion Query Parameters

extern NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_KEY;
extern NSString * const MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY;
extern NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_SUCCESS;
extern NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_CHECK_IN_TIMED_OUT;

#pragma mark - ASWebAuthentication Handoff Headers

// ASWebAuthentication handoff header keys
extern NSString * const MSID_ASWEBAUTH_HANDOFF_URL_KEY;                    // x-ms-aswebauth-handoff-url
extern NSString * const MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY;          // x-ms-aswebauth-handoff-use-ephemeral-session
extern NSString * const MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY;        // x-ms-aswebauth-handoff-include-headers
extern NSString * const MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY;         // x-ms-aswebauth-handoff-attach-headers
extern NSString * const MSID_ASWEBAUTH_HANDOFF_INTUNE_AUTH_TOKEN_KEY;      // x-ms-aswebauth-handoff-intune-auth-token
extern NSString * const MSID_ASWEBAUTH_HANDOFF_SESSION_CORRELATION_ID_KEY; // x-ms-aswebauth-handoff-session-correlation-id
extern NSString * const MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX;              // x-ms-aswebauth-handoff-

// ASWebAuthentication handoff header values
extern NSString * const MSID_ASWEBAUTH_HANDOFF_VALUE_TRUE;                 // "true"
extern NSString * const MSID_ASWEBAUTH_HANDOFF_VALUE_FALSE;                // "false"

#pragma mark - Utility Functions

extern NSString *MSIDASWebAuthCallbackSchemeForPurpose(MSIDASWebAuthenticationPurpose purpose);

#pragma mark - MSIDASWebAuthenticationConstants Class

@interface MSIDASWebAuthenticationConstants : NSObject

@property (class, nonatomic, readonly) NSSet<NSString *> *asWebAuthAllowedDomains;

@end
