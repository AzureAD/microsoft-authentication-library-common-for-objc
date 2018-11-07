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

#import "MSIDTokenResponseValidator.h"
#import "MSIDRequestParameters.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResult.h"
#import "MSIDTokenResponse.h"

@implementation MSIDTokenResponseValidator

- (MSIDTokenResult *)validateTokenResponse:(id)response
                              oauthFactory:(MSIDOauth2Factory *)factory
                                tokenCache:(id<MSIDCacheAccessor>)tokenCache
                         requestParameters:(MSIDRequestParameters *)parameters
                                     error:(NSError **)error
{
    if (response && ![response isKindOfClass:[NSDictionary class]])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Token response is not of the expected type: NSDictionary.", nil, nil, nil, parameters.correlationId, nil);
        }

        MSID_LOG_ERROR(parameters, @"Unexpected response from STS, not of NSDictionary type");

        return nil;
    }

    NSDictionary *jsonDictionary = (NSDictionary *)response;
    MSIDTokenResponse *tokenResponse = [factory tokenResponseFromJSON:jsonDictionary
                                                              context:parameters
                                                                error:error];
    if (!tokenResponse)
    {
        MSID_LOG_ERROR(parameters, @"Failed to create token response");
        return nil;
    }

    NSError *verificationError = nil;

    if (![factory verifyResponse:tokenResponse context:parameters error:&verificationError])
    {
        if (error)
        {
            *error = verificationError;
        }

        MSID_LOG_WARN(parameters, @"Unsuccessful token response, error %ld, %@", (long)verificationError.code, verificationError.domain);
        MSID_LOG_WARN_PII(parameters, @"Unsuccessful token response, error %@", verificationError);

        return nil;
    }

    NSError *savingError = nil;
    BOOL isSaved = [tokenCache saveTokensWithConfiguration:parameters.msidConfiguration
                                                  response:tokenResponse
                                                   context:parameters
                                                     error:&savingError];

    if (!isSaved)
    {
        MSID_LOG_ERROR(parameters, @"Failed to save tokens in cache. Error %ld, %@", (long)savingError.code, savingError.domain);
        MSID_LOG_ERROR_PII(parameters, @"Failed to save tokens in cache. Error %@", savingError);
    }

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse configuration:parameters.msidConfiguration];

    MSIDAuthority *authority = parameters.cloudAuthority ?: parameters.authority;

    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:parameters.msidConfiguration];

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                                   idToken:tokenResponse.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:parameters.correlationId
                                                             tokenResponse:tokenResponse];

    return result;
}

@end
