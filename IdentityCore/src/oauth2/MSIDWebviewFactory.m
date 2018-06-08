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

#import "MSIDWebviewFactory.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDDeviceId.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDWebviewSession.h"
#import <WebKit/WebKit.h>
#import "MSIDSystemWebviewController.h"
#import "MSIDPkce.h"

@implementation MSIDWebviewFactory

#pragma mark - Webview creation

- (MSIDWebviewSession *)embeddedWebviewSessionFromConfiguration:(MSIDWebviewConfiguration *)configuration verifyState:(BOOL)verifyState customWebview:(WKWebView *)webview context:(id<MSIDRequestContext>)context
{
    return nil;
}

#if TARGET_OS_IPHONE
- (MSIDWebviewSession *)systemWebviewSessionFromConfiguration:(MSIDWebviewConfiguration *)configuration verifyState:(BOOL)verifyState context:(id<MSIDRequestContext>)context
{
    NSString *state = [self generateStateValue];
    NSURL *startURL = [self startURLFromConfiguration:configuration requestState:state];
    NSURL *redirectURL = [NSURL URLWithString:configuration.redirectUri];
    
    MSIDSystemWebviewController *systemWVC = [[MSIDSystemWebviewController alloc] initWithStartURL:startURL
                                                                                 callbackURLScheme:redirectURL.scheme
                                                                                           context:context];
    
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:systemWVC
                                                                                factory:self
                                                                           requestState:state
                                                                            verifyState:verifyState];
    return session;
}
#endif

#pragma mark - Webview helpers

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
    
    parameters[MSID_OAUTH2_SCOPE] = MSID_OAUTH2_SCOPE_OPENID_VALUE;
    parameters[MSID_OAUTH2_CLIENT_ID] = configuration.clientId;
    parameters[MSID_OAUTH2_RESPONSE_TYPE] = MSID_OAUTH2_CODE;
    parameters[MSID_OAUTH2_REDIRECT_URI] = configuration.redirectUri;
    parameters[MSID_OAUTH2_CORRELATION_ID_REQUEST] = [configuration.correlationId UUIDString];
    parameters[MSID_OAUTH2_LOGIN_HINT] = configuration.loginHint;
    
    // PKCE
    if (configuration.pkce)
    {
        parameters[MSID_OAUTH2_CODE_CHALLENGE] = configuration.pkce.codeChallenge;
        parameters[MSID_OAUTH2_CODE_CHALLENGE_METHOD] = configuration.pkce.codeChallengeMethod;
    }
    
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
    
    if (!configuration.authorizationEndpoint) return nil;
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:configuration.authorizationEndpoint resolvingAgainstBaseURL:NO];
    NSDictionary *parameters = [self authorizationParametersFromConfiguration:configuration requestState:state];
    
    urlComponents.queryItems = [parameters urlQueryItemsArray];
    urlComponents.percentEncodedQuery = [parameters msidURLFormEncode];
    
    return urlComponents.URL;
}

#pragma mark - Webview response parsing
- (MSIDWebviewResponse *)responseWithURL:(NSURL *)url
                            requestState:(NSString *)requestState
                             verifyState:(BOOL)verifyState
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    NSError *stateVerifierError = nil;
    if (![self verifyRequestState:requestState responseURL:url error:&stateVerifierError] && verifyState)
    {
        if (error)
        {
            *error = stateVerifierError;
        }
        return nil;
    }
    
    return [self responseWithURL:url context:context error:error];
}

- (MSIDWebviewResponse *)responseWithURL:(NSURL *)url
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
//     return base response
    NSError *responseCreationError = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:url context:context error:&responseCreationError];
    if (responseCreationError) {
        if (error)  *error = responseCreationError;
        return nil;
    }
    
    return response;
}

- (BOOL)verifyRequestState:(NSString *)requestState
        responseURL:(NSURL *)url
        error:(NSError **)error
{
    // Check for auth response
    // Try both the URL and the fragment parameters:
    NSDictionary *parameters = [url msidFragmentParameters];
    if (parameters.count == 0)
    {
        parameters = [url msidQueryParameters];
    }

    NSString *stateReceived = parameters[MSID_OAUTH2_STATE];
    BOOL result = [requestState isEqualToString:stateReceived.msidBase64UrlDecode];
    
    if (!result) {
        MSID_LOG_WARN(nil, @"Missing or invalid state returned state: %@", stateReceived);
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorInvalidState,
                                     [NSString stringWithFormat:@"Missing or invalid state returned state: %@", stateReceived],
                                     nil, nil, nil, nil, nil);
        }
    }
    
    return result;
}

- (NSString *)generateStateValue
{
    return [[NSUUID UUID] UUIDString];
}

@end
