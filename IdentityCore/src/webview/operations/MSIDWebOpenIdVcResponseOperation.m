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


#import "MSIDWebOpenIdVcResponseOperation.h"
#import "MSIDWebOpenIdVcResponse.h"
#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#endif

@interface MSIDWebOpenIdVcResponseOperation()

@property (nonatomic) NSURL *openIdVcURL;

@end

@implementation MSIDWebOpenIdVcResponseOperation

- (nullable instancetype)initWithResponse:(nonnull MSIDWebviewResponse *)response
                                    error:(NSError * _Nullable __autoreleasing *)error
{
    self = [super initWithResponse:response
                             error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDWebOpenIdVcResponse.class] || [NSString msidIsStringNilOrBlank:[(MSIDWebOpenIdVcResponse *)response openIdVcURL].absoluteString])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"response is not valid");
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Wrong type of response or response does not contain a valid openid-vc URL", nil, nil, nil, nil, nil, YES);
            }
            return nil;
        }

        MSIDWebOpenIdVcResponse *openIdVcResponse = (MSIDWebOpenIdVcResponse *)response;
        _openIdVcURL = openIdVcResponse.openIdVcURL;
    }

    return self;
}

- (BOOL)doActionWithCorrelationId:(NSUUID *)correlationId
                            error:(NSError * _Nullable __autoreleasing *)error
{
#if TARGET_OS_IPHONE
    if ([MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAttemptToOpenURLFromExtension, @"unable to open openid-vc URL from extension", nil, nil, nil, correlationId, nil, YES);
        }
        return YES;
    }

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Opening openid-vc URL - %@", [self.openIdVcURL msidPIINullifiedURL]);
    [MSIDAppExtensionUtil sharedApplicationOpenURL:self.openIdVcURL];

    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programmatically.", nil, nil, nil, correlationId, nil, YES);
    }
    return YES;
#else
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"openid-vc:// scheme is not supported on this platform", nil, nil, nil, correlationId, nil, YES);
    }
    return YES;
#endif
}

@end
