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

#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDWebviewConstants.h"
#import "MSIDWebResponseOperationConstants.h"

@implementation MSIDWebMDMEnrollmentCompletionResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Validate that the URL matches the expected pattern for enrollment completion response
    if (![self isEnrollmentCompletionResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     [NSString stringWithFormat:
                                      @"Enrollment completion response should have %@ as scheme and %@ as host",
                                      MSID_SCHEME_MSAUTH, MSID_MDM_ENROLLMENT_COMPLETION_HOST],
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        // Extract status from query parameters
        // URL format: msauth://in_app_enrollment_complete?status=success&errorUrl=
        _status = self.parameters[MSID_MDM_ENROLLMENT_COMPLETION_STATUS_KEY];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                         @"Created MDM enrollment completion response - status: %@", _status);
        
        // Extract error URL if present
        _errorUrl = self.parameters[MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY];
    }
    
    return self;
}

- (BOOL)isSuccess
{
    if (!self.status)
    {
        return NO;
    }
    
    NSString *lowercaseStatus = self.status.lowercaseString;
    return [lowercaseStatus isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_SUCCESS]
        || [lowercaseStatus isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_STATUS_VALUE_CHECK_IN_TIMED_OUT];
}

+ (NSString *)operation
{
    return MSID_MDM_ENROLLMENT_COMPLETION_OPERATION;
}

#pragma mark - Private methods

// Checks if the URL matches the expected pattern for enrollment completion response
- (BOOL)isEnrollmentCompletionResponse:(NSURL *)url
{
    if (!url)
    {
        return NO;
    }
    
    return [url.scheme isEqualToString:MSID_SCHEME_MSAUTH]
        && [url.host caseInsensitiveCompare:MSID_MDM_ENROLLMENT_COMPLETION_HOST] == NSOrderedSame;
}

@end



