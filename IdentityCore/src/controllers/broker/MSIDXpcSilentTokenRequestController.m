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

#import "MSIDXpcSilentTokenRequestController.h"
#import "MSIDSilentController+Internal.h"
#if TARGET_OS_OSX
#import "MSIDXpcSingleSignOnProvider.h"
#endif

@implementation MSIDXpcSilentTokenRequestController

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
#if TARGET_OS_OSX
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning silent broker xpc flow.");
    MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult *result, NSError *error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Silent broker xpc flow finished. Result %@, error: %ld error domain: %@, shouldFallBack: %@", _PII_NULLIFY(result), (long)error.code, error.domain, @(self.fallbackController != nil));
        completionBlock(result, error);
    };
    
    __auto_type request = [self.tokenRequestProvider silentXpcTokenRequestWithParameters:self.requestParameters
                                                                            forceRefresh:self.forceRefresh];
    [self acquireTokenWithRequest:request completionBlock:completionBlockWrapper];
#else
    NSAssert(NO, @"Xpc service is only valid on MacOS");
#endif
}

+ (BOOL)canPerformRequest
{
#if TARGET_OS_OSX
    if (@available(macOS 13, *)) {
        return YES;
    } else {
        return NO;
    }
#else
    return NO;
#endif
}

@end

