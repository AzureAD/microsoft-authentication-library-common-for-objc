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

#import "MSIDWebviewConstants.h"

#pragma mark - URL Schemes

NSString * const MSID_SCHEME_MSAUTH  = @"msauth";
NSString * const MSID_SCHEME_BROWSER  = @"browser";

#pragma mark - URL Hosts

NSString * const MSID_MDM_ENROLL_HOST = @"enroll";
NSString * const MSID_COMPLIANCE_HOST = @"compliance";
NSString * const MSID_MDM_ENROLLMENT_COMPLETION_HOST = @"in_app_enrollment_complete";

#pragma mark - Enrollment Query Parameters

NSString * const MSID_INTUNE_URL_KEY = @"intuneRedirectUrl";
NSString * const MSID_IN_APP_KEY = @"in-app";

#pragma mark - Enrollment Completion Query Parameters

NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_KEY = @"status";
NSString * const MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY = @"errorUrl";
NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_SUCCESS = @"success";
NSString * const MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_CHECK_IN_TIMED_OUT = @"check_in_timed_out";

#pragma mark - ASWebAuthentication Handoff Headers

// ASWebAuthentication handoff header keys
NSString *const MSID_ASWEBAUTH_HANDOFF_URL_KEY                    = @"x-ms-aswebauth-handoff-url";
NSString *const MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY          = @"x-ms-aswebauth-handoff-use-ephemeral-session";
NSString *const MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY        = @"x-ms-aswebauth-handoff-include-headers";
NSString *const MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY         = @"x-ms-aswebauth-handoff-attach-headers";
NSString *const MSID_ASWEBAUTH_HANDOFF_INTUNE_AUTH_TOKEN_KEY      = @"x-ms-aswebauth-handoff-intune-auth-token";
NSString *const MSID_ASWEBAUTH_HANDOFF_SESSION_CORRELATION_ID_KEY = @"x-ms-aswebauth-handoff-session-correlation-id";
NSString *const MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX              = @"x-ms-aswebauth-handoff-";

// ASWebAuthentication handoff header values
NSString *const MSID_ASWEBAUTH_HANDOFF_VALUE_TRUE                 = @"true";
NSString *const MSID_ASWEBAUTH_HANDOFF_VALUE_FALSE                = @"false";

#pragma mark - Utility Functions

NSString *MSIDASWebAuthCallbackSchemeForPurpose(MSIDASWebAuthenticationPurpose purpose)
{
    // Currently all purposes use the same callback scheme
    // Future: Different purposes could use different schemes if needed
    switch (purpose)
    {
        case MSIDASWebAuthenticationPurposeMDMEnrollment:
            return MSID_SCHEME_MSAUTH;
            
        case MSIDASWebAuthenticationPurposeUnknown:
        default:
            return MSID_SCHEME_MSAUTH;
    }
}

#pragma mark - ASWebAuthentication Allowed Domains

@implementation MSIDASWebAuthenticationConstants

+ (NSSet<NSString *> *)asWebAuthAllowedDomains
{
    static NSSet<NSString *> *allowedDomains = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedDomains = [[NSSet alloc] initWithArray:@[@"portal.manage.microsoft.com",
                                                        @"portal.manage-beta.microsoft.com",
                                                        @"portal.manage.microsoft.us",
                                                        @"portal.manage.microsoft.cn",
                                                        @"portal.manage.microsoftonline.de"
                                                      ]];
    });
    
    return allowedDomains;
}

@end

