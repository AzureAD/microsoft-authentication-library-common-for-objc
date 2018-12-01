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
#import "MSIDTokenResponseValidator.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRefreshTokenGrantRequest.h"
#import "MSIDRefreshToken.h"
#import "MSIDAuthority.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResult.h"
#import "NSError+MSIDExtensions.h"

@interface MSIDSilentTokenRequest()

@property (nonatomic, readwrite) MSIDRequestParameters *requestParameters;
@property (nonatomic) BOOL forceRefresh;
@property (nonatomic, readwrite) MSIDOauth2Factory *oauthFactory;
@property (nonatomic, readwrite) MSIDTokenResponseValidator *tokenResponseValidator;
@property (nonatomic, readwrite) MSIDAccessToken *extendedLifetimeAccessToken;

@end

@implementation MSIDSilentTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
{
    self = [super init];

    if (self)
    {
        _requestParameters = parameters;
        _forceRefresh = forceRefresh;
        _oauthFactory = oauthFactory;
        _tokenResponseValidator = tokenResponseValidator;
    }

    return self;
}

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!self.requestParameters.accountIdentifier)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Account parameter cannot be nil");

        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMissingAccountParameter, @"Account parameter cannot be nil", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, error);
        return;
    }

    NSString *upn = self.requestParameters.accountIdentifier.legacyAccountId;

    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }

         [self executeRequestImpl:completionBlock];
     }];
}

- (void)executeRequestImpl:(MSIDRequestCompletionBlock)completionBlock
{
    if (!self.forceRefresh && ![self.requestParameters.claims count])
    {
        NSError *accessTokenError = nil;

        MSIDAccessToken *accessToken = [self accessTokenWithError:&accessTokenError];

        if (accessTokenError)
        {
            completionBlock(nil, accessTokenError);
            return;
        }

        if (accessToken && ![accessToken isExpiredWithExpiryBuffer:self.requestParameters.tokenExpirationBuffer])
        {
            NSError *rtError = nil;
            id<MSIDRefreshableToken> refreshableToken = [self appRefreshTokenWithError:&rtError];

            if (!refreshableToken)
            {
                MSID_LOG_WARN(self.requestParameters, @"Didn't find app refresh token with error: %ld, %@", (long)rtError.code, rtError.domain);
                MSID_LOG_WARN_PII(self.requestParameters, @"Didn't find app refresh token with error: %@", rtError);
            }

            NSError *resultError = nil;
            MSIDTokenResult *tokenResult = [self resultWithAccessToken:accessToken
                                                          refreshToken:refreshableToken
                                                                 error:&resultError];

            if (resultError)
            {
                completionBlock(nil, resultError);
                return;
            }

            completionBlock(tokenResult, nil);
            return;
        }

        if (accessToken && accessToken.isExtendedLifetimeValid)
        {
            self.extendedLifetimeAccessToken = accessToken;
        }
    }

    NSError *frtCacheError = nil;

    MSIDRefreshToken *familyRefreshToken = [self familyRefreshTokenWithError:&frtCacheError];

    if (frtCacheError)
    {
        MSID_LOG_ERROR(self.requestParameters, @"Failed to read family refresh token with error %ld, %@", (long)frtCacheError.code, frtCacheError.domain);
        MSID_LOG_ERROR_PII(self.requestParameters, @"Failed to read family refresh token with error %@", frtCacheError);
        completionBlock(nil, frtCacheError);
        return;
    }

    if (familyRefreshToken)
    {
        [self tryFRT:familyRefreshToken completionBlock:completionBlock];
    }
    else
    {
        NSError *appRTCacheError = nil;
        id<MSIDRefreshableToken> appRefreshToken = [self appRefreshTokenWithError:&appRTCacheError];

        if (appRTCacheError)
        {
            MSID_LOG_ERROR(self.requestParameters, @"Failed to read app spefici refresh token with error %ld, %@", (long)appRTCacheError.code, appRTCacheError.domain);
            MSID_LOG_ERROR_PII(self.requestParameters, @"Failed to read app specific refresh token with error %@", appRTCacheError);
            completionBlock(nil, appRTCacheError);
            return;
        }

        [self tryAppRefreshToken:appRefreshToken completionBlock:completionBlock];
    }
}

- (void)tryFRT:(MSIDRefreshToken *)familyRefreshToken completionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_VERBOSE(self.requestParameters, @"Trying to acquire access token using FRT for clientId %@, authority %@", self.requestParameters.authority, self.requestParameters.clientId);
    MSID_LOG_VERBOSE(self.requestParameters, @"Trying to acquire access token using FRT for clientId %@, authority %@, account %@", self.requestParameters.authority, self.requestParameters.clientId, self.requestParameters.accountIdentifier.homeAccountId);

    [self refreshAccessToken:familyRefreshToken
             completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
                 if (error)
                 {
                     if ([self isErrorRecoverableByUserInteraction:error])
                     {
                         //Udpate app metadata  by resetting familyId if server returns client_mismatch
                         NSError *msidError = nil;

                         [self updateFamilyIdCacheWithServerError:error
                                                       cacheError:&msidError];

                         if (msidError)
                         {
                             MSID_LOG_ERROR(self.requestParameters, @"Failed to update familyID cache status with error %ld, %@", (long)error.code, error.domain);
                             MSID_LOG_ERROR_PII(self.requestParameters, @"Failed to update familyID cache status with error %@", error);
                         }

                         id<MSIDRefreshableToken> appRefreshToken = [self appRefreshTokenWithError:&msidError];

                         if (msidError)
                         {
                             MSID_LOG_ERROR(self.requestParameters, @"Failed to retrieve multi resource refresh token with error %ld, %@", (long)error.code, error.domain);
                             MSID_LOG_ERROR_PII(self.requestParameters, @"Failed to retrieve multi resource refresh token with error %@", error);
                             completionBlock(nil, msidError);
                             return;
                         }

                         if (appRefreshToken && ![[familyRefreshToken refreshToken] isEqualToString:[appRefreshToken refreshToken]])
                         {
                             [self tryAppRefreshToken:appRefreshToken completionBlock:completionBlock];
                             return;
                         }

                         NSError *interactionError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"User interaction is required", error.msidOauthError, error.msidSubError, error, self.requestParameters.correlationId, nil);
                         completionBlock(nil, interactionError);
                     }
                     else
                     {
                         completionBlock(nil, error);
                     }
                 }
                 else
                 {
                     completionBlock(result, nil);
                 }
             }];
}

