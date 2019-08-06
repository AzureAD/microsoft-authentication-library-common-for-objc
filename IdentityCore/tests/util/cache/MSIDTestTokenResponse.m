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

#import "MSIDTestTokenResponse.h"
#import "MSIDTokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDOAuth2Constants.h"

@implementation MSIDTestTokenResponse

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponse
{
    return [self.class v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                          RT:DEFAULT_TEST_REFRESH_TOKEN
                                      scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                         uid:DEFAULT_TEST_UID
                                        utid:DEFAULT_TEST_UTID
                                    familyId:nil];
}

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithFamilyId:(NSString *)familyId
{
    return [self.class v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                          RT:DEFAULT_TEST_REFRESH_TOKEN
                                      scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                         uid:DEFAULT_TEST_UID
                                        utid:DEFAULT_TEST_UTID
                                    familyId:familyId];
}

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithScopes:(NSOrderedSet<NSString *> *)scopes
{
    return [self.class v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                          RT:DEFAULT_TEST_REFRESH_TOKEN
                                      scopes:scopes
                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                         uid:DEFAULT_TEST_UID
                                        utid:DEFAULT_TEST_UTID
                                    familyId:nil];
}

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithRefreshToken:(NSString *)refreshToken
{
    return [self.class v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                          RT:refreshToken
                                      scopes:[NSOrderedSet orderedSetWithObjects:DEFAULT_TEST_SCOPE, nil]
                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                         uid:DEFAULT_TEST_UID
                                        utid:DEFAULT_TEST_UTID
                                    familyId:nil];
}

+ (MSIDAADV2TokenResponse *)v2TokenResponseWithAT:(NSString *)accessToken
                                               RT:(NSString *)refreshToken
                                           scopes:(NSOrderedSet<NSString *> *)scopes
                                          idToken:(NSString *)idToken
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                         familyId:(NSString *)familyId
{
    NSString *clientInfoString = nil;

    if (uid && utid)
    {
        clientInfoString = [@{ @"uid" : uid, @"utid" : utid} msidBase64UrlJson];
    }

    NSString *scopesString = scopes.msidToString;
    
    NSMutableDictionary *jsonDictionary = [@{MSID_OAUTH2_TOKEN_TYPE: @"Bearer",
                                            MSID_OAUTH2_EXPIRES_IN: @"3600",
                                            MSID_OAUTH2_EXT_EXPIRES_IN: @"3600",
                                            MSID_OAUTH2_SCOPE: scopesString
                                             } mutableCopy];

    if (clientInfoString)
    {
        jsonDictionary[MSID_OAUTH2_CLIENT_INFO] = clientInfoString;
    }
    
    if (accessToken)
    {
        jsonDictionary[MSID_OAUTH2_ACCESS_TOKEN] = accessToken;
    }
    
    if (refreshToken)
    {
        jsonDictionary[MSID_OAUTH2_REFRESH_TOKEN] = refreshToken;
    }
    
    if (idToken)
    {
        jsonDictionary[MSID_OAUTH2_ID_TOKEN] = idToken;
    }
    
    if (familyId)
    {
        jsonDictionary[MSID_FAMILY_ID] = familyId;
    }
    
    return [self v2TokenResponseFromJSONDictionary:jsonDictionary];
}

+ (MSIDAADV2TokenResponse *)v2TokenResponseFromJSONDictionary:(NSDictionary *)jsonDictionary
{
    return [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonDictionary error:nil];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponse
{
    return [self v1DefaultTokenResponseWithAdditionalFields:nil];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithAdditionalFields:(NSDictionary *)additionalFields
{
    return [self v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                    rt:DEFAULT_TEST_REFRESH_TOKEN
                              resource:DEFAULT_TEST_RESOURCE
                                   uid:DEFAULT_TEST_UID
                                  utid:DEFAULT_TEST_UTID
                                   upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                              tenantId:DEFAULT_TEST_UTID
                      additionalFields:additionalFields];
}

+ (MSIDAADV1TokenResponse *)v1TokenResponseWithAT:(NSString *)accessToken
                                               rt:(NSString *)refreshToken
                                         resource:(NSString *)resource
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                              upn:(NSString *)upn
                                         tenantId:(NSString *)tenantId
                                 additionalFields:(NSDictionary *)additionalFields
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:upn oid:nil tenantId:tenantId];
    return [self v1TokenResponseWithAT:accessToken rt:refreshToken resource:resource uid:uid utid:utid idToken:idToken additionalFields:additionalFields];
}

