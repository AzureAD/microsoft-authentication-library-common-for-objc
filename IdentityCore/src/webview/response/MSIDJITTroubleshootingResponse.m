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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#if !EXCLUDE_FROM_MSALCPP

#import "MSIDJITTroubleshootingResponse.h"
#import "MSIDBrokerConstants.h"

@implementation MSIDJITTroubleshootingResponse

- (instancetype)initWithURL:(NSURL *)url
                    context:(id <MSIDRequestContext>)context
                      error:(NSError **)error
{
    // Check for JIT retry response
    if (![self isJITRetryResponse:url] && ![self isJITTroubleshootingResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                    MSIDErrorServerInvalidResponse,
                    @"MSAuth JIT retry response should have msauth as a scheme and compliance_status or jit_troubleshooting as a host",
                    nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }

    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _status = self.parameters[@"status"];
    }

    return self;
}

- (BOOL)isJITRetryResponse:(NSURL *)url
{
    if (!url) return NO;
    if ([@"msauth" caseInsensitiveCompare:url.scheme] == NSOrderedSame && [@"compliance_status" caseInsensitiveCompare:url.host] == NSOrderedSame)
    {
        _isRetryResponse = YES;
        return YES;
    }

    return NO;
}

- (BOOL)isJITTroubleshootingResponse:(NSURL *)url
{
    if (!url) return NO;
    return ([@"msauth" caseInsensitiveCompare:url.scheme] == NSOrderedSame && [JIT_TROUBLESHOOTING_HOST caseInsensitiveCompare:url.host] == NSOrderedSame);
}

- (NSError *)getErrorFromResponseWithContext:(id <MSIDRequestContext>)context
{
    NSError *returnError = nil;

    if (self.isRetryResponse)
    {
        switch ([self.status intValue])
        {
            case 4:
                returnError = MSIDCreateError(MSIDErrorDomain, MSIDErrorJITRetryRequired, @"JIT: Retrying JIT", nil, nil, nil, context.correlationId, nil, NO);
                break;

            default:
                returnError = MSIDCreateError(MSIDErrorDomain, MSIDErrorJITUnknownStatusWebCP, [NSString stringWithFormat:@"JIT: Unexpected status received from webCP troubleshooting flow: %@.", self.status], nil, nil, nil, context.correlationId, nil, YES);
                break;
        }
    }
    else
    {
        returnError = MSIDCreateError(MSIDErrorDomain, MSIDErrorJITTroubleshootingRequired, @"JIT: Troubleshooting JIT", nil, nil, nil, context.correlationId, nil, NO);
    }

    return returnError;
}
@end

#endif
