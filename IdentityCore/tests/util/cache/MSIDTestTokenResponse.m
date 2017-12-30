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
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDTestIdTokenUtil.h"

@implementation MSIDTestTokenResponse

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponse
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    NSString *jsonString = [NSString stringWithFormat:@"{\"%@\": \"access_token\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"scope\": \"%@%@\", \"refresh_token\": \"%@\", \"id_token\": \"%@\", \"client_info\": \"%@\"}", DEFAULT_TEST_ACCESS_TOKEN, DEFAULT_TEST_RESOURCE, DEFAULT_TEST_SCOPE, DEFAULT_TEST_REFRESH_TOKEN, idToken, clientInfoString];
    
    return [self v2TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV2TokenResponse *)v2DefaultTokenResponseWithFamilyId:(NSString *)familyId
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    
    NSString *jsonString = [NSString stringWithFormat:@"{\"%@\": \"access_token\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"scope\": \"%@%@\", \"refresh_token\": \"%@\", \"id_token\": \"%@\", \"client_info\": \"%@\", \"foci\":\"%@\"}", DEFAULT_TEST_ACCESS_TOKEN, DEFAULT_TEST_RESOURCE, DEFAULT_TEST_SCOPE, DEFAULT_TEST_REFRESH_TOKEN, idToken, clientInfoString, familyId];
    
    return [self v2TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV2TokenResponse *)v2TokenResponseFromJSON:(NSString *)jsonString
{
    return [[MSIDAADV2TokenResponse alloc] initWithJSONData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] error:nil];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponse
{
    return [self v1TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                    rt:DEFAULT_TEST_REFRESH_TOKEN
                              resource:DEFAULT_TEST_RESOURCE
                                   uid:DEFAULT_TEST_UID
                                  utid:DEFAULT_TEST_UTID
                                   upn:DEFAULT_TEST_ID_TOKEN_USERNAME
                              tenantId:DEFAULT_TEST_UTID];
}

+ (MSIDAADV1TokenResponse *)v1TokenResponseWithAT:(NSString *)accessToken
                                               rt:(NSString *)refreshToken
                                         resource:(NSString *)resource
                                              uid:(NSString *)uid
                                             utid:(NSString *)utid
                                              upn:(NSString *)upn
                                         tenantId:(NSString *)tenantId
{
    NSString *clientInfoString = [@{ @"uid" : uid, @"utid" : utid} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:DEFAULT_TEST_ID_TOKEN_NAME upn:upn tenantId:tenantId];
    
    NSString *jsonString = [NSString stringWithFormat:@"{\"access_token\": \"%@\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"resource\": \"%@\", \"refresh_token\": \"%@\", \"id_token\": \"%@\", \"client_info\": \"%@\"}", accessToken, resource, refreshToken, idToken, clientInfoString];
    
    return [self v1TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithoutClientInfo
{
    NSString *idToken = [MSIDTestIdTokenUtil defaultV1IdToken];
    
    NSString *jsonString = [NSString stringWithFormat:@"{\"access_token\": \"%@\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"resource\": \"%@\", \"refresh_token\": \"%@\", \"id_token\": \"%@\"}", DEFAULT_TEST_ACCESS_TOKEN, DEFAULT_TEST_RESOURCE, DEFAULT_TEST_REFRESH_TOKEN, idToken];
    
    return [self v1TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV1TokenResponse *)v1DefaultTokenResponseWithFamilyId:(NSString *)familyId
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    NSString *idToken = [MSIDTestIdTokenUtil defaultV1IdToken];
    
    NSString *jsonString = [NSString stringWithFormat:@"{\"access_token\": \"%@\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"resource\": \"%@\", \"refresh_token\": \"%@\", \"id_token\": \"%@\", \"client_info\": \"%@\", \"foci\":\"%@\"}", DEFAULT_TEST_ACCESS_TOKEN, DEFAULT_TEST_RESOURCE, DEFAULT_TEST_REFRESH_TOKEN, idToken, clientInfoString, familyId];
    
    return [self v1TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV1TokenResponse *)v1SingleResourceTokenResponse
{
    NSString *jsonString = [NSString stringWithFormat:@"{\"access_token\": \"%@\", \"token_type\": \"Bearer\",\"expires_in\": 3599, \"refresh_token\": \"%@\"}", DEFAULT_TEST_ACCESS_TOKEN, DEFAULT_TEST_REFRESH_TOKEN];
    
    return [self v1TokenResponseFromJSON:jsonString];
}

+ (MSIDAADV1TokenResponse *)v1TokenResponseFromJSON:(NSString *)jsonString
{
    return [[MSIDAADV1TokenResponse alloc] initWithJSONData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] error:nil];
}

@end
