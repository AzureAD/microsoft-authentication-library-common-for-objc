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
@property (nonatomic) NSDictionary *functionAppURL;
@property (nonatomic) NSString *encodedCertificate;
@property (nonatomic) NSString *certificatePassword;

@end

@implementation MSIDAutomationOperationAPIRequestHandler

#pragma mark - Init

- (instancetype)initWithAPIPath:(NSString *)apiPath
             encodedCertificate:(NSString *)encodedCertificate
            certificatePassword:(NSString *)certificatePassword
      operationAPIConfiguration:(NSDictionary *)operationAPIConfiguration
     functionAppAPIConfiguration:(NSDictionary *)functionAppAPIConfiguration
{
    self = [super init];
    
    if (self)
    {
        _labAPIPath = apiPath;
        _configurationParams = operationAPIConfiguration;
        _functionAppURL = functionAppAPIConfiguration;
        _encodedCertificate = encodedCertificate;
        _certificatePassword = certificatePassword;
    }
    
    return self;
}

- (instancetype)initWithAPIPath:(NSString *)apiPath
      operationAPIConfiguration:(NSDictionary *)operationAPIConfiguration
{
    return [self initWithAPIPath:apiPath
              encodedCertificate:nil
             certificatePassword:nil
       operationAPIConfiguration:operationAPIConfiguration
      functionAppAPIConfiguration:nil];
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
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(cachedResponse, nil);
            });
        }

        return;
    }
    
    // Check if we should use function app URLs (with bearer token authentication)
    // Only use Function App URL for operation requests, not for app configuration queries
    if (self.functionAppURL && self.functionAppURL[@"operation_api_path"] && [self shouldUseFunctionAppURLForRequest:apiRequest])
    {
        // Use function app URL API with bearer token
        [self getAccessTokenAndCallFunctionAppAPI:apiRequest
                                  responseHandler:responseHandler
                                completionHandler:completionHandler];
        return;
    }
    
    // Fall back to OAuth-based API (legacy) - used for app configuration and other queries
    [self getAccessTokenAndCallLabAPI:apiRequest
                      responseHandler:responseHandler
                    completionHandler:completionHandler];
}

#pragma mark - Helper

- (BOOL)shouldUseFunctionAppURLForRequest:(MSIDAutomationBaseApiRequest *)request
{
    // Get the class name of the request
    NSString *className = NSStringFromClass([request class]);
    
    // Function App URL should only be used for operation requests:
    // - MSIDAutomationResetAPIRequest (password reset)
    // - MSIDAutomationTemporaryAccountRequest (create temp user)
    // - MSIDAutomationDeleteDeviceAPIRequest (delete device)
    // - MSIDAutomationPolicyToggleAPIRequest (enable/disable policy)
    //
    // NOT for:
    // - MSIDTestAutomationAppConfigurationRequest (app configuration queries)
    // - Any other query/read requests
    
    return [className isEqualToString:@"MSIDAutomationResetAPIRequest"] ||
           [className isEqualToString:@"MSIDAutomationTemporaryAccountRequest"] ||
           [className isEqualToString:@"MSIDAutomationDeleteDeviceAPIRequest"] ||
           [className isEqualToString:@"MSIDAutomationPolicyToggleAPIRequest"];
}

#pragma mark - Get access token

- (void)getAccessTokenAndCallLabAPI:(MSIDAutomationBaseApiRequest *)request
                    responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
                  completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    // Use certificate-based authentication if certificate is provided
    if (self.encodedCertificate && self.certificatePassword)
    {
        NSData *certificateData = [[NSData alloc] initWithBase64EncodedString:self.encodedCertificate options:0];
        
        [MSIDClientCredentialHelper getAccessTokenForAuthority:self.configurationParams[@"operation_api_authority"]
                                                      resource:self.configurationParams[@"operation_api_resource"]
                                                      clientId:self.configurationParams[@"operation_api_client_id"]
                                                   certificate:certificateData
                                           certificatePassword:self.certificatePassword
                                             completionHandler:^(NSString *accessToken, NSError *error) {
                                                 
                                                 if (!accessToken)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionHandler(nil, error);
                                                     });
                                                     return;
                                                 }
                                                 
                                                 [self executeAPIRequestWithAccessToken:request
                                                                           responseHandler:responseHandler
                                                                               accessToken:accessToken
                                                                                   apiPath:self.labAPIPath
                                                                         completionHandler:completionHandler];
                                             }];
    }
    else
    {
        // Fall back to client secret authentication
        [MSIDClientCredentialHelper getAccessTokenForAuthority:self.configurationParams[@"operation_api_authority"]
                                                      resource:self.configurationParams[@"operation_api_resource"]
                                                      clientId:self.configurationParams[@"operation_api_client_id"]
                                              clientCredential:self.configurationParams[@"operation_api_client_secret"]
                                             completionHandler:^(NSString *accessToken, NSError *error) {
                                                 
                                                 if (!accessToken)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionHandler(nil, error);
                                                     });
                                                     return;
                                                 }
                                                 
                                                 [self executeAPIRequestWithAccessToken:request
                                                                           responseHandler:responseHandler
                                                                               accessToken:accessToken
                                                                                   apiPath:self.labAPIPath
                                                                         completionHandler:completionHandler];
                                             }];
    }
}

