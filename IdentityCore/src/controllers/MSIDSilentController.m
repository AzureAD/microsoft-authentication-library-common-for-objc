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

#import "MSIDSilentController.h"
#import "MSIDSilentTokenRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDSilentController()

@property (nonatomic) BOOL forceRefresh;

@end

@implementation MSIDSilentController

#pragma mark - Init

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                               tokenRequestFactory:(nonnull MSIDTokenRequestFactory *)tokenRequestFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull id<MSIDCacheAccessor>)tokenCache
                                             error:(NSError *_Nullable *_Nullable)error
{
    self = [super initWithRequestParameters:parameters
                               oauthFactory:oauthFactory
                        tokenRequestFactory:tokenRequestFactory
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                                      error:error];

    if (self)
    {
        self.forceRefresh = forceRefresh;
    }

    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    [super resolveEndpointsWithUpn:self.requestParameters.accountIdentifier.legacyAccountId
                        completion:^(BOOL resolved, NSError * _Nullable error) {

                            if (!resolved)
                            {
                                [self stopTelemetryEvent:[self telemetryAPIEvent] error:error];
                                completionBlock(nil, error);
                                return;
                            }

                            [self acquireTokenImpl:completionBlock];
    }];
}

- (void)acquireTokenImpl:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    MSIDSilentTokenRequest *silentRequest = [[MSIDSilentTokenRequest alloc] initWithRequestParameters:self.requestParameters
                                                                                         forceRefresh:self.forceRefresh
                                                                                         oauthFactory:self.oauthFactory
                                                                                  tokenRequestFactory:self.tokenRequestFactory
                                                                               tokenResponseValidator:self.tokenResponseValidator
                                                                                           tokenCache:self.tokenCache];

    [silentRequest acquireTokenWithCompletionHandler:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        [self stopTelemetryEvent:[self telemetryAPIEvent] error:error];
        completionBlock(result, error);
    }];
}

@end
