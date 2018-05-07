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

#import "MSIDAADRequestConfigurator.h"
#import "MSIDHttpRequest.h"
#import "MSIDAADRequestErrorHandler.h"
#import "MSIDAADResponseSerializer.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDDeviceId.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDVersion.h"
#import "MSIDContants.h"

static NSTimeInterval const s_defaultTimeoutInterval = 300;

@implementation MSIDAADRequestConfigurator

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _timeoutInterval = s_defaultTimeoutInterval;
        _authorityCache = [MSIDAadAuthorityCache sharedInstance];
    }
    return self;
}

- (void)configure:(MSIDHttpRequest *)request
{
    NSParameterAssert(request.urlRequest);
    NSParameterAssert(request.urlRequest.URL);
    
    request.responseSerializer = [MSIDAADResponseSerializer new];
    request.errorHandler = [MSIDAADRequestErrorHandler new];
    
    __auto_type requestUrl = [self.authorityCache networkUrlForAuthority:request.urlRequest.URL context:request.context];
    NSMutableURLRequest *mutableUrlRequest = [request.urlRequest mutableCopy];
    mutableUrlRequest.URL = requestUrl;
    mutableUrlRequest.timeoutInterval = self.timeoutInterval;
    mutableUrlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [mutableUrlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    mutableUrlRequest.URL = [NSURL msidAddParameters:@{MSID_VERSION_KEY : MSIDVersion.sdkVersion} toUrl:requestUrl];
    
    NSMutableDictionary *headers = [mutableUrlRequest.allHTTPHeaderFields mutableCopy];
    [headers addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    if (request.context.correlationId)
    {
        headers[MSID_OAUTH2_CORRELATION_ID_REQUEST] = @"true";
        headers[MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE] = [request.context.correlationId UUIDString];
    }
    
    mutableUrlRequest.allHTTPHeaderFields = headers;
    request.urlRequest = mutableUrlRequest;
}

@end
