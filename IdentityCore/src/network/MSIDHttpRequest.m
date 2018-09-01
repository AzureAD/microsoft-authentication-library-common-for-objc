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

#import "MSIDHttpRequest.h"
#import "MSIDJsonResponseSerializer.h"
#import "MSIDUrlRequestSerializer.h"
#import "MSIDHttpRequestTelemetryHandling.h"
#import "MSIDHttpRequestErrorHandling.h"
#import "MSIDHttpRequestConfiguratorProtocol.h"
#import "MSIDHttpRequestTelemetry.h"
#import "MSIDURLSessionManager.h"

static NSInteger const s_defaultRetryCounter = 1;
static NSTimeInterval const s_defaultRetryInterval = 0.5;

@implementation MSIDHttpRequest

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _sessionManager = MSIDURLSessionManager.defaultManager;
        _responseSerializer = [MSIDJsonResponseSerializer new];
        _requestSerializer = [MSIDUrlRequestSerializer new];
        _telemetry = [MSIDHttpRequestTelemetry new];
        _retryCounter = s_defaultRetryCounter;
        _retryInterval = s_defaultRetryInterval;
    }
    
    return self;
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    NSParameterAssert(self.urlRequest);
    
    self.urlRequest = [self.requestSerializer serializeWithRequest:self.urlRequest parameters:self.parameters];
    
    [self.telemetry sendRequestEventWithId:self.context.telemetryRequestId];
    
    MSID_LOG_VERBOSE(self.context, @"Sending network request: %@, headers: %@", _PII_NULLIFY(self.urlRequest), _PII_NULLIFY(self.urlRequest.allHTTPHeaderFields));
    
    [[self.sessionManager.session dataTaskWithRequest:self.urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
      {
          MSID_LOG_VERBOSE(self.context, @"Received network response: %@, error %@", _PII_NULLIFY(response), _PII_NULLIFY(error));
          
          if (response) NSAssert([response isKindOfClass:NSHTTPURLResponse.class], NULL);
          
          __auto_type httpResponse = (NSHTTPURLResponse *)response;
          
          [self.telemetry responseReceivedEventWithContext:self.context
                                                urlRequest:self.urlRequest
                                              httpResponse:httpResponse
                                                      data:data
                                                     error:error];
          
          if (error)
          {
              if (completionBlock) { completionBlock(nil, error); }
          }
          else if (httpResponse.statusCode == 200)
          {
              id responseObject = [self.responseSerializer responseObjectForResponse:httpResponse data:data context:self.context error:&error];
              
              MSID_LOG_VERBOSE(self.context, @"Parsed response: %@, error %@, error domain: %@, error code: %ld", _PII_NULLIFY(responseObject), _PII_NULLIFY(error), error.domain, (long)error.code);
              
              if (completionBlock) { completionBlock(responseObject, error); }
          }
          else
          {
              if (self.errorHandler)
              {
                  [self.errorHandler handleError:error
                                    httpResponse:httpResponse
                                            data:data
                                     httpRequest:self
                                         context:self.context
                                 completionBlock:completionBlock];
              }
              else
              {
                  if (completionBlock) { completionBlock(nil, error); }
              }
          }

      }] resume];
}

@end
