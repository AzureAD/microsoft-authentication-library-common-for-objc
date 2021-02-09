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
#import "MSIDThrottlingTypeProcessor+Internal.h"
#import "NSDate+MSIDExtensions.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDConstants.h"
#import "NSError+MSIDThrottlingExtension.h"

@implementation MSIDThrottlingTypeProcessor

+ (MSIDThrottlingType)processErrorResponseToGetThrottleType:(NSError *)errorResponse
                                                      error:(NSError *_Nullable *_Nullable)error
{
    
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    throttleType = [self ifErrorResponseIs429ThrottleType:errorResponse
                                                    error:error];
    
    if (throttleType == MSIDThrottlingType429) return throttleType;
    throttleType = [self ifErrorResponseIsInteractiveRequireThrottleType:errorResponse];
    return throttleType;
}

/**
 429 throttle conditions:
 - HTTP Response code is 429 or in 5xx range
 - OR Retry-After in response header
 */
+ (MSIDThrottlingType)ifErrorResponseIs429ThrottleType:(NSError * _Nullable )errorResponse
                                                 error:(NSError *_Nullable *_Nullable)error
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    /**
     In SSO-Ext flow, it can be both MSAL or MSID Error. If it's MSALErrorDomain, we need to extract information we need (error code and user info)
     */
    BOOL isMSIDError = [errorResponse.domain hasPrefix:@"MSID"];
    NSString *httpResponseCode = errorResponse.userInfo[isMSIDError ? MSIDHTTPResponseCodeKey : @"MSALHTTPResponseCodeKey"];
    NSInteger responseCode = [httpResponseCode intValue];
    if (responseCode == 429) throttleType = MSIDThrottlingType429;
    if (responseCode >= 500 && responseCode <= 599) throttleType = MSIDThrottlingType429;
    NSDate *retryHeaderDate = [errorResponse msidGetRetryDateFromError];
    if (retryHeaderDate)
    {
        throttleType = MSIDThrottlingType429;
    }
    return throttleType;
}

/**
 * If not 429, we check if is appliable for UIRequired:
 * error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied
 */
+ (MSIDThrottlingType)ifErrorResponseIsInteractiveRequireThrottleType:(NSError *)errorResponse
{
    MSIDThrottlingType throttleType = MSIDThrottlingTypeNone;
    // If not 429, we check if is appliable for UIRequired:
    // error response can be: invalid_request, invalid_client, invalid_scope, invalid_grant, unauthorized_client, interaction_required, access_denied
    
    NSSet *uirequiredErrors = [NSSet setWithArray:@[@"invalid_request", @"invalid_client", @"invalid_scope", @"invalid_grant", @"unauthorized_client", @"interaction_required", @"access_denied"]];
    BOOL isMSIDError = [errorResponse.domain hasPrefix:@"MSID"];
    
    if (isMSIDError)
    {
        NSString *errorString = errorResponse.msidOauthError;
        NSUInteger errorCode = errorResponse.code;
        if ([uirequiredErrors containsObject:errorString] || (errorCode == MSIDErrorInteractionRequired))
        {
            throttleType = MSIDThrottlingTypeInteractiveRequired;
        }
    }
    else
    {
        // -50002 = MSALErrorInteractionRequired
        if (errorResponse.code == -50002)
        {
            throttleType = MSIDThrottlingTypeInteractiveRequired;
        }
    }
    
    return throttleType;
}

@end
