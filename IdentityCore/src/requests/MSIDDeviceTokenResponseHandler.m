//
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

#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDRequestParameters.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResponseValidator.h"

@interface MSIDDeviceTokenResponseHandler ()

@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) MSIDOauth2Factory *oauthFactory;
@property (nonatomic) id<MSIDCacheAccessor> tokenCache;

@end

@implementation MSIDDeviceTokenResponseHandler

- (instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
{
    self = [super init];
    if (self)
    {
        _requestParameters = requestParameters;
        _oauthFactory = oauthFactory;
        _tokenCache = tokenCache;
    }
    return self;
}


- (void)handleTokenResponse:(nonnull NSDictionary *)tokenJsonResponse
                    context:(nonnull id<MSIDRequestContext>)context
                      error:(NSError *)error
            completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    if (error)
    {
        completionBlock(nil, error);
        return;
    }

    MSIDTokenResponse *serializedTokenResponse = [self.oauthFactory tokenResponseFromJSON:tokenJsonResponse
                                                                                   context:context
                                                                                     error:&error];
    
    MSIDTokenResponseValidator *tokenResponseValidator = [MSIDTokenResponseValidator new];
    MSIDTokenResult *result = [tokenResponseValidator validateAndSaveTokenResponse:serializedTokenResponse
                                                                      oauthFactory:self.oauthFactory
                                                                        tokenCache:self.tokenCache
                                                              accountMetadataCache:nil
                                                                 requestParameters:self.requestParameters
                                                                  saveSSOStateOnly:NO
                                                                             error:&error];
    completionBlock(result, error);
}

@end