+ (MSIDAADV1TokenResponse *)v1TokenResponseWithAT:(NSString *)accessToken
                                               rt:(NSString *)refreshToken
                                         resource:(NSString *)resource
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                          idToken:(NSString *)idToken
                                 additionalFields:(NSDictionary *)additionalFields
{
    NSString *clientInfoString = (uid && utid) ? [@{ @"uid" : uid, @"utid" : utid} msidBase64UrlJson] : nil;
    
    NSMutableDictionary *jsonDictionary = [@{MSID_OAUTH2_TOKEN_TYPE: @"Bearer",
                                             MSID_OAUTH2_EXPIRES_IN: @"3600"
                                             } mutableCopy];
    
    if (resource) jsonDictionary[MSID_OAUTH2_RESOURCE] = resource;
    if (accessToken) jsonDictionary[MSID_OAUTH2_ACCESS_TOKEN] = accessToken;
    if (refreshToken) jsonDictionary[MSID_OAUTH2_REFRESH_TOKEN] = refreshToken;
    if (idToken) jsonDictionary[MSID_OAUTH2_ID_TOKEN] = idToken;
    if (clientInfoString) jsonDictionary[MSID_OAUTH2_CLIENT_INFO] = clientInfoString;

    [jsonDictionary addEntriesFromDictionary:additionalFields];
    
    return [self v1TokenResponseFromJSONDictionary:jsonDictionary];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithoutClientInfo
{    
    return [self v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                    rt:DEFAULT_TEST_REFRESH_TOKEN
                              resource:DEFAULT_TEST_RESOURCE
                                   uid:nil utid:nil
                                   upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                              tenantId:nil
                      additionalFields:nil];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithFamilyId:(NSString *)familyId
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil defaultV1IdToken];
    
    NSDictionary *jsonDict = @{MSID_OAUTH2_ACCESS_TOKEN: DEFAULT_TEST_ACCESS_TOKEN,
                               MSID_OAUTH2_TOKEN_TYPE: @"Bearer",
                               MSID_OAUTH2_EXPIRES_IN: @"3600",
                               MSID_OAUTH2_RESOURCE:DEFAULT_TEST_RESOURCE,
                               MSID_OAUTH2_REFRESH_TOKEN:DEFAULT_TEST_REFRESH_TOKEN,
                               MSID_OAUTH2_ID_TOKEN: idToken,
                               MSID_OAUTH2_CLIENT_INFO: clientInfoString,
                               MSID_FAMILY_ID: familyId
                               };
    
    return [self v1TokenResponseFromJSONDictionary:jsonDict];
}

+ (MSIDAADV1TokenResponse *)v1SingleResourceTokenResponse
{
    return [self v1SingleResourceTokenResponseWithAccessToken:DEFAULT_TEST_ACCESS_TOKEN
                                                 refreshToken:DEFAULT_TEST_REFRESH_TOKEN];
}

+ (MSIDAADV1TokenResponse *)v1SingleResourceTokenResponseWithAccessToken:(NSString *)accessToken
                                                            refreshToken:(NSString *)refreshToken
{
    NSMutableDictionary *jsonDictionary = [@{MSID_OAUTH2_TOKEN_TYPE: @"Bearer",
                                            MSID_OAUTH2_EXPIRES_IN: @"3600"} mutableCopy];
    
    if (accessToken)
    {
        jsonDictionary[MSID_OAUTH2_ACCESS_TOKEN] = accessToken;
    }
    
    if (refreshToken)
    {
        jsonDictionary[MSID_OAUTH2_REFRESH_TOKEN] = refreshToken;
    }
    
    return [self v1TokenResponseFromJSONDictionary:jsonDictionary];
}

+ (MSIDAADV1TokenResponse *)v1TokenResponseFromJSONDictionary:(NSDictionary *)jsonDictionary
{
    return [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonDictionary error:nil];
}

+ (MSIDTokenResponse *)defaultTokenResponseWithAT:(NSString *)accessToken
                                               RT:(NSString *)refreshToken
                                           scopes:(NSOrderedSet<NSString *> *)scopes
                                         username:(NSString *)username
                                          subject:(NSString *)subject
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:username subject:subject];
    
    NSString *scopesString = scopes.msidToString;

    NSMutableDictionary *dictionary = [@{MSID_OAUTH2_TOKEN_TYPE: @"Bearer",
                                         MSID_OAUTH2_EXPIRES_IN: @3600,
                                         MSID_OAUTH2_SCOPE: scopesString
                                         } mutableCopy];

    if (accessToken)
    {
        dictionary[MSID_OAUTH2_ACCESS_TOKEN] = accessToken;
    }

    if (refreshToken)
    {
        dictionary[MSID_OAUTH2_REFRESH_TOKEN] = refreshToken;
    }

    if (idToken)
    {
        dictionary[MSID_OAUTH2_ID_TOKEN] = idToken;
    }
    
    return [[MSIDTokenResponse alloc] initWithJSONDictionary:dictionary error:nil];
}

@end
