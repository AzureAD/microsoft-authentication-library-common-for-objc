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
#import "MSIDAADTokenResponse.h"
#import "MSIDMainThreadUtil.h"

@implementation MSIDAADRequestErrorHandler

- (void)handleError:(NSError * )error
       httpResponse:(NSHTTPURLResponse *)httpResponse
               data:(NSData *)data
        httpRequest:(NSObject<MSIDHttpRequestProtocol> *)httpRequest
            context:(id<MSIDRequestContext>)context
    completionBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    if (!httpResponse)
    {
        if (completionBlock) completionBlock(nil, error);
        return;
    }
    
    BOOL shouldRetry = YES;
    shouldRetry &= httpRequest.retryCounter > 0;
    // 5xx Server errors.
    shouldRetry &= httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599;

    if (shouldRetry)
    {
        httpRequest.retryCounter--;
        
        MSID_LOG_VERBOSE(context, @"Retrying network request, retryCounter: %ld", (long)httpRequest.retryCounter);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(httpRequest.retryInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [httpRequest sendWithBlock:completionBlock];
        });
        
        return;
    }

    id responseSerializer = [MSIDJsonResponseSerializer new];
    id responseObject = [responseSerializer responseObjectForResponse:httpResponse data:data context:context error:nil];

    if (responseObject)
    {
        MSIDAADTokenResponse *tokenResponse = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:responseObject error:nil];

        if (![NSString msidIsStringNilOrBlank:tokenResponse.error])
        {
            NSError *oauthError = MSIDCreateError(MSIDOAuthErrorDomain,
                                                  tokenResponse.oauthErrorCode,
                                                  tokenResponse.errorDescription,
                                                  tokenResponse.error,
                                                  tokenResponse.suberror,
                                                  nil,
                                                  context.correlationId,
                                                  nil);

            NSString *message = [NSString stringWithFormat:@"Oauth error raised: %@, sub error: %@, correlation ID: %@", tokenResponse.error, tokenResponse.suberror, tokenResponse.correlationId];
            NSString *messagePII = [NSString stringWithFormat:@"Oauth error raised: %@, sub error: %@, correlation ID: %@, description: %@", tokenResponse.error, tokenResponse.suberror, tokenResponse.correlationId, tokenResponse.errorDescription];

            MSID_LOG_WARN(context, @"%@", message);
            MSID_LOG_WARN_PII(context, @"%@", messagePII);

            if (completionBlock) completionBlock(nil, oauthError);
            return;
        }
    }

    id errorDescription = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];

    NSString *message = [NSString stringWithFormat:@"Http error raised: Http Code: %ld \n", (long)httpResponse.statusCode];
    NSString *messagePII = [NSString stringWithFormat:@"Http error raised: Http Code: %ld \n%@", (long)httpResponse.statusCode, errorDescription];
    
    MSID_LOG_WARN(context, @"%@", message);
    MSID_LOG_VERBOSE_PII(context, @"%@", messagePII);
    
    NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
    [additionalInfo setValue:httpResponse.allHeaderFields
                      forKey:MSIDHTTPHeadersKey];

    [additionalInfo setValue:[NSString stringWithFormat: @"%ld", (long)httpResponse.statusCode]
                      forKey:MSIDHTTPResponseCodeKey];
    
    NSError *httpError = MSIDCreateError(MSIDHttpErrorCodeDomain, MSIDErrorServerUnhandledResponse, errorDescription, nil, nil, nil, context.correlationId, additionalInfo);
    
    if (completionBlock) completionBlock(nil, httpError);
}

@end
