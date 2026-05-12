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

#import "MSIDASWebAuthHandoffConstants.h"

#pragma mark - Header Names (Per Specification Section 5.2)

// Required header
NSString *const MSIDASWebAuthHandoffURLHeader = @"x-ms-aswebauth-handoff-url";

// Optional control headers
NSString *const MSIDASWebAuthHandoffUseEphemeralSessionHeader = @"x-ms-aswebauth-handoff-use-ephemeral-session";
NSString *const MSIDASWebAuthHandoffIncludeHeadersHeader = @"x-ms-aswebauth-handoff-include-headers";
NSString *const MSIDASWebAuthHandoffAttachHeadersHeader = @"x-ms-aswebauth-handoff-attach-headers";
NSString *const MSIDASWebAuthHandoffSessionCorrelationIdHeader = @"x-ms-aswebauth-handoff-session-correlation-id";

#pragma mark - Callback URL Components

NSString *const MSIDASWebAuthCallbackScheme = @"msauth";
NSString *const MSIDASWebAuthCallbackHostMDMEnrollmentComplete = @"in_app_enrollment_complete";

#pragma mark - Helper Functions

NSString * _Nullable MSIDASWebAuthGetCallbackSchemeForPurpose(MSIDASWebAuthSessionPurpose purpose)
{
    switch (purpose)
    {
        case MSIDASWebAuthSessionPurposeMDMEnrollment:
            return MSIDASWebAuthCallbackScheme;
            
        case MSIDASWebAuthSessionPurposeUnknown:
        default:
            return MSIDASWebAuthCallbackScheme; // Default scheme
    }
}

NSString * _Nullable MSIDASWebAuthGetCallbackHostForPurpose(MSIDASWebAuthSessionPurpose purpose)
{
    switch (purpose)
    {
        case MSIDASWebAuthSessionPurposeMDMEnrollment:
            return MSIDASWebAuthCallbackHostMDMEnrollmentComplete;
            
        case MSIDASWebAuthSessionPurposeUnknown:
        default:
            return nil; // Unknown purpose has no specific callback host
    }
}

BOOL MSIDASWebAuthValidateCallbackForPurpose(NSURL * _Nullable callbackURL, MSIDASWebAuthSessionPurpose purpose)
{
    if (!callbackURL)
    {
        return NO;
    }
    
    // Get expected scheme and host for this purpose
    NSString *expectedScheme = MSIDASWebAuthGetCallbackSchemeForPurpose(purpose);
    NSString *expectedHost = MSIDASWebAuthGetCallbackHostForPurpose(purpose);
    
    if (!expectedScheme)
    {
        return NO;
    }
    
    // Validate scheme (case-insensitive)
    if ([callbackURL.scheme caseInsensitiveCompare:expectedScheme] != NSOrderedSame)
    {
        return NO;
    }
    
    // If purpose has a specific host requirement, validate it
    if (expectedHost)
    {
        if (!callbackURL.host || [callbackURL.host caseInsensitiveCompare:expectedHost] != NSOrderedSame)
        {
            return NO;
        }
    }
    
    return YES;
}
