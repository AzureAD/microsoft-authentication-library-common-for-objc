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
#import "MSIDHttpResponseSerializer.h"
#import "MSIDUrlRequestSerializer.h"
#import "MSIDHttpRequestTelemetryHandling.h"
#import "MSIDHttpRequestErrorHandling.h"
#import "MSIDHttpRequestConfiguratorProtocol.h"
#import "MSIDHttpRequestTelemetry.h"
#import "MSIDURLSessionManager.h"
#import "MSIDJsonResponsePreprocessor.h"
#import "MSIDOAuthRequestConfigurator.h"
#import "MSIDHttpRequestServerTelemetryHandling.h"
#import "MSIDBrokerConstants.h"
#import "MSIDExecutionFlowLogger.h"
#import "MSIDExecutionFlowConstants.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDHttpRequestInterceptorProtocol.h"
#import "MSIDHttpRequestHeaderValidator.h"
#import "MSIDHttpRequestHeaderValidating.h"

static NSInteger s_retryCount = 1;
static NSTimeInterval s_retryInterval = 0.5;
static NSTimeInterval s_requestTimeoutInterval = 300;

@implementation MSIDHttpRequest

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _sessionManager = MSIDURLSessionManager.defaultManager;
        __auto_type responseSerializer = [MSIDHttpResponseSerializer new];
        responseSerializer.preprocessor = [MSIDJsonResponsePreprocessor new];
        _responseSerializer = responseSerializer;
        _requestSerializer = [MSIDUrlRequestSerializer new];
#if !EXCLUDE_FROM_MSALCPP
        _telemetry = [MSIDHttpRequestTelemetry new];
#endif
        _retryCounter = s_retryCount;
        _retryInterval = s_retryInterval;
        _requestTimeoutInterval = s_requestTimeoutInterval;
        _cache = [NSURLCache sharedURLCache];
        _shouldCacheResponse = NO;
        _headerValidator = [MSIDHttpRequestHeaderValidator new];
    }

    return self;
}

- (void)sendWithBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    NSParameterAssert(self.urlRequest);
    MSIDExecutionFlowInsertTag([self toString:MSIDPrepareNetworkRequestTag],
                                   nil,
                                   self.context.correlationId);
    __auto_type requestConfigurator = [MSIDOAuthRequestConfigurator new];
    requestConfigurator.timeoutInterval = _requestTimeoutInterval;
    [requestConfigurator configure:self];

    self.urlRequest = [self.requestSerializer serializeWithRequest:self.urlRequest parameters:self.parameters headers:self.headers];

    if (self.requestInterceptor)
    {
        __weak typeof(self) weakSelf = self;
        [self.requestInterceptor addAdditionalHeaderFieldsForUrl:self.urlRequest.URL withBlock:^(NSDictionary<NSString *, NSString *> * _Nullable additionalHeaders)
        {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (additionalHeaders.count)
            {
                NSMutableURLRequest *mutableRequest = [strongSelf.urlRequest mutableCopy];
                
                NSDictionary<NSString *, NSString *> *validHeaders = [strongSelf.headerValidator validHeadersFromHeaders:additionalHeaders];
                for (NSString *field in validHeaders)
                {
                    [mutableRequest setValue:validHeaders[field] forHTTPHeaderField:field];
                }

                strongSelf.urlRequest = mutableRequest;
            }

            [strongSelf sendRequestWithCompletionBlock:completionBlock];
        }];
        return;
    }

    [self sendRequestWithCompletionBlock:completionBlock];
}

- (void)sendRequestWithCompletionBlock:(MSIDHttpRequestDidCompleteBlock)completionBlock
{
    NSCachedURLResponse *response = _shouldCacheResponse ? [self cachedResponse] : nil;
    if (response)
    {
        NSError *error = nil;
        id responseObject = [self.responseSerializer responseObjectForResponse:(NSHTTPURLResponse *)response.response
                                                                          data:response.data
                                                                       context:self.context
                                                                         error:&error];

        if (!responseObject)
        {
            MSIDExecutionFlowInsertTag([self toString:MSIDCacheResponseFailedObjectTag],
                                           nil,
                                           self.context.correlationId);
            [self.cache removeCachedResponseForRequest:self.urlRequest];
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,self.context, @"Removing invalid response from cache %@, response: %@", _PII_NULLIFY(self.urlRequest), _PII_NULLIFY(response.response));
        }
        else
        {
            MSIDExecutionFlowInsertTag([self toString:MSIDCacheResponseSucceededObjectTag],
                                           nil,
                                           self.context.correlationId);
            if (completionBlock) { completionBlock(responseObject, error); }
            return;
        }
    }
#if !EXCLUDE_FROM_MSALCPP
    [self.telemetry sendRequestEventWithId:self.context.telemetryRequestId];
