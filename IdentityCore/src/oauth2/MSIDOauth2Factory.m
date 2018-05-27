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

#import "MSIDOauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDRequestContext.h"
#import "MSIDAccessToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDIdToken.h"
#import "MSIDAccount.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDLegacyAccessToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDPkce.h"
#import "MSIDDeviceId.h"

@implementation MSIDOauth2Factory

#pragma mark - Response

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    return [[MSIDTokenResponse alloc] initWithJSONDictionary:json error:error];
}

- (BOOL)verifyResponse:(MSIDTokenResponse *)response
               context:(id<MSIDRequestContext>)context
                 error:(NSError **)error
{
    if (!response)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal, @"processTokenResponse called without a response dictionary", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if (response.error)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     response.oauthErrorCode,
                                     response.errorDescription,
                                     response.error,
                                     nil,
                                     nil,
                                     context.correlationId,
                                     nil);
        }
        return NO;
    }
    
    if ([NSString msidIsStringNilOrBlank:response.accessToken])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Authentication response received without expected accessToken", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Tokens

- (MSIDBaseToken *)baseTokenFromResponse:(MSIDTokenResponse *)response
                           configuration:(MSIDConfiguration *)configuration
{
    MSIDBaseToken *baseToken = [[MSIDBaseToken alloc] init];
    BOOL result = [self fillBaseToken:baseToken fromResponse:response configuration:configuration];

    if (!result) return nil;

    return baseToken;
}

- (MSIDAccessToken *)accessTokenFromResponse:(MSIDTokenResponse *)response
                               configuration:(MSIDConfiguration *)configuration
{
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] init];
    BOOL result = [self fillAccessToken:accessToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return accessToken;
}

- (MSIDLegacyAccessToken *)legacyAccessTokenFromResponse:(MSIDTokenResponse *)response
                                           configuration:(MSIDConfiguration *)configuration
{
    MSIDLegacyAccessToken *accessToken = [[MSIDLegacyAccessToken alloc] init];
    BOOL result = [self fillLegacyAccessToken:accessToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return accessToken;
}

- (MSIDLegacyRefreshToken *)legacyRefreshTokenFromResponse:(MSIDTokenResponse *)response
                                             configuration:(MSIDConfiguration *)configuration
{
    MSIDLegacyRefreshToken *refreshToken = [[MSIDLegacyRefreshToken alloc] init];
    BOOL result = [self fillLegacyRefreshToken:refreshToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return refreshToken;
}

- (MSIDRefreshToken *)refreshTokenFromResponse:(MSIDTokenResponse *)response
                                 configuration:(MSIDConfiguration *)configuration
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    BOOL result = [self fillRefreshToken:refreshToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return refreshToken;
}

- (MSIDIdToken *)idTokenFromResponse:(MSIDTokenResponse *)response
                       configuration:(MSIDConfiguration *)configuration
{
    MSIDIdToken *idToken = [[MSIDIdToken alloc] init];
    BOOL result = [self fillIDToken:idToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return idToken;
}

- (MSIDLegacySingleResourceToken *)legacyTokenFromResponse:(MSIDTokenResponse *)response
                                             configuration:(MSIDConfiguration *)configuration
{
    MSIDLegacySingleResourceToken *legacyToken = [[MSIDLegacySingleResourceToken alloc] init];
    BOOL result = [self fillLegacyToken:legacyToken fromResponse:response configuration:configuration];

    if (!result) return nil;
    return legacyToken;
}

- (MSIDAccount *)accountFromResponse:(MSIDTokenResponse *)response configuration:(MSIDConfiguration *)configuration
{
    MSIDAccount *account = [[MSIDAccount alloc] init];
    BOOL result = [self fillAccount:account fromResponse:response configuration:configuration];

    if (!result) return nil;
    return account;
}

#pragma mark - Token helpers

- (BOOL)fillBaseToken:(MSIDBaseToken *)token
         fromResponse:(MSIDTokenResponse *)response
        configuration:(MSIDConfiguration *)configuration
{
    if (!response
        || !configuration)
    {
        return NO;
    }
    
    token.authority = configuration.authority;
    token.clientId = configuration.clientId;
    token.additionalServerInfo = response.additionalServerInfo;
    token.homeAccountId = response.idTokenObj.userId;
    return YES;
}

- (BOOL)fillAccessToken:(MSIDAccessToken *)token
           fromResponse:(MSIDTokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillBaseToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }
    
    token.scopes = [response.target scopeSet];
    token.accessToken = response.accessToken;
    
    if (!token.accessToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize access token when missing access token field");
        return NO;
    }
    NSDate *expiresOn = response.expiryDate;
    
    if (!expiresOn)
    {
        MSID_LOG_WARN(nil, @"The server did not return the expiration time for the access token.");
        expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600.0]; //Assume 1hr expiration
    }
    
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:(uint64_t)[expiresOn timeIntervalSince1970]];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:(uint64_t)[[NSDate date] timeIntervalSince1970]];

    return YES;
}

- (BOOL)fillRefreshToken:(MSIDRefreshToken *)token
            fromResponse:(MSIDTokenResponse *)response
           configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillBaseToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }
    
    if (!response.isMultiResource)
    {
        return NO;
    }
    
    token.refreshToken = response.refreshToken;
    
    if (!token.refreshToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize refresh token when missing refresh token field");
        return NO;
    }

    return YES;
}

