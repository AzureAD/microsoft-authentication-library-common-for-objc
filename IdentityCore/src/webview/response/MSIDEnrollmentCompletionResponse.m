//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDEnrollmentCompletionResponse.h"
#import "MSIDError.h"
#import "MSIDWebResponseOperationConstants.h"

@implementation MSIDEnrollmentCompletionResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
        shouldRetryInBroker:(BOOL)shouldRetryInBroker
                      error:(NSError *__autoreleasing*)error
{
    // Validate that this is a profile completion URL
    if (![self isProfileCompletionURL:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                    MSIDErrorServerInvalidResponse,
                                    @"Enrollment completion response should have msauth scheme and profileInstalled/profileComplete host",
                                    nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _profileCompletedURL = url;
        _shouldRetryInBroker = shouldRetryInBroker;
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context,
                             @"Created enrollment completion response for URL: %@, shouldRetryInBroker: %d",
                             MSID_PII_LOG_MASKABLE(url), shouldRetryInBroker);
    }
    
    return self;
}

- (BOOL)isProfileCompletionURL:(NSURL *)url
{
    NSString *scheme = [url.scheme lowercaseString];
    NSString *host = [url.host lowercaseString];
    
    // msauth://profileInstalled or msauth://profileComplete
    if ([scheme isEqualToString:@"msauth"] &&
        ([host isEqualToString:@"profileinstalled"] || [host isEqualToString:@"profilecomplete"]))
    {
        return YES;
    }
    
    return NO;
}

+ (NSString *)operation
{
    return @"enrollment_completion";
}

@end