#endif
    [self.serverTelemetry setTelemetryToRequest:self];

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,self.context, @"Sending network request: %@, headers: %@", _PII_NULLIFY(self.urlRequest), _PII_NULLIFY(self.urlRequest.allHTTPHeaderFields));

    [[self.sessionManager.session dataTaskWithRequest:self.urlRequest completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *error)
      {
        MSIDExecutionFlowInsertTag([self toString:MSIDReceiveNetworkResponseTag],
                                       nil,
                                       self.context.correlationId);
          MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,self.context, @"Received network response: %@, error %@", _PII_NULLIFY(urlResponse), _PII_NULLIFY(error));

          if (urlResponse) NSAssert([urlResponse isKindOfClass:NSHTTPURLResponse.class], NULL);

          __auto_type httpResponse = (NSHTTPURLResponse *)urlResponse;
#if !EXCLUDE_FROM_MSALCPP
          [self.telemetry responseReceivedEventWithContext:self.context
                                                urlRequest:self.urlRequest
                                              httpResponse:httpResponse
                                                      data:data
                                                     error:error];
#endif

        void (^completeBlockWrapper)(id, NSError *) = ^(id wrapperResponse, NSError *wrapperError)
        {
            MSIDExecutionFlowInsertTag([self toString:MSIDParseNetworkResponseTag],
                                           wrapperError ? @{MSID_EXECUTION_FLOW_ERROR_CODE:@(wrapperError.code)} : nil,
                                           self.context.correlationId);
            [self.serverTelemetry handleError:wrapperError context:self.context];

            if (completionBlock) { completionBlock(wrapperResponse, wrapperError); }
        };

          if (error)
          {
              NSString *clientData = httpResponse.allHeaderFields[MSID_CLIENT_DATA_HEADER_KEY];
              if (clientData)
              {
                  MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Enriching error userInfo with client data from response header.");
                  NSMutableDictionary *userInfo = error.userInfo ? [error.userInfo mutableCopy] : [NSMutableDictionary new];
                  userInfo[MSID_CLIENT_DATA_RESPONSE] = clientData;
                  error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
              }

              if (self.errorHandler)
              {
                  [self.errorHandler handleError:error
                                    httpResponse:nil
                                            data:nil
                                     httpRequest:self
                              responseSerializer:nil
                              externalSSOContext:nil
                                         context:self.context
                                 completionBlock:completeBlockWrapper];
              }
              else
              {
                  if (completeBlockWrapper) completeBlockWrapper(nil, error);
              }
          }
          else if (httpResponse.statusCode == 200)
          {
              id responseObject = [self.responseSerializer responseObjectForResponse:httpResponse data:data context:self.context error:&error];

              MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,self.context, @"Parsed response: %@, error %@, error domain: %@, error code: %ld", _PII_NULLIFY(responseObject), _PII_NULLIFY(error), error.domain, (long)error.code);

              if (responseObject && self->_shouldCacheResponse)
              {
                  NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:urlResponse data:data];
                  [self setCachedResponse:cachedResponse forRequest:self.urlRequest];
              }

              if (completeBlockWrapper) completeBlockWrapper(responseObject, error);
          }
          else
          {
              
              MSIDExecutionFlowInsertTag([self toString:MSIDOtherHttpNetworkStatusCodeTag],
                                             @{MSID_EXECUTION_FLOW_DIAGNOSTIC_ID:@(httpResponse.statusCode)},
                                             self.context.correlationId);
              if (self.errorHandler)
              {
                  id<MSIDResponseSerialization> responseSerializer = self.errorResponseSerializer ? self.errorResponseSerializer : self.responseSerializer;

                  [self.errorHandler handleError:error
                                    httpResponse:httpResponse
                                            data:data
                                     httpRequest:self
                              responseSerializer:responseSerializer
                              externalSSOContext:self.externalSSOContext
                                         context:self.context
                                 completionBlock:completeBlockWrapper];
              }
              else
              {
                  if (completeBlockWrapper) completeBlockWrapper(nil, error);
              }
          }

      }] resume];
}

+ (NSInteger)retryCountSetting { return s_retryCount; }
+ (void)setRetryCountSetting:(NSInteger)retryCountSetting { s_retryCount = retryCountSetting; }

+ (void)setRetryIntervalSetting:(NSTimeInterval)retryIntervalSetting { s_retryInterval = retryIntervalSetting; }
+ (NSTimeInterval)retryIntervalSetting { return s_retryInterval; }
+ (void)setRequestTimeoutInterval:(NSTimeInterval)requestTimeoutInterval { s_requestTimeoutInterval = requestTimeoutInterval; }
+ (NSTimeInterval)requestTimeoutInterval { return s_requestTimeoutInterval; }

- (NSCachedURLResponse *)cachedResponse
{
    return [self.cache cachedResponseForRequest:self.urlRequest];
}

- (void)setCachedResponse:(__unused NSCachedURLResponse *)cachedResponse forRequest:(__unused NSURLRequest *)request
{
   [self.cache storeCachedResponse:cachedResponse forRequest:request];
}

- (NSString *)toString:(MSIDExecutionFlowNetworkTag)tag
{
    return MSIDExecutionFlowNetworkTagToString(tag);
}

@end