- (BOOL)fillIDToken:(MSIDIdToken *)token
       fromResponse:(MSIDTokenResponse *)response
      configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillBaseToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }
    
    token.rawIdToken = response.idToken;
    
    if (!token.rawIdToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize ID token when missing ID token field");
        return NO;
    }

    return YES;
}

- (BOOL)fillLegacyToken:(MSIDLegacySingleResourceToken *)token
           fromResponse:(MSIDTokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillAccessToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }
    
    token.refreshToken = response.refreshToken;
    token.idToken = response.idToken;
    token.legacyUserId = response.idTokenObj.userId;
    token.accessTokenType = response.tokenType ? response.tokenType : MSID_OAUTH2_BEARER;
    return YES;
}

- (BOOL)fillLegacyAccessToken:(MSIDLegacyAccessToken *)token
                 fromResponse:(MSIDTokenResponse *)response
                configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillAccessToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    token.idToken = response.idToken;
    token.legacyUserId = response.idTokenObj.userId;
    token.accessTokenType = response.tokenType ? response.tokenType : MSID_OAUTH2_BEARER;
    return YES;
}

- (BOOL)fillLegacyRefreshToken:(MSIDLegacyRefreshToken *)token
                  fromResponse:(MSIDTokenResponse *)response
                 configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [self fillRefreshToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    token.idToken = response.idToken;
    token.legacyUserId = response.idTokenObj.userId;
    token.realm = response.idTokenObj.realm;
    return YES;
}

- (BOOL)fillAccount:(MSIDAccount *)account
       fromResponse:(MSIDTokenResponse *)response
      configuration:(MSIDConfiguration *)configuration
{
    account.homeAccountId = response.idTokenObj.userId;

    if (!account.homeAccountId)
    {
        return NO;
    }

    account.username = response.idTokenObj.username;
    account.givenName = response.idTokenObj.givenName;
    account.familyName = response.idTokenObj.familyName;
    account.middleName = response.idTokenObj.middleName;
    account.name = response.idTokenObj.name;
    account.authority = configuration.authority;
    account.accountType = response.accountType;
    account.localAccountId = response.idTokenObj.uniqueId;
    return YES;
}

#pragma mark

- (NSMutableDictionary<NSString *, NSString *> *)authorizationParametersFromConfiguration:(MSIDWebviewConfiguration *)configuration
                                                                             requestState:(NSString *)state
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary new];
    
    if (configuration.sliceParameters)
    {
        [parameters addEntriesFromDictionary:configuration.sliceParameters];
    }
    
    if (configuration.extraQueryParameters)
    {
        [parameters addEntriesFromDictionary:configuration.extraQueryParameters];
    }
    
    parameters[MSID_OAUTH2_CLIENT_ID] = configuration.clientId;
    parameters[MSID_OAUTH2_RESPONSE_TYPE] = MSID_OAUTH2_CODE;
    parameters[MSID_OAUTH2_REDIRECT_URI] = configuration.redirectUri;
    parameters[MSID_OAUTH2_CORRELATION_ID_REQUEST] = [configuration.correlationId UUIDString];
    parameters[MSID_OAUTH2_LOGIN_HINT] = configuration.loginHint;
    
    // PKCE
    parameters[MSID_OAUTH2_CODE_CHALLENGE] = configuration.pkce.codeChallenge;
    parameters[MSID_OAUTH2_CODE_CHALLENGE_METHOD] = configuration.pkce.codeChallengeMethod;
    
    NSDictionary *msalId = [MSIDDeviceId deviceId];
    [parameters addEntriesFromDictionary:msalId];
    
    parameters[MSID_OAUTH2_CLAIMS] = configuration.claims;
    
    // State
    parameters[MSID_OAUTH2_STATE] = state.msidBase64UrlEncode;
    
    return parameters;
}

- (NSURL *)startURLFromConfiguration:(MSIDWebviewConfiguration *)configuration requestState:(NSString *)state
{
    if (!configuration) return nil;
    if (configuration.explicitStartURL) return configuration.explicitStartURL;
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:configuration.authorizationEndpoint resolvingAgainstBaseURL:NO];
    NSDictionary *parameters = [self authorizationParametersFromConfiguration:configuration requestState:state];
    
    urlComponents.queryItems = [parameters urlQueryItemsArray];
    urlComponents.percentEncodedQuery = [parameters msidURLFormEncode];
    
    return urlComponents.URL;
}


#pragma mark - Webview response parsing
- (MSIDWebOAuth2Response *)responseWithURL:(NSURL *)url
                              requestState:(NSString *)requestState
                                   context:(id<MSIDRequestContext>)context
                                     error:(NSError **)error
{
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if (parameters.count == 0)
    {
        parameters = [url msidQueryParameters];
    }
    
    // check state
    if (![self verifyRequestState:requestState parameters:parameters])
    {
        if (error) {
            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorInvalidState, @"State returned from the server does not match", nil, nil, nil, nil, nil);
        }
        return nil;
    }
    
    // return base response
    NSError *responseCreationError = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithParameters:parameters
                                                                                context:context error:&responseCreationError];
    if (responseCreationError) {
        if (error)  *error = responseCreationError;
        return nil;
    }
    
    return response;
}

- (BOOL)verifyRequestState:(NSString *)state
                parameters:(NSDictionary *)parameters
{
    if (!state) return YES;
    
    NSString *stateReceived = parameters[MSID_OAUTH2_STATE];
    return [stateReceived.msidBase64UrlDecode isEqualToString:state];
}

- (NSString *)generateStateValue
{
    return [[NSUUID UUID] UUIDString];
}

@end