- (void)tryAppRefreshToken:(id<MSIDRefreshableToken>)multiResourceRefreshToken completionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    if (!multiResourceRefreshToken)
    {
        NSError *interactionError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"User interaction is required", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, interactionError);
        return;
    }

    [self refreshAccessToken:multiResourceRefreshToken
             completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
                 if (error)
                 {
                     //Check if server returns invalid_grant or invalid_request
                     if ([self isErrorRecoverableByUserInteraction:error])
                     {
                         NSError *interactionError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"User interaction is required", error.msidOauthError, error.msidSubError, error, self.requestParameters.correlationId, nil);

                         completionBlock(nil, interactionError);
                         return;
                     }
                     else
                     {
                         completionBlock(nil, error);
                     }
                 }
                 else
                 {
                     completionBlock(result, nil);
                 }
             }];
}

#pragma mark - Helpers

- (BOOL)isErrorRecoverableByUserInteraction:(NSError *)msidError
{
    MSIDErrorCode oauthError = MSIDErrorCodeForOAuthError(msidError.msidOauthError, MSIDErrorServerInvalidGrant);

    if (oauthError == MSIDErrorServerInvalidScope
        || oauthError == MSIDErrorServerInvalidClient)
    {
        return NO;
    }

    /*
        The default behavior of SDK should be to always show UI
        as long as server returns us valid response with an existing Oauth2 error.
        If it's an unrecoverable error, server will show error message to user in the web UI.
        If client wants to not show UI in particular cases, they can examine error contents and do custom handling based on Oauth2 error code and/or sub error.
     */
    return ![NSString msidIsStringNilOrBlank:msidError.msidOauthError];
}

- (void)refreshAccessToken:(id<MSIDRefreshableToken>)refreshToken completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    if (!refreshToken)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"No token matching arguments found in the cache", nil, nil, nil, self.requestParameters.correlationId, nil);
        completionBlock(nil, error);
        return;
    }

    MSID_LOG_INFO(self.requestParameters, @"Refreshing access token");

    [self.requestParameters.authority loadOpenIdMetadataWithContext:self.requestParameters
                                                    completionBlock:^(MSIDOpenIdProviderMetadata * _Nullable metadata, NSError * _Nullable error) {

                                                        if (error)
                                                        {
                                                            completionBlock(nil, error);
                                                            return;
                                                        }

                                                        [self acquireTokenWithRefreshTokenImpl:refreshToken
                                                                               completionBlock:completionBlock];

                                                    }];
}

- (void)acquireTokenWithRefreshTokenImpl:(id<MSIDRefreshableToken>)refreshToken
                         completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    MSIDRefreshTokenGrantRequest *tokenRequest = [self.oauthFactory refreshTokenRequestWithRequestParameters:self.requestParameters
                                                                                                refreshToken:refreshToken.refreshToken];

    [tokenRequest sendWithBlock:^(id response, NSError *error) {

        if (error)
        {
            BOOL serverUnavailable = error.userInfo[MSIDServerUnavailableStatusKey] != nil;

            if (serverUnavailable && self.requestParameters.extendedLifetimeEnabled && self.extendedLifetimeAccessToken)
            {
                NSError *cacheError = nil;
                MSIDTokenResult *tokenResult = [self resultWithAccessToken:self.extendedLifetimeAccessToken
                                                              refreshToken:refreshToken
                                                                     error:&cacheError];
                tokenResult.extendedLifeTimeToken = YES;

                completionBlock(tokenResult, cacheError);
                return;
            }

            completionBlock(nil, error);
            return;
        }

        NSError *validationError = nil;

        MSIDTokenResult *tokenResult = [self.tokenResponseValidator validateAndSaveTokenResponse:response
                                                                                    oauthFactory:self.oauthFactory
                                                                                      tokenCache:self.tokenCache
                                                                               requestParameters:self.requestParameters
                                                                                           error:&validationError];

        if (!tokenResult)
        {
            completionBlock(nil, validationError);
            return;
        }

        completionBlock(tokenResult, nil);
    }];
}

#pragma mark - Abstract

- (nullable MSIDAccessToken *)accessTokenWithError:(NSError **)error
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return nil;
}

- (nullable MSIDTokenResult *)resultWithAccessToken:(MSIDAccessToken *)accessToken
                                       refreshToken:(id<MSIDRefreshableToken>)refreshToken
                                              error:(NSError * _Nullable * _Nullable)error
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return nil;
}

- (nullable MSIDRefreshToken *)familyRefreshTokenWithError:(NSError * _Nullable * _Nullable)error
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return nil;
}

- (nullable id<MSIDRefreshableToken>)appRefreshTokenWithError:(NSError * _Nullable * _Nullable)error
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return nil;
}

- (BOOL)updateFamilyIdCacheWithServerError:(NSError *)serverError
                                cacheError:(NSError **)cacheError
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return NO;
}

- (id<MSIDCacheAccessor>)tokenCache
{
    NSAssert(NO, @"Abstract method. Should be implemented in a subclass");
    return nil;
}

@end
