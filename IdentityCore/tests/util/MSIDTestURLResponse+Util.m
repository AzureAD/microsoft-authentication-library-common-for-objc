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

#import "MSIDTestURLResponse+Util.h"
#import "MSIDDeviceId.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestURLResponse.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@implementation MSIDTestURLResponse (Util)

+ (NSDictionary *)msidDefaultRequestHeaders
{
    static NSDictionary *s_msidHeaders = nil;
    static dispatch_once_t headersOnce;

    dispatch_once(&headersOnce, ^{
        NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
        headers[@"return-client-request-id"] = @"true";
        headers[@"client-request-id"] = [MSIDTestRequireValueSentinel sentinel];
        headers[@"Accept"] = @"application/json";
        headers[@"x-app-name"] = @"MSIDTestsHostApp";
        headers[@"x-app-ver"] = @"1.0";
        headers[@"x-ms-PkeyAuth"] = @"1.0";

        s_msidHeaders = [headers copy];
    });

    return s_msidHeaders;
}

+ (MSIDTestURLResponse *)discoveryResponseForAuthority:(NSString *)authority
{
    NSURL *authorityURL = [NSURL URLWithString:authority];

    NSString *authorizationEndpoint = [NSString stringWithFormat:@"%@/oauth2/v2.0/authorize", authority];

    NSString *requestUrl = [NSString stringWithFormat:@"https://%@/common/discovery/instance?api-version=1.1&authorization_endpoint=%@", authorityURL.msidHostWithPortIfNecessary, [authorizationEndpoint msidWWWFormURLEncode]];

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:requestUrl]
                                                                  statusCode:200
                                                                 HTTPVersion:@"1.1"
                                                                headerFields:nil];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse request:[NSURL URLWithString:requestUrl]
                                                                  reponse:httpResponse];
    NSDictionary *headers = [self msidDefaultRequestHeaders];
    discoveryResponse->_requestHeaders = [headers mutableCopy];

    NSString *tenantDiscoveryEndpoint = [NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority];

    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : tenantDiscoveryEndpoint,
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             },
                                         @{
                                             @"preferred_network": @"login.microsoftonline.de",
                                             @"preferred_cache": @"login.microsoftonline.de",
                                             @"aliases": @[@"login.microsoftonline.de"]
                                             }
                                         ]
                                 };
    [discoveryResponse setResponseJSON:responseJson];
    return discoveryResponse;
}

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
{
    NSDictionary *oidcReqHeaders = [self msidDefaultRequestHeaders];

    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/authorize", authority],
       @"issuer" : @"issuer"
       };

    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority]
                           requestHeaders:oidcReqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:oidcJson];

    return oidcResponse;
}

+ (MSIDTestURLResponse *)errorRefreshTokenGrantResponseWithRT:(NSString *)requestRT
                                                requestClaims:(NSString *)requestClaims
                                                requestScopes:(NSString *)requestScopes
                                                responseError:(NSString *)oauthError
                                                  description:(NSString *)oauthDescription
                                                     subError:(NSString *)subError
                                                          url:(NSString *)url
                                                 responseCode:(NSUInteger)responseCode
{
    NSMutableDictionary *reqHeaders = [[self msidDefaultRequestHeaders] mutableCopy];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];

    NSMutableDictionary *requestBody = [@{ @"client_id" : @"my_client_id",
                                           @"scope" : requestScopes,
                                           @"grant_type" : @"refresh_token",
                                           @"refresh_token" : requestRT,
                                           @"client_info" : @"1"} mutableCopy];

    if (requestClaims)
    {
        requestBody[@"claims"] = requestClaims;
    }

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:requestBody
                        responseURLString:url
                             responseCode:responseCode ? responseCode : 200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"error": oauthError,
                                             @"error_description": oauthDescription ?: @"descr",
                                             @"suberror": subError ?: @""
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];
    return response;
}

+ (MSIDTestURLResponse *)refreshTokenGrantResponseWithRT:(NSString *)requestRT
                                           requestClaims:(NSString *)requestClaims
                                           requestScopes:(NSString *)requestScopes
                                              responseAT:(NSString *)responseAT
                                              responseRT:(NSString *)responseRT
                                              responseID:(NSString *)responseID
                                           responseScope:(NSString *)responseScope
                                      responseClientInfo:(NSString *)responseClientInfo
                                                     url:(NSString *)url
                                            responseCode:(NSUInteger)responseCode
                                               expiresIn:(NSString *)expiresIn
{
    NSMutableDictionary *reqHeaders = [[self msidDefaultRequestHeaders] mutableCopy];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];

    NSDictionary *responseDict = [self tokenResponseWithAT:responseAT
                                                responseRT:responseRT
                                                responseID:responseID
                                             responseScope:responseScope
                                        responseClientInfo:responseClientInfo
                                                 expiresIn:expiresIn
                                                      foci:nil
                                              extExpiresIn:nil];

    NSMutableDictionary *requestBody = [@{ @"client_id" : @"my_client_id",
                                          @"scope" : requestScopes,
                                          @"grant_type" : @"refresh_token",
                                          @"refresh_token" : requestRT,
                                          @"client_info" : @"1"} mutableCopy];

    if (requestClaims)
    {
        requestBody[@"claims"] = requestClaims;
    }

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:requestBody
                        responseURLString:url
                             responseCode:responseCode ? responseCode : 200
                         httpHeaderFields:nil
                         dictionaryAsJSON:responseDict];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];
    return response;
}

+ (NSDictionary *)tokenResponseWithAT:(NSString *)responseAT
                           responseRT:(NSString *)responseRT
                           responseID:(NSString *)responseID
                        responseScope:(NSString *)responseScope
                   responseClientInfo:(NSString *)responseClientInfo
                            expiresIn:(NSString *)expiresIn
                                 foci:(NSString *)foci
                         extExpiresIn:(NSString *)extExpiresIn
{
    NSDictionary *clientInfoClaims = @{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID};

    NSString *defaultIDToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME subject:@"sub" givenName:@"Test" familyName:@"User" name:@"Test Name" version:@"2.0" tid:DEFAULT_TEST_UTID];

    NSMutableDictionary *responseDictionary = [@{ @"access_token" : responseAT ?: DEFAULT_TEST_ACCESS_TOKEN,
                                                  @"expires_in" : expiresIn ?: @"3600",
                                                  @"foci": foci ?: @"",
                                                  @"refresh_token" : responseRT ?: DEFAULT_TEST_REFRESH_TOKEN,
                                                  @"id_token": responseID ?: defaultIDToken,
                                                  @"client_info" : responseClientInfo ?: [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]],
                                                  @"scope": responseScope ?: @"user.read user.write tasks.read"} mutableCopy];

    if (extExpiresIn)
    {
        responseDictionary[@"ext_expires_in"] = extExpiresIn;
    }

    return responseDictionary;
}

@end