- (void)getAccessTokenAndCallFunctionAppAPI:(MSIDAutomationBaseApiRequest *)request
                            responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
                          completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    // Use certificate-based authentication to get bearer token
    if (self.encodedCertificate && self.certificatePassword)
    {
        NSData *certificateData = [[NSData alloc] initWithBase64EncodedString:self.encodedCertificate options:0];
        
        [MSIDClientCredentialHelper getAccessTokenForAuthority:self.configurationParams[@"operation_api_authority"]
                                                      resource:self.configurationParams[@"operation_api_resource"]
                                                      clientId:self.configurationParams[@"operation_api_client_id"]
                                                   certificate:certificateData
                                           certificatePassword:self.certificatePassword
                                             completionHandler:^(NSString *accessToken, NSError *error) {
                                                 
                                                 if (!accessToken)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionHandler(nil, error);
                                                     });
                                                     return;
                                                 }
                                                 
                                                 NSString *functionAppAPIPath = self.functionAppURL[@"operation_api_path"];
                                                 [self executeAPIRequestWithAccessToken:request
                                                                           responseHandler:responseHandler
                                                                               accessToken:accessToken
                                                                                   apiPath:functionAppAPIPath
                                                                         completionHandler:completionHandler];
                                             }];
    }
    else
    {
        // Fall back to client secret authentication
        [MSIDClientCredentialHelper getAccessTokenForAuthority:self.configurationParams[@"operation_api_authority"]
                                                      resource:self.configurationParams[@"operation_api_resource"]
                                                      clientId:self.configurationParams[@"operation_api_client_id"]
                                              clientCredential:self.configurationParams[@"operation_api_client_secret"]
                                             completionHandler:^(NSString *accessToken, NSError *error) {
                                                 
                                                 if (!accessToken)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionHandler(nil, error);
                                                     });
                                                     return;
                                                 }
                                                 
                                                 NSString *functionAppAPIPath = self.functionAppURL[@"operation_api_path"];
                                                 [self executeAPIRequestWithAccessToken:request
                                                                           responseHandler:responseHandler
                                                                               accessToken:accessToken
                                                                                   apiPath:functionAppAPIPath
                                                                         completionHandler:completionHandler];
                                             }];
    }
}

#pragma mark - Execute API request with bearer token

- (void)executeAPIRequestWithAccessToken:(MSIDAutomationBaseApiRequest *)request
                         responseHandler:(id<MSIDAutomationOperationAPIResponseHandler>)responseHandler
                             accessToken:(NSString *)accessToken
                                 apiPath:(NSString *)apiPath
                       completionHandler:(void (^)(id result, NSError *error))completionHandler
{
    NSURL *resultURL = [request requestURLWithAPIPath:apiPath];
    
    if (!resultURL)
    {
        NSError *error = [NSError errorWithDomain:@"MSIDAutomationOperationAPIRequestHandler"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to build API URL"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, error);
        });
        return;
    }
    
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
          
          NSError *apiError = error;
          if (!apiError && httpResponse)
          {
              NSString *errorMessage = [NSString stringWithFormat:@"API request failed with status code: %ld", (long)httpResponse.statusCode];
              if (data)
              {
                  NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                  errorMessage = [errorMessage stringByAppendingFormat:@"\nResponse: %@", responseBody];
              }
              apiError = [NSError errorWithDomain:@"MSIDAutomationOperationAPIRequestHandler"
                                             code:httpResponse.statusCode
                                         userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
          }
          
          dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, apiError);
          });
        
      }] resume];
}

@end
