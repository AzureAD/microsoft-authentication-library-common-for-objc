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

@interface MSIDHttpRequest () <NSURLSessionDelegate>

@property (nonatomic) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) NSURLSession *session;

@end

@implementation MSIDHttpRequest

- (instancetype)init
{
    self = [super init];
    
    if (!self) return nil;
    
    // TODO: can we remove queue?
    _operationQueue = [NSOperationQueue new];
    _operationQueue.maxConcurrentOperationCount = 1;
    
    _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration delegate:self delegateQueue:self.operationQueue];
    _responseSerializer = [MSIDJsonResponseSerializer new];
    _requestSerializer = [MSIDUrlRequestSerializer new];
    _defaultTimeoutInterval = 300;
    
    return self;
}

- (NSURLRequest *)urlRequest
{
    if (!_urlRequest)
    {
        __auto_type request = [NSMutableURLRequest new];
        request.timeoutInterval = self.defaultTimeoutInterval;
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        _urlRequest = request;
    }
    
    return _urlRequest;
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock _Nullable )completionBlock;
{
    self.urlRequest = [self.requestSerializer serializeWithRequest:self.urlRequest parameters:self.parameters];
    
    [self.telemetry sendRequestEventWithId:self.context.telemetryRequestId];
    
    [[self.session dataTaskWithRequest:self.urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          MSID_LOG_VERBOSE(self.context, @"Received network response: %@, error %@", _PII_NULLIFY(response), _PII_NULLIFY(error));
          MSID_LOG_VERBOSE_PII(self.context, @"Received network response: %@, error %@", response, error);
          
          if (![response isKindOfClass:NSHTTPURLResponse.class])
          {
              if (completionBlock) completionBlock(response, error, self.context);
              return;
          }
          
          __auto_type httpResponse = (NSHTTPURLResponse *)response;
          
          [self.telemetry responseReceivedEventWithId:self.context.telemetryRequestId
                                        correlationId:self.context.correlationId
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
                  completionBlock(nil, error, self.context);
              }
          }
          else
          {
              if (!completionBlock) return;
              
              id responseObject = [self.responseSerializer responseObjectForResponse:httpResponse data:data error:&error];
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionBlock(error ? nil : responseObject, error, self.context);
              });
          }
      }] resume];
    
    [self.session finishTasksAndInvalidate];
}

- (void)cancel
{
    [self.session invalidateAndCancel];
    [self.session finishTasksAndInvalidate];
}

@end
