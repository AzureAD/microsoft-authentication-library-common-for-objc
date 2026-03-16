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

@implementation MSIDWebMDMEnrollmentCompletionResponse

static NSString *const SCHEME_MSAUTH = @"msauth";
static NSString *const ENROLLMENT_COMPLETE = @"in_app_enrollment_complete";

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Validate URL matches enrollment completion pattern
    if (![self isEnrollmentCompletionResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     [NSString stringWithFormat:
                                      @"Enrollment completion response should have %@ as scheme and %@ as host",
                                        SCHEME_MSAUTH, ENROLLMENT_COMPLETE],
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        // Extract status from query parameters
        // URL format: msauth://in_app_enrollment_complete?status=success&info=...
        _status = self.parameters[@"status"];
        
        //TODO: verify implementation
        _additionalInfo = self.parameters[@"info"] ?: self.parameters[@"additionalInfo"];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                         @"Created MDM enrollment completion response - status: %@", _status);
        
        if (_additionalInfo)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context,
                                 @"Enrollment completion info: %@", MSID_PII_LOG_MASKABLE(_additionalInfo));
        }
        else
        {
            NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
                    for (NSString *key in self.parameters.allKeys)
                    {
                        if (![key isEqualToString:@"status"])
                        {
                            additionalInfo[key] = self.parameters[key];
                        }
                    }
                    _additionalInfo = [additionalInfo copy];
        }
    }
    
    return self;
}

/**
 * Detects enrollment completion URLs.
 * Supports both embedded and system webview formats.
 */
- (BOOL)isEnrollmentCompletionResponse:(NSURL *)url
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // Pattern 1: Embedded webview format
    // msauth://in_app_enrollment_complete
    if ([scheme isEqualToString:SCHEME_MSAUTH] && [host caseInsensitiveCompare:ENROLLMENT_COMPLETE] == NSOrderedSame)
    {
        return YES;
    }
    
    // TODO: verify with testing
    // Pattern 2: System webview format
    // myscheme://auth/msauth/in_app_enrollment_complete
    NSArray *pathComponents = url.pathComponents;
    
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    NSUInteger pathComponentCount = pathComponents.count;
    
    if ([pathComponents[pathComponentCount - 1] caseInsensitiveCompare:ENROLLMENT_COMPLETE] == NSOrderedSame
            && [pathComponents[pathComponentCount - 2] isEqualToString:SCHEME_MSAUTH])
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isSuccess
{
    return [self.status.lowercaseString isEqualToString:@"success"];
}

+ (NSString *)operation
{
    return @"in_app_enrollment_complete";
}

@end


