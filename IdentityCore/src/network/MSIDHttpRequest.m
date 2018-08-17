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
#import "MSIDHttpRequestTelemetryProtocol.h"
#import "MSIDHttpRequestErrorHandlerProtocol.h"
#import "MSIDHttpRequestConfiguratorProtocol.h"
#import "MSIDHttpRequestTelemetry.h"

@interface MSIDHttpRequest () <NSURLSessionDelegate>

@property (nonatomic) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic) NSURLSession *session;

@end

@implementation MSIDHttpRequest

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration delegate:self delegateQueue:nil];
        _responseSerializer = [MSIDJsonResponseSerializer new];
        _requestSerializer = [MSIDUrlRequestSerializer new];
        _telemetry = [MSIDHttpRequestTelemetry new];
    }
    
    return self;
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    NSParameterAssert(self.urlRequest);
    
    self.urlRequest = [self.requestSerializer serializeWithRequest:self.urlRequest parameters:self.parameters];
    
    if (self.requestConfigurator) { [self.requestConfigurator configure:self]; }
    
    [self.telemetry sendRequestEventWithId:self.context.telemetryRequestId];
    
    MSID_LOG_VERBOSE(self.context, @"Sending network request: %@, headers: %@", _PII_NULLIFY(self.urlRequest), _PII_NULLIFY(self.urlRequest.allHTTPHeaderFields));
    
    [[self.session dataTaskWithRequest:self.urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
      {
          MSID_LOG_VERBOSE(self.context, @"Received network response: %@, error %@", _PII_NULLIFY(response), _PII_NULLIFY(error));
          
          if (response) { NSAssert([response isKindOfClass:NSHTTPURLResponse.class], NULL); }
          
          __auto_type httpResponse = (NSHTTPURLResponse *)response;
          
          [self.telemetry responseReceivedEventWithContext:self.context
                                                urlRequest:self.urlRequest
                                              httpResponse:httpResponse
                                                      data:data
                                                     error:error];
          if (error)
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
          else
          {
              id responseObject = [self.responseSerializer responseObjectForResponse:httpResponse data:data error:&error];
              
              MSID_LOG_VERBOSE(self.context, @"Parsed response: %@, error %@", _PII_NULLIFY(responseObject), _PII_NULLIFY(error));
              
              if (completionBlock) { completionBlock(error ? nil : responseObject, error); }
          }
      }] resume];
}

- (void)finishAndInvalidate
{
    [self.session finishTasksAndInvalidate];
}

- (void)cancel
{
    [self.session invalidateAndCancel];
}

@end
