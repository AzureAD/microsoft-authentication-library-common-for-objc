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
    
    _retryOnErrorCounter = 1;
    
    return self;
}

- (NSURLRequest *)urlRequest
{
    if (!_urlRequest)
    {
        __auto_type request = [NSMutableURLRequest new];
        request.timeoutInterval = 300;
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        _urlRequest = request;
    }
    
    return _urlRequest;
}

- (void)sendWithContext:(id <MSIDRequestContext>)context
      completionBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    self.urlRequest = [self.requestSerializer serializeWithRequest:self.urlRequest parameters:self.parameters];
    
    [[self.session dataTaskWithRequest:self.urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          MSID_LOG_VERBOSE(context, @"Received network response: %@, error %@", _PII_NULLIFY(response), _PII_NULLIFY(error));
          MSID_LOG_VERBOSE_PII(context, @"Received network response: %@, error %@", response, error);
          
          if (error)
          {
              __auto_type httpResponse = (NSHTTPURLResponse *)response;
              BOOL shouldRetry = [httpResponse isKindOfClass:NSHTTPURLResponse.class];
              shouldRetry &= self.retryOnErrorCounter > 0;
              shouldRetry &= httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599;
              
              if (shouldRetry)
              {
                  self.retryOnErrorCounter--;
                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                      [self sendWithContext:context completionBlock:completionBlock];
                  });
              }
              else
              {
                  completionBlock(nil, error, context);
              }
          }
          else
          {
              if (!completionBlock) return;
              
              id responseObject = [self.responseSerializer responseObjectForResponse:response data:data error:&error];
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionBlock(error ? nil : responseObject, error, context);
              });
          }
      }] resume];
}

- (void)cancel
{
    [self.session finishTasksAndInvalidate];
}

@end
