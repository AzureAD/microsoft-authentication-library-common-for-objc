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

#import "MSIDTokenRequestFactory.h"
#import "MSIDAuthorizationCodeGrantRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDClientCapabilitiesUtil.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDRefreshTokenGrantRequest.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDTokenRequestFactory

- (MSIDAuthorizationCodeGrantRequest *)authorizationGrantRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                         codeVerifier:(NSString *)pkceCodeVerifier
                                                                             authCode:(NSString *)authCode
{
    NSString *claims = [MSIDClientCapabilitiesUtil jsonFromClaims:parameters.claims];
    NSString *allScopes = [parameters allTokenRequestScopes];

    MSIDAuthorizationCodeGrantRequest *tokenRequest = [[MSIDAuthorizationCodeGrantRequest alloc] initWithEndpoint:parameters.tokenEndpoint
                                                                                                         clientId:parameters.clientId
                                                                                                            scope:allScopes
                                                                                                      redirectUri:parameters.redirectUri
                                                                                                             code:authCode
                                                                                                           claims:claims
                                                                                                     codeVerifier:pkceCodeVerifier
                                                                                                          context:parameters];
    return tokenRequest;
}

- (MSIDRefreshTokenGrantRequest *)refreshTokenRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                              refreshToken:(NSString *)refreshToken
{
    NSString *allScopes = [parameters allTokenRequestScopes];

    MSIDRefreshTokenGrantRequest *tokenRequest = [[MSIDRefreshTokenGrantRequest alloc] initWithEndpoint:parameters.tokenEndpoint
                                                                                               clientId:parameters.clientId
                                                                                                  scope:allScopes
                                                                                           refreshToken:refreshToken
                                                                                                context:parameters];
    return tokenRequest;
}

- (MSIDWebviewConfiguration *)webViewConfigurationWithRequestParameters:(MSIDInteractiveRequestParameters *)parameters
{

    MSIDWebviewConfiguration *configuration = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:parameters.authority.metadata.authorizationEndpoint
                                                                                                  redirectUri:parameters.redirectUri
                                                                                                     clientId:parameters.clientId resource:nil
                                                                                                       scopes:parameters.allAuthorizeRequestScopes
                                                                                                correlationId:parameters.correlationId
                                                                                                   enablePkce:YES];

    configuration.promptBehavior = parameters.promptType;
    configuration.loginHint = parameters.accountIdentifier.legacyAccountId ?: parameters.loginHint;
    configuration.extraQueryParameters = parameters.extraQueryParameters;
    configuration.sliceParameters = parameters.sliceParameters;

    NSString *claims = [MSIDClientCapabilitiesUtil jsonFromClaims:parameters.claims];

    if (![NSString msidIsStringNilOrBlank:claims])
    {
        configuration.claims = claims;
    }

    return configuration;
}

@end
