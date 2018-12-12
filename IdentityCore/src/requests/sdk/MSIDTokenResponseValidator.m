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
#import "MSIDBrokerResponse.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"

@implementation MSIDTokenResponseValidator

- (MSIDTokenResult *)validateTokenResponse:(MSIDTokenResponse *)tokenResponse
                              oauthFactory:(MSIDOauth2Factory *)factory
                             configuration:(MSIDConfiguration *)configuration
                            requestAccount:(MSIDAccountIdentifier *)accountIdentifier
                             correlationID:(NSUUID *)correlationID
                                     error:(NSError **)error
{
    if (!tokenResponse)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Token response is nil", correlationID);
        return nil;
    }

    NSError *verificationError = nil;

    if (![factory verifyResponse:tokenResponse context:nil error:&verificationError])
    {
        if (error)
        {
            *error = verificationError;
        }

        MSID_LOG_WARN(nil, @"Unsuccessful token response, error %ld, %@", (long)verificationError.code, verificationError.domain);
        MSID_LOG_WARN_CORR_PII(correlationID, @"Unsuccessful token response, error %@", verificationError);

        return nil;
    }

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:tokenResponse configuration:configuration];
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:tokenResponse configuration:configuration];

    MSIDAccount *account = [factory accountFromResponse:tokenResponse configuration:configuration];

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:refreshToken
                                                                   idToken:tokenResponse.idToken
                                                                   account:account
                                                                 authority:accessToken.authority
                                                             correlationId:correlationID
                                                             tokenResponse:tokenResponse];

    return result;
}

- (BOOL)validateTokenResult:(MSIDTokenResult *)tokenResult
              configuration:(MSIDConfiguration *)configuration
             requestAccount:(MSIDAccountIdentifier *)accountIdentifier
              correlationID:(NSUUID *)correlationID
                      error:(NSError **)error
{
    // Post saving validation
    return YES;
}

- (MSIDTokenResult *)validateAndSaveBrokerResponse:(MSIDBrokerResponse *)brokerResponse
                                      oauthFactory:(MSIDOauth2Factory *)factory
                                        tokenCache:(id<MSIDCacheAccessor>)tokenCache
                                     correlationID:(NSUUID *)correlationID
                                             error:(NSError **)error
{
    if (!brokerResponse)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Broker response is nil", correlationID);
        return nil;
    }

    __auto_type authority = [MSIDAuthorityFactory authorityFromUrl:[NSURL URLWithString:brokerResponse.authority]
                                                           context:nil
                                                             error:error];

    if (!authority) return nil;

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:nil
                                                                           clientId:brokerResponse.clientId
                                                                             target:brokerResponse.target];

    MSIDTokenResult *tokenResult = [self validateTokenResponse:brokerResponse.tokenResponse
                                                  oauthFactory:factory
                                                 configuration:configuration
                                                requestAccount:nil
                                                 correlationID:[[NSUUID alloc] initWithUUIDString:brokerResponse.correlationId]
                                                         error:error];

    if (!tokenResult)
    {
        return nil;
    }

    NSError *savingError = nil;
    BOOL isSaved = [tokenCache saveTokensWithBrokerResponse:brokerResponse
                                           saveSSOStateOnly:brokerResponse.accessTokenInvalidForResponse
                                                    factory:factory
                                                    context:nil
                                                      error:error];

    if (!isSaved)
    {
        MSID_LOG_ERROR_CORR(correlationID, @"Failed to save tokens in cache. Error %ld, %@", (long)savingError.code, savingError.domain);
        MSID_LOG_ERROR_CORR_PII(correlationID, @"Failed to save tokens in cache. Error %@", savingError);
    }

    BOOL resultValid = [self validateTokenResult:tokenResult
                                   configuration:configuration
                                  requestAccount:nil
                                   correlationID:correlationID
                                           error:error];

    if (!resultValid)
    {
        return nil;
    }

    tokenResult.brokerAppVersion = brokerResponse.brokerAppVer;
    return tokenResult;
}


- (MSIDTokenResult *)validateAndSaveTokenResponse:(id)response
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

    MSIDTokenResult *tokenResult = [self validateTokenResponse:tokenResponse
                                                  oauthFactory:factory
                                                 configuration:parameters.msidConfiguration
                                                requestAccount:parameters.accountIdentifier
                                                 correlationID:parameters.correlationId
                                                         error:error];

    if (!tokenResult)
    {
        return nil;
    }

    NSError *savingError = nil;
    BOOL isSaved = [tokenCache saveTokensWithConfiguration:parameters.msidConfiguration
                                                  response:tokenResponse
                                                   factory:factory
                                                   context:parameters
                                                     error:&savingError];

    if (!isSaved)
    {
        MSID_LOG_ERROR(parameters, @"Failed to save tokens in cache. Error %ld, %@", (long)savingError.code, savingError.domain);
        MSID_LOG_ERROR_PII(parameters, @"Failed to save tokens in cache. Error %@", savingError);
    }

    BOOL resultValid = [self validateTokenResult:tokenResult
                                   configuration:parameters.msidConfiguration
                                  requestAccount:parameters.accountIdentifier
                                   correlationID:parameters.correlationId
                                           error:error];

    if (!resultValid)
    {
        return nil;
    }

    return tokenResult;
}


@end
