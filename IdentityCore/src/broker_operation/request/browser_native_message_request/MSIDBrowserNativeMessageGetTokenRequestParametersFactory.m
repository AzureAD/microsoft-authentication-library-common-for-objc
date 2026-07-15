//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#import "MSIDBrowserNativeMessageGetTokenRequestParametersFactory.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDRequestParameters.h"
#import "MSIDOAuth2Constants.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDError.h"

static NSString * const MSIDBrowserNativeMessageChildClientIdKey = @"child_client_id";
static NSString * const MSIDBrowserNativeMessageChildRedirectUriKey = @"child_redirect_uri";

@implementation MSIDBrowserNativeMessageGetTokenRequestParametersFactory

+ (MSIDInteractiveTokenRequestParameters *)requestParametersWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                            requestType:(MSIDRequestType)requestType
                                         boundAppRefreshTokenRequested:(BOOL)boundAppRefreshTokenRequested
                                                   correlationIdOverride:(NSUUID *)correlationIdOverride
                                                                 error:(NSError *__autoreleasing *)error
{
    MSIDAADAuthority *authority = request.authority;
    if (!authority)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                     @"An authority is required to create GetToken request parameters.",
                                     nil, nil, nil, correlationIdOverride ?: request.correlationId, nil, NO);
        }

        return nil;
    }

    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:MSID_OAUTH2_SCOPE_OPENID_VALUE,
                                MSID_OAUTH2_SCOPE_PROFILE_VALUE,
                                MSID_OAUTH2_SCOPE_OFFLINE_ACCESS_VALUE,
                                nil];
    NSOrderedSet *requestedScopes = [NSOrderedSet msidOrderedSetFromString:request.scopes normalize:YES];
    NSOrderedSet *resourceScopes = [requestedScopes msidMinusOrderedSet:oidcScopes normalize:YES];

    NSString *clientId = request.clientId;
    NSString *redirectUri = request.redirectUri;
    NSMutableDictionary *extraParameters = [request.extraParameters mutableCopy];
    NSString *childClientId = extraParameters[MSIDBrowserNativeMessageChildClientIdKey];
    NSString *childRedirectUri = extraParameters[MSIDBrowserNativeMessageChildRedirectUriKey];
    NSString *nestedAuthBrokerClientId = nil;
    NSString *nestedAuthBrokerRedirectUri = nil;

    if (![NSString msidIsStringNilOrBlank:childClientId]
        && ![NSString msidIsStringNilOrBlank:childRedirectUri])
    {
        nestedAuthBrokerClientId = clientId;
        clientId = childClientId;
        nestedAuthBrokerRedirectUri = redirectUri;
        redirectUri = childRedirectUri;
        [extraParameters removeObjectsForKeys:@[MSIDBrowserNativeMessageChildClientIdKey,
                                                MSIDBrowserNativeMessageChildRedirectUriKey]];
    }

    NSError *localError = nil;
    MSIDAuthenticationScheme *authScheme = request.authScheme ?: [MSIDAuthenticationScheme new];

    // Initialize the validated core token request state, including authority, client,
    // redirect URI, scopes, authentication scheme, correlation ID, and request type.
    MSIDInteractiveTokenRequestParameters *parameters =
    [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                          authScheme:authScheme
                                                         redirectUri:redirectUri
                                                            clientId:clientId
                                                              scopes:resourceScopes
                                                          oidcScopes:oidcScopes
                                                extraScopesToConsent:nil
                                                       correlationId:correlationIdOverride ?: request.correlationId
                                                      telemetryApiId:nil
                                                       brokerOptions:nil
                                                         requestType:requestType
                                                 intuneAppIdentifier:nil
                                                               error:&localError];

    if (!parameters)
    {
        if (error)
        {
            *error = localError;
        }

        return nil;
    }

    // The designated initializer does not accept Browser Native Message-specific
    // values, so copy those fields and execution flags onto the initialized request.
    parameters.accountIdentifier = request.accountId;
    parameters.promptType = request.prompt;
    parameters.loginHint = request.loginHint;
    parameters.claimsRequest = request.claimsRequest;
    parameters.nonce = request.nonce;
    parameters.instanceAware = request.instanceAware;
    parameters.webPageUri = request.sender.absoluteString;
    parameters.platformSequence = request.platformSequence;
    parameters.extraURLQueryParameters = extraParameters;
    parameters.nestedAuthBrokerClientId = nestedAuthBrokerClientId;
    parameters.nestedAuthBrokerRedirectUri = nestedAuthBrokerRedirectUri;
    parameters.allowAnyExtraURLQueryParameters = YES;
    parameters.ignoreScopeValidation = YES;
    parameters.bypassRedirectURIValidation = YES;
    parameters.isBoundAppRefreshTokenRequested = boundAppRefreshTokenRequested;

    return parameters;
}

@end
