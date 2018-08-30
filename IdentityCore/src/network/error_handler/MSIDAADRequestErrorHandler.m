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


#import "MSIDAADRequestErrorHandler.h"
#import "MSIDJsonResponseSerializer.h"

@implementation MSIDAADRequestErrorHandler

- (instancetype)init
{
    self = [super init];
    
    return self;
}

- (void)handleError:(NSError * )error
       httpResponse:(NSHTTPURLResponse *)httpResponse
               data:(NSData *)data
        httpRequest:(id<MSIDHttpRequestProtocol>)httpRequest
            context:(id<MSIDRequestContext>)context
    completionBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    if (!httpResponse)
    {
        if (completionBlock) { completionBlock(nil, error); }
        return;
    }
    
    if (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599 && httpRequest.retryCounter > 0)
    {
        httpRequest.retryCounter--;
        
        MSID_LOG_VERBOSE(context, @"Retrying network request, retryCounter: %ld", (long)httpRequest.retryCounter);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(httpRequest.retryInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [httpRequest sendWithBlock:completionBlock];
        });
        
        return;
    }
    
    // Http error
    NSString *errorData = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];
    NSString* message = [NSString stringWithFormat:@"Http error raised: Http Code: %ld \n", (long)httpResponse.statusCode];
    NSString* messagePII = [NSString stringWithFormat:@"Http error raised: Http Code: %ld \n%@", (long)httpResponse.statusCode, errorData];
    
    MSID_LOG_WARN(context, @"%@", message);
    MSID_LOG_VERBOSE_PII(context, @"%@", messagePII);
    
    NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
    [additionalInfo setValue:httpResponse.allHeaderFields forKey:MSIDHTTPHeadersKey];
    [additionalInfo setValue:[NSString stringWithFormat: @"%ld", (long)httpResponse.statusCode]          forKey:MSIDHTTPResponseCodeKey];
    NSError *httpError = MSIDCreateError(MSIDHttpErrorCodeDomain, MSIDErrorServerUnhandledResponse, errorData, nil, nil, nil, context.correlationId, additionalInfo);
    
    if (completionBlock) { completionBlock(nil, httpError); }
}

@end
