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

#import "MSIDAutomationOperationAPIRequestHandler.h"
#import "MSIDAutomation-Swift.h"
#import "MSIDClientCredentialHelper.h"

@interface MSIDAutomationOperationAPIRequestHandler()

@property (nonatomic) NSString *labAPIPath;
@property (nonatomic) NSDictionary *configurationParams;

@end

@implementation MSIDAutomationOperationAPIRequestHandler

#pragma mark - Init

- (instancetype)initWithAPIPath:(NSString *)apiPath
      operationAPIConfiguration:(NSDictionary *)operationAPIConfiguration
{
    self = [super init];
    
    if (self)
    {
        _labAPIPath = apiPath;
        _configurationParams = operationAPIConfiguration;
    }
    
    return self;
}

#pragma mark - Public

- (void)executeAPIRequest:(MSIDAutomationBaseApiRequest *)apiRequest
          responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
        completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    id cachedResponse = [self.apiCacheHandler cachedResponseForRequest:apiRequest];
    
    if (cachedResponse)
    {
        if (completionHandler)
        {
            completionHandler(cachedResponse, nil);
        }
        
        return;
    }
    
    [self getAccessTokenAndCallLabAPI:apiRequest
                      responseHandler:responseHandler
                    completionHandler:completionHandler];
}

#pragma mark - Get access token

- (void)getAccessTokenAndCallLabAPI:(MSIDAutomationBaseApiRequest *)request
                    responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
                  completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    [MSIDClientCredentialHelper getAccessTokenForAuthority:self.configurationParams[@"operation_api_authority"]
                                                  resource:self.configurationParams[@"operation_api_resource"]
                                                  clientId:self.configurationParams[@"operation_api_client_id"]
                                          clientCredential:self.configurationParams[@"operation_api_client_secret"]
                                         completionHandler:^(NSString *accessToken, NSError *error) {
                                             
                                             if (!accessToken)
                                             {
                                                 completionHandler(nil, error);
                                             }
                                             
                                             [self executeAPIRequestImpl:request
                                                         responseHandler:responseHandler
                                                             accessToken:accessToken
                                                       completionHandler:completionHandler];
                                         }];
}

#pragma mark - Execute request

- (void)executeAPIRequestImpl:(MSIDAutomationBaseApiRequest *)request
              responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
                  accessToken:(NSString *)accessToken
            completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    NSURL *resultURL = [request requestURLWithAPIPath:self.labAPIPath];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:resultURL];
    NSString *bearerHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [urlRequest addValue:bearerHeader forHTTPHeaderField:@"Authorization"];
    [urlRequest setHTTPMethod:request.httpMethod];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest
                                     completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
          
          if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
          {
              NSError *responseError = nil;
              id result = [responseHandler responseFromData:data error:&responseError];
              
              if (request.shouldCacheResponse)
              {
                  [self.apiCacheHandler cacheResponse:result forRequest:request];
              }
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionHandler(result, responseError);
              });
              
              return;
          }
          
          dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
          });
        
      }] resume];
}

@end
