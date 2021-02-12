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


#import "MSIDThrottlingService.h"
#import "MSIDThrottlingServiceMock.h"

@implementation MSIDThrottlingServiceMock

- (instancetype)initWithAccessGroup:(NSString *)accessGroup
                            context:(id<MSIDRequestContext>)context
{
    self = [super initWithAccessGroup:accessGroup context:context];
    if (self)
    {
        _shouldThrottleRequestInvokedCount = 0;
        _updateThrottlingServiceInvokedCount = 0;
    }
    return self;
}

- (void)shouldThrottleRequest:(id<MSIDThumbprintCalculatable>)request
                  resultBlock:(MSIDThrottleResultBlock)resultBlock
{
    self.shouldThrottleRequestInvokedCount++;
    [super shouldThrottleRequest:request
                     resultBlock:resultBlock];
    
}

- (void)updateThrottlingService:(NSError *)error
                   tokenRequest:(id<MSIDThumbprintCalculatable>)tokenRequest
{
    self.updateThrottlingServiceInvokedCount++;
    [super updateThrottlingService:error
                      tokenRequest:tokenRequest];
}

+ (BOOL)updateLastRefreshTimeAccessGroup:(NSString *)accessGroup
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    return [super updateLastRefreshTimeAccessGroup:accessGroup
                                           context:context
                                         error:error];
}

@end

