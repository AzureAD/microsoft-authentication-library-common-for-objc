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
#import "MSIDSystemWebviewRequest.h"
#import "MSIDSystemWebviewController.h"

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
                                 request:(MSIDRequestParameters *)requestParams
{
    MSIDBaseToken *baseToken = [[MSIDBaseToken alloc] init];
    return [self fillBaseToken:baseToken fromResponse:response request:requestParams];
}

- (MSIDAccessToken *)accessTokenFromResponse:(MSIDTokenResponse *)response
                                     request:(MSIDRequestParameters *)requestParams
{
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] init];
    return [self fillAccessToken:accessToken fromResponse:response request:requestParams];
}

- (MSIDRefreshToken *)refreshTokenFromResponse:(MSIDTokenResponse *)response
                                       request:(MSIDRequestParameters *)requestParams
{
    MSIDRefreshToken *refreshToken = [[MSIDRefreshToken alloc] init];
    return [self fillRefreshToken:refreshToken fromResponse:response request:requestParams];
}

- (MSIDIdToken *)idTokenFromResponse:(MSIDTokenResponse *)response
                             request:(MSIDRequestParameters *)requestParams
{
    MSIDIdToken *idToken = [[MSIDIdToken alloc] init];
    return [self fillIDToken:idToken fromResponse:response request:requestParams];
}

- (MSIDLegacySingleResourceToken *)legacyTokenFromResponse:(MSIDTokenResponse *)response
                                                   request:(MSIDRequestParameters *)requestParams
{
    MSIDLegacySingleResourceToken *legacyToken = [[MSIDLegacySingleResourceToken alloc] init];
    return [self fillLegacyToken:legacyToken fromResponse:response request:requestParams];
}

- (MSIDAccount *)accountFromResponse:(MSIDTokenResponse *)response request:(MSIDRequestParameters *)requestParams
{
    MSIDAccount *account = [[MSIDAccount alloc] init];
    return [self fillAccount:account fromResponse:response request:requestParams];
}

#pragma mark - Token helpers

- (MSIDBaseToken *)fillBaseToken:(MSIDBaseToken *)token
                    fromResponse:(MSIDTokenResponse *)response
                         request:(MSIDRequestParameters *)requestParams
{
    if (!response
        || !requestParams)
    {
        return nil;
    }

    token.authority = requestParams.authority;
    token.clientId = requestParams.clientId;
    token.additionalServerInfo = response.additionalServerInfo;
    token.username = response.idTokenObj.username;
    token.uniqueUserId = response.idTokenObj.userId;

    return token;
}

- (MSIDAccessToken *)fillAccessToken:(MSIDAccessToken *)token
                        fromResponse:(MSIDTokenResponse *)response
                             request:(MSIDRequestParameters *)requestParams
{
    token = (MSIDAccessToken *) [self fillBaseToken:token fromResponse:response request:requestParams];

    if (!token)
    {
        return nil;
    }

    token.scopes = [response.target scopeSet];

    token.accessTokenType = response.tokenType ? response.tokenType : MSID_OAUTH2_BEARER;
    token.accessToken = response.accessToken;

    if (!token.accessToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize access token when missing access token field");
        return nil;
    }

    token.idToken = response.idToken;

    NSDate *expiresOn = response.expiryDate;

    if (!expiresOn)
    {
        MSID_LOG_WARN(nil, @"The server did not return the expiration time for the access token.");
        expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600.0]; //Assume 1hr expiration
    }

    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:(uint64_t)[expiresOn timeIntervalSince1970]];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:(uint64_t)[[NSDate date] timeIntervalSince1970]];

    return token;
}

- (MSIDRefreshToken *)fillRefreshToken:(MSIDRefreshToken *)token
                          fromResponse:(MSIDTokenResponse *)response
                               request:(MSIDRequestParameters *)requestParams
{
    token = (MSIDRefreshToken *) [self fillBaseToken:token fromResponse:response request:requestParams];

    if (!token)
    {
        return nil;
    }

    if (!response.isMultiResource)
    {
        return nil;
    }

    token.refreshToken = response.refreshToken;

    if (!token.refreshToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize refresh token when missing refresh token field");
        return nil;
    }

    token.idToken = response.idToken;

    return token;
}

- (MSIDIdToken *)fillIDToken:(MSIDIdToken *)token
                fromResponse:(MSIDTokenResponse *)response
                     request:(MSIDRequestParameters *)requestParams
{
    token = (MSIDIdToken *) [self fillBaseToken:token fromResponse:response request:requestParams];

    if (!token)
    {
        return nil;
    }

    token.rawIdToken = response.idToken;

    if (!token.rawIdToken)
    {
        MSID_LOG_ERROR(nil, @"Trying to initialize ID token when missing ID token field");
        return nil;
    }

    return token;
}

- (MSIDLegacySingleResourceToken *)fillLegacyToken:(MSIDLegacySingleResourceToken *)token
                                      fromResponse:(MSIDTokenResponse *)response
                                           request:(MSIDRequestParameters *)requestParams
{
    token = (MSIDLegacySingleResourceToken *) [self fillAccessToken:token fromResponse:response request:requestParams];

    if (!token)
    {
        return nil;
    }

    token.refreshToken = response.refreshToken;
    return token;
}

- (MSIDAccount *)fillAccount:(MSIDAccount *)account
                fromResponse:(MSIDTokenResponse *)response
                     request:(MSIDRequestParameters *)requestParams
{
    account.uniqueUserId = response.idTokenObj.userId;
    account.username = response.idTokenObj.username;
    account.firstName = response.idTokenObj.givenName;
    account.lastName = response.idTokenObj.familyName;
    account.authority = requestParams.authority;
    account.accountType = response.accountType;
    account.legacyUserId = response.idTokenObj.userId;
    return account;
}

#pragma mark - Webview controllers
- (id<MSIDWebviewInteracting>)embeddedWebviewControllerWithRequest:(MSIDRequestParameters *)requestParams
                                                     customWebview:(WKWebView *)webview
{
    // TODO: return default
    return nil;
}

- (id<MSIDWebviewInteracting>)systemWebviewControllerWithRequest:(MSIDRequestParameters *)requestParams
{
    // TODO: return default
    return nil;
}

@end
