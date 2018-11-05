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

#import "MSIDAADV2TokenRequestFactory.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDClientCapabilitiesUtil.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAADRefreshTokenGrantRequest.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDInteractiveRequestParameters.h"

@implementation MSIDAADV2TokenRequestFactory

- (MSIDAuthorizationCodeGrantRequest *)authorizationGrantRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                         codeVerifier:(NSString *)pkceCodeVerifier
                                                                             authCode:(NSString *)authCode
{
    NSString *claims = [MSIDClientCapabilitiesUtil msidClaimsParameterFromCapabilities:parameters.clientCapabilities
                                                                       developerClaims:parameters.claims];
    NSString *allScopes = parameters.allTokenRequestScopes;

    MSIDAADAuthorizationCodeGrantRequest *tokenRequest = [[MSIDAADAuthorizationCodeGrantRequest alloc] initWithEndpoint:parameters.tokenEndpoint
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
    NSString *claims = [MSIDClientCapabilitiesUtil msidClaimsParameterFromCapabilities:parameters.clientCapabilities
                                                                       developerClaims:parameters.claims];
    NSString *allScopes = parameters.allTokenRequestScopes;

    MSIDAADRefreshTokenGrantRequest *tokenRequest = [[MSIDAADRefreshTokenGrantRequest alloc] initWithEndpoint:parameters.tokenEndpoint
                                                                                                     clientId:parameters.clientId
                                                                                                        scope:allScopes
                                                                                                 refreshToken:refreshToken
                                                                                                       claims:claims
                                                                                                      context:parameters];

    return tokenRequest;
}

- (MSIDWebviewConfiguration *)webViewConfigurationWithRequestParameters:(MSIDInteractiveRequestParameters *)parameters
{
    MSIDWebviewConfiguration *configuration = [super webViewConfigurationWithRequestParameters:parameters];

    NSString *claims = [MSIDClientCapabilitiesUtil msidClaimsParameterFromCapabilities:parameters.clientCapabilities
                                                                       developerClaims:parameters.claims];

    configuration.claims = claims;

    /*

     TODO: set uid+utid

     config.uid = _parameters.account.homeAccountId.objectId;
     config.utid = _parameters.account.homeAccountId.tenantId;

     */

    return configuration;
}

@end
