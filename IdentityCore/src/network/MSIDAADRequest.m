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

#import "MSIDAADRequest.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDDeviceId.h"
#import "MSIDAADRequestErrorHandler.h"
#import "MSIDAADResponseSerializer.h"

@implementation MSIDAADRequest

- (instancetype)init
{
    self = [super init];
    
    if (!self) return nil;
    
    self.responseSerializer = [MSIDAADResponseSerializer new];
    self.errorHandler = [MSIDAADRequestErrorHandler new];
    
    return self;
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock;
{
    __auto_type requestUrl = [[MSIDAadAuthorityCache sharedInstance] networkUrlForAuthority:self.urlRequest.URL context:self.context];
    NSMutableURLRequest *mutableUrlRequest = [self.urlRequest mutableCopy];
    mutableUrlRequest.URL = requestUrl;
    
    // TODO:
//    __auto_type requestUrl = [ADHelpers addClientVersionToURL:_requestURL];
    
    // TODO:
//    [mutableUrlRequest.allHTTPHeaderFields mutableCopy]
//    requestUrl
//    [[ADClientMetrics getInstance] addClientMetrics:_requestHeaders endpoint:[_requestURL absoluteString]];
    
    NSMutableDictionary *headers = [mutableUrlRequest.allHTTPHeaderFields mutableCopy];
    [headers addEntriesFromDictionary:[MSIDDeviceId deviceId]];

    if (self.context.correlationId)
    {
        headers[MSID_OAUTH2_CORRELATION_ID_REQUEST] = @"true";
        headers[MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE] = [self.context.correlationId UUIDString];
    }
    
    mutableUrlRequest.allHTTPHeaderFields = headers;
    self.urlRequest = mutableUrlRequest;
    
//    [[ADClientMetrics getInstance] endClientMetricsRecord:[[_request URL] absoluteString]
//                                                startTime:[_request startTime]
//                                            correlationId:_request.correlationId
//                                             errorDetails:[adError errorDetails]];
    
//    [super sendWithBlock:completionBlock];
    
    [super sendWithBlock:^(id response, NSError *error, id<MSIDRequestContext> context)
     {
         if (error)
         {
             completionBlock(response, error, context);
         }
         else
         {
             completionBlock(response, error, context);
         }
     }];
}

@end
