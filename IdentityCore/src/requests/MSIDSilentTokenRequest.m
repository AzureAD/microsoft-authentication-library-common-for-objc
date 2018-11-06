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

#import "MSIDSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccessToken.h"

@interface MSIDSilentTokenRequest()

@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) BOOL forceRefresh;
@property (nonatomic) MSIDOauth2Factory *oauthFactory;
@property (nonatomic) MSIDTokenRequestFactory *tokenRequestFactory;
@property (nonatomic) MSIDTokenResponseValidator *tokenResponseValidator;
@property (nonatomic) id<MSIDTokenCacheProviding> tokenCache;

@end

@implementation MSIDSilentTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                               tokenRequestFactory:(nonnull MSIDTokenRequestFactory *)tokenRequestFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull id<MSIDTokenCacheProviding>)tokenCache
{
    self = [super init];

    if (self)
    {
        self.requestParameters = parameters;
        self.forceRefresh = forceRefresh;
        self.oauthFactory = oauthFactory;
        self.tokenRequestFactory = tokenRequestFactory;
        self.tokenResponseValidator = tokenResponseValidator;
        self.tokenCache = tokenCache;
    }

    return self;
}

- (void)acquireTokenWithCompletionHandler:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    // TODO!
    // CHECK_ERROR_COMPLETION(_parameters.account, _parameters, MSALErrorAccountRequired, @"user parameter cannot be nil");

    if (!self.forceRefresh && ![self.requestParameters.claims count])
    {
        NSError *accessTokenError = nil;
        MSIDTokenResult *accessTokenResult = [self.tokenCache accessTokenResultWithParameters:self.requestParameters
                                                                                        error:&accessTokenError];

        if (accessTokenError)
        {
            completionBlock(nil, accessTokenError);
            return;
        }

        if (accessTokenResult)
        {
            completionBlock(accessTokenResult, nil);
            return;
        }
    }


    /*
        NSError *msidError = nil;
        NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [self.tokenCache getAppMetadataEntries:_parameters.msidConfiguration
                                                                                                 context:_parameters
                                                                                                   error:&msidError];

        if (msidError)
        {
            completionBlock(nil, msidError);
            return;
        }

        //On first network try, app metadata will be nil but on every subsequent attempt, it should reflect if clientId is part of family
        NSString *familyId = appMetadataEntries.firstObject ? appMetadataEntries.firstObject.familyId : @"1";
        if (![NSString msidIsStringNilOrBlank:familyId])
        {
            [self tryFRT:familyId appMetadata:appMetadataEntries.firstObject completionBlock:completionBlock];
        }
        else
        {
            [self tryMRRT:completionBlock];
        }*/
    }
}

@end
