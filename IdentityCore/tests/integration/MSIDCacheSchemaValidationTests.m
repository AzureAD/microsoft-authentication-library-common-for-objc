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

#import <XCTest/XCTest.h>
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADV2TokenResponse.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAccessToken.h"
#import "MSIDIdToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDDefaultCredentialCacheKey.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDB2CTokenResponse.h"
#import "MSIDB2COauth2Factory.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAppMetadataCacheKey.h"

/*
 Those tests validate full schema compliance to test cases defined in the schema spec
 */

@interface MSIDCacheSchemaValidationTests : XCTestCase

@end

@implementation MSIDCacheSchemaValidationTests

#pragma mark - MSSTS + AAD account

- (MSIDTokenResponse *)aadTestTokenResponse
{
    NSString *jsonResponse = @"{\"token_type\":\"Bearer\",\"scope\":\"Calendars.Read openid profile Tasks.Read User.Read email\",\"expires_in\":3600,\"ext_expires_in\":262800,\"access_token\":\"<removed_at>\",\"refresh_token\":\"<removed_rt>\",\"id_token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJiNmM2OWEzNy1kZjk2LTRkYjAtOTA4OC0yYWI5NmUxZDgyMTUiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhL3YyLjAiLCJpYXQiOjE1Mzg1Mzg0MjIsIm5iZiI6MTUzODUzODQyMiwiZXhwIjoxNTM4NTQyMzIyLCJuYW1lIjoiQ2xvdWQgSURMQUIgQmFzaWMgVXNlciIsIm9pZCI6IjlmNDg4MGQ4LTgwYmEtNGM0MC05N2JjLWY3YTIzYzcwMzA4NCIsInByZWZlcnJlZF91c2VybmFtZSI6ImlkbGFiQG1zaWRsYWI0Lm9ubWljcm9zb2Z0LmNvbSIsInN1YiI6Ilk2WWtCZEhOTkxITm1US2VsOUtoUno4d3Jhc3hkTFJGaVAxNEJSUFdybjQiLCJ0aWQiOiJmNjQ1YWQ5Mi1lMzhkLTRkMWEtYjUxMC1kMWIwOWE3NGE4Y2EiLCJ1dGkiOiI2bmNpWDAyU01raTlrNzMtRjFzWkFBIiwidmVyIjoiMi4wIn0.\",\"client_info\":\"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0\"}";

    NSError *responseError = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONData:[jsonResponse dataUsingEncoding:NSUTF8StringEncoding] error:&responseError];

    XCTAssertNotNil(response);
    XCTAssertNil(responseError);

    return response;
}

- (MSIDConfiguration *)aadTestConfiguration
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"msalb6c69a37-df96-4db0-9088-2ab96e1d8215://auth"
                                                                           clientId:@"b6c69a37-df96-4db0-9088-2ab96e1d8215"
                                                                             target:@"tasks.read user.read openid profile offline_access"];
    return configuration;
}

- (void)testSchemaComplianceForAccessToken_whenMSSTSResponse_withAADAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response
                                                      configuration:configuration];

    MSIDCredentialCacheItem *credential = accessToken.tokenCacheItem;
    NSDictionary *accessTokenJSON = credential.jsonDictionary;

    NSDate *currentDate = [NSDate new];
    NSString *expiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 3600)];
    NSString *extExpiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 262800)];
    NSString *cachedAt = [NSString stringWithFormat:@"%ld", (long)[currentDate timeIntervalSince1970]];

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"<removed_at>",
                                   @"target": @"Calendars.Read openid profile Tasks.Read User.Read email",
                                   @"extended_expires_on": extExpiresOn,
                                   @"credential_type": @"AccessToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"expires_on": expiresOn,
                                   @"cached_at": cachedAt,
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
                                   };

    XCTAssertEqualObjects(accessTokenJSON, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca-calendars.read openid profile tasks.read user.read email";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testSchemaComplianceForIDToken_whenMSSTSResponse_withAADAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = idToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJiNmM2OWEzNy1kZjk2LTRkYjAtOTA4OC0yYWI5NmUxZDgyMTUiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhL3YyLjAiLCJpYXQiOjE1Mzg1Mzg0MjIsIm5iZiI6MTUzODUzODQyMiwiZXhwIjoxNTM4NTQyMzIyLCJuYW1lIjoiQ2xvdWQgSURMQUIgQmFzaWMgVXNlciIsIm9pZCI6IjlmNDg4MGQ4LTgwYmEtNGM0MC05N2JjLWY3YTIzYzcwMzA4NCIsInByZWZlcnJlZF91c2VybmFtZSI6ImlkbGFiQG1zaWRsYWI0Lm9ubWljcm9zb2Z0LmNvbSIsInN1YiI6Ilk2WWtCZEhOTkxITm1US2VsOUtoUno4d3Jhc3hkTFJGaVAxNEJSUFdybjQiLCJ0aWQiOiJmNjQ1YWQ5Mi1lMzhkLTRkMWEtYjUxMC1kMWIwOWE3NGE4Y2EiLCJ1dGkiOiI2bmNpWDAyU01raTlrNzMtRjFzWkFBIiwidmVyIjoiMi4wIn0.",
                                   @"credential_type": @"IdToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca-";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2003);
}

- (void)testSchemaComplianceForRefreshToken_whenMSSTSResponse_withAADAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForAccount_whenMSSTSResponse_withAADAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDAccountCacheItem *accountCacheItem = account.accountCacheItem;

    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
                                   @"local_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"username": @"idlab@msidlab4.onmicrosoft.com",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"authority_type": @"MSSTS",
                                   @"name": @"Cloud IDLAB Basic User",
                                   @"client_info": @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"
                                   };

    XCTAssertEqualObjects(accountCacheItem.jsonDictionary, expectedJSON);

    // 2. Verify cache key

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountCacheItem.homeAccountId
                                                                                    environment:accountCacheItem.environment
                                                                                          realm:accountCacheItem.realm
                                                                                           type:accountCacheItem.accountType];

    key.username = account.username;

    NSString *expectedServiceKey = @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"idlab@msidlab4.onmicrosoft.com";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @1003);
}

#pragma mark - MSA account

- (MSIDTokenResponse *)msaTestTokenResponse
{
    NSString *jsonResponse = @"{\"token_type\":\"Bearer\",\"scope\":\"Tasks.Read User.Read openid profile\",\"expires_in\":3600,\"ext_expires_in\":0,\"access_token\":\"<removed_at>\",\"refresh_token\":\"<removed_rt>\",\"id_token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXIiOiIyLjAiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vOTE4ODA0MGQtNmM2Ny00YzViLWIxMTItMzZhMzA0YjY2ZGFkL3YyLjAiLCJzdWIiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFNTmVBRnBTTGdsSGlPVHI5SVpISkVBIiwiYXVkIjoiYjZjNjlhMzctZGY5Ni00ZGIwLTkwODgtMmFiOTZlMWQ4MjE1IiwiZXhwIjoxNTM4ODg1MjU0LCJpYXQiOjE1Mzg3OTg1NTQsIm5iZiI6MTUzODc5ODU1NCwibmFtZSI6IlRlc3QgVXNlcm5hbWUiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJtc2Fsc2RrdGVzdEBvdXRsb29rLmNvbSIsIm9pZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInRpZCI6IjkxODgwNDBkLTZjNjctNGM1Yi1iMTEyLTM2YTMwNGI2NmRhZCIsImFpbyI6IkRXZ0tubCFFc2ZWa1NVOGpGVmJ4TTZQaFphUjJFeVhzTUJ5bVJHU1h2UkV1NGkqRm1CVTFSQmw1aEh2TnZvR1NHbHFkQkpGeG5kQXNBNipaM3FaQnIwYzl2YUlSd1VwZUlDVipTWFpqdzghQiIsImFsZyI6IkhTMjU2In0.\",\"client_info\":\"eyJ2ZXIiOiIxLjAiLCJzdWIiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFNTmVBRnBTTGdsSGlPVHI5SVpISkVBIiwibmFtZSI6Ik9sZ2EgRGFsdG9tIiwicHJlZmVycmVkX3VzZXJuYW1lIjoibXNhbHNka3Rlc3RAb3V0bG9vay5jb20iLCJvaWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtNDBjMC0zYmFjMTg4ZDAxZDEiLCJ0aWQiOiI5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJob21lX29pZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInVpZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInV0aWQiOiI5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQifQ\"}";

    NSError *responseError = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONData:[jsonResponse dataUsingEncoding:NSUTF8StringEncoding] error:&responseError];

    XCTAssertNotNil(response);
    XCTAssertNil(responseError);

    return response;
}

- (void)testSchemaComplianceForAccessToken_whenMSSTSResponse_withMSAAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self msaTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response
                                                      configuration:configuration];

    MSIDCredentialCacheItem *credential = accessToken.tokenCacheItem;
    NSDictionary *accessTokenJSON = credential.jsonDictionary;

    NSDate *currentDate = [NSDate new];
    NSString *expiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 3600)];
    NSString *cachedAt = [NSString stringWithFormat:@"%ld", (long)[currentDate timeIntervalSince1970]];

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"<removed_at>",
                                   @"target": @"Tasks.Read User.Read openid profile",
                                   @"credential_type": @"AccessToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"9188040d-6c67-4c5b-b112-36a304b66dad",
                                   @"expires_on": expiresOn,
                                   @"cached_at": cachedAt,
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"home_account_id": @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad"
                                   };

    XCTAssertEqualObjects(accessTokenJSON, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-9188040d-6c67-4c5b-b112-36a304b66dad-tasks.read user.read openid profile";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-9188040d-6c67-4c5b-b112-36a304b66dad";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testSchemaComplianceForIDToken_whenMSSTSResponse_withMSAAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self msaTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = idToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXIiOiIyLjAiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vOTE4ODA0MGQtNmM2Ny00YzViLWIxMTItMzZhMzA0YjY2ZGFkL3YyLjAiLCJzdWIiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFNTmVBRnBTTGdsSGlPVHI5SVpISkVBIiwiYXVkIjoiYjZjNjlhMzctZGY5Ni00ZGIwLTkwODgtMmFiOTZlMWQ4MjE1IiwiZXhwIjoxNTM4ODg1MjU0LCJpYXQiOjE1Mzg3OTg1NTQsIm5iZiI6MTUzODc5ODU1NCwibmFtZSI6IlRlc3QgVXNlcm5hbWUiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJtc2Fsc2RrdGVzdEBvdXRsb29rLmNvbSIsIm9pZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInRpZCI6IjkxODgwNDBkLTZjNjctNGM1Yi1iMTEyLTM2YTMwNGI2NmRhZCIsImFpbyI6IkRXZ0tubCFFc2ZWa1NVOGpGVmJ4TTZQaFphUjJFeVhzTUJ5bVJHU1h2UkV1NGkqRm1CVTFSQmw1aEh2TnZvR1NHbHFkQkpGeG5kQXNBNipaM3FaQnIwYzl2YUlSd1VwZUlDVipTWFpqdzghQiIsImFsZyI6IkhTMjU2In0.",
                                   @"credential_type": @"IdToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"home_account_id": @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad",
                                   @"realm": @"9188040d-6c67-4c5b-b112-36a304b66dad",
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-9188040d-6c67-4c5b-b112-36a304b66dad-";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-9188040d-6c67-4c5b-b112-36a304b66dad";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2003);
}

- (void)testSchemaComplianceForRefreshToken_whenMSSTSResponse_withMSAAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self msaTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForAccount_whenMSSTSResponse_withMSAAccount
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self msaTestTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDAccountCacheItem *accountCacheItem = account.accountCacheItem;

    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
        @"local_account_id": @"00000000-0000-0000-40c0-3bac188d01d1",
        @"home_account_id": @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad",
        @"username": @"msalsdktest@outlook.com",
        @"environment": @"login.microsoftonline.com",
        @"realm": @"9188040d-6c67-4c5b-b112-36a304b66dad",
        @"authority_type": @"MSSTS",
        @"name": @"Test Username",
        @"client_info": @"eyJ2ZXIiOiIxLjAiLCJzdWIiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFNTmVBRnBTTGdsSGlPVHI5SVpISkVBIiwibmFtZSI6Ik9sZ2EgRGFsdG9tIiwicHJlZmVycmVkX3VzZXJuYW1lIjoibXNhbHNka3Rlc3RAb3V0bG9vay5jb20iLCJvaWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtNDBjMC0zYmFjMTg4ZDAxZDEiLCJ0aWQiOiI5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJob21lX29pZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInVpZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC00MGMwLTNiYWMxODhkMDFkMSIsInV0aWQiOiI5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQifQ"
    };

    XCTAssertEqualObjects(accountCacheItem.jsonDictionary, expectedJSON);

    // 2. Verify cache key

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountCacheItem.homeAccountId
                                                                                    environment:accountCacheItem.environment
                                                                                          realm:accountCacheItem.realm
                                                                                           type:accountCacheItem.accountType];

    key.username = account.username;

    NSString *expectedServiceKey = @"9188040d-6c67-4c5b-b112-36a304b66dad";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"00000000-0000-0000-40c0-3bac188d01d1.9188040d-6c67-4c5b-b112-36a304b66dad-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"msalsdktest@outlook.com";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @1003);
}

#pragma mark - B2C account without tenantId (old conf)

- (MSIDTokenResponse *)b2cTestTokenResponse
{
    NSString *jsonResponse = @"{\"access_token\":\"<removed_at>\",\"id_token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1Mzg4MDQ4NjAsIm5iZiI6MTUzODgwMTI2MCwidmVyIjoiMS4wIiwiaXNzIjoiaHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2JhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOC92Mi4wLyIsInN1YiI6ImFkMDIwZjhlLWIxYmEtNDRiMi1iZDY5LWMyMmJlODY3MzdmNSIsImF1ZCI6IjBhN2Y1MmRkLTI2MGUtNDMyZi05NGRlLWI0NzgyOGMzZjM3MiIsImlhdCI6MTUzODgwMTI2MCwiYXV0aF90aW1lIjoxNTM4ODAxMjYwLCJpZHAiOiJsaXZlLmNvbSIsIm5hbWUiOiJNU0FMIFNESyBUZXN0Iiwib2lkIjoiYWQwMjBmOGUtYjFiYS00NGIyLWJkNjktYzIyYmU4NjczN2Y1IiwiZmFtaWx5X25hbWUiOiJTREsgVGVzdCIsImdpdmVuX25hbWUiOiJNU0FMIiwiZW1haWxzIjpbIm1zYWxzZGt0ZXN0QG91dGxvb2suY29tIl0sInRmcCI6IkIyQ18xX1NpZ25pbiIsImF0X2hhc2giOiJRNE8zSERDbGNhTGw3eTB1VS1iSkFnIn0.\",\"token_type\":\"Bearer\",\"not_before\":1538801260,\"expires_in\":3600,\"expires_on\":1538804860,\"resource\":\"14df2240-96cc-4f42-a133-ef0807492869\",\"client_info\":\"eyJ1aWQiOiJhZDAyMGY4ZS1iMWJhLTQ0YjItYmQ2OS1jMjJiZTg2NzM3ZjUtYjJjXzFfc2lnbmluIiwidXRpZCI6ImJhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOCJ9\",\"scope\":\"https://iosmsalb2c.onmicrosoft.com/webapitest/user.read\",\"refresh_token\":\"<removed_rt>\",\"refresh_token_expires_in\":1209600}";

    NSError *responseError = nil;
    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONData:[jsonResponse dataUsingEncoding:NSUTF8StringEncoding] error:&responseError];

    XCTAssertNotNil(response);
    XCTAssertNil(responseError);

    return response;
}

- (MSIDConfiguration *)b2cTestConfiguration
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/tfp/iosmsalb2c.onmicrosoft.com/b2c_1_signin" b2cAuthority];

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"msal0a7f52dd-260e-432f-94de-b47828c3f372://auth"
                                                                           clientId:@"0a7f52dd-260e-432f-94de-b47828c3f372"
                                                                             target:@"https://iosmsalb2c.onmicrosoft.com/webapitest/user.read"];
    return configuration;
}

- (void)testSchemaComplianceForAccessToken_whenMSSTSResponse_withB2CAccount
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponse];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response
                                                      configuration:configuration];

    MSIDCredentialCacheItem *credential = accessToken.tokenCacheItem;
    NSDictionary *accessTokenJSON = credential.jsonDictionary;

    NSDate *currentDate = [NSDate new];
    NSString *expiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 3600)];
    NSString *cachedAt = [NSString stringWithFormat:@"%ld", (long)[currentDate timeIntervalSince1970]];

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
        @"secret": @"<removed_at>",
        @"target": @"https://iosmsalb2c.onmicrosoft.com/webapitest/user.read",
        @"credential_type": @"AccessToken",
        @"environment": @"login.microsoftonline.com",
        @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
        @"expires_on": expiresOn,
        @"cached_at": cachedAt,
        @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372",
        @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8"
    };

    XCTAssertEqualObjects(accessTokenJSON, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"accesstoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-https://iosmsalb2c.onmicrosoft.com/webapitest/user.read";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"accesstoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testSchemaComplianceForIDToken_whenMSSTSResponse_withB2CAccount
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponse];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = idToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
        @"secret": @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1Mzg4MDQ4NjAsIm5iZiI6MTUzODgwMTI2MCwidmVyIjoiMS4wIiwiaXNzIjoiaHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2JhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOC92Mi4wLyIsInN1YiI6ImFkMDIwZjhlLWIxYmEtNDRiMi1iZDY5LWMyMmJlODY3MzdmNSIsImF1ZCI6IjBhN2Y1MmRkLTI2MGUtNDMyZi05NGRlLWI0NzgyOGMzZjM3MiIsImlhdCI6MTUzODgwMTI2MCwiYXV0aF90aW1lIjoxNTM4ODAxMjYwLCJpZHAiOiJsaXZlLmNvbSIsIm5hbWUiOiJNU0FMIFNESyBUZXN0Iiwib2lkIjoiYWQwMjBmOGUtYjFiYS00NGIyLWJkNjktYzIyYmU4NjczN2Y1IiwiZmFtaWx5X25hbWUiOiJTREsgVGVzdCIsImdpdmVuX25hbWUiOiJNU0FMIiwiZW1haWxzIjpbIm1zYWxzZGt0ZXN0QG91dGxvb2suY29tIl0sInRmcCI6IkIyQ18xX1NpZ25pbiIsImF0X2hhc2giOiJRNE8zSERDbGNhTGw3eTB1VS1iSkFnIn0.",
        @"credential_type": @"IdToken",
        @"environment": @"login.microsoftonline.com",
        @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
        @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
        @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372"
    };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"idtoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"idtoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2003);
}

- (void)testSchemaComplianceForRefreshToken_whenMSSTSResponse_withB2CAccount
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponse];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"refreshtoken-0a7f52dd-260e-432f-94de-b47828c3f372--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"refreshtoken-0a7f52dd-260e-432f-94de-b47828c3f372-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForAccount_whenMSSTSResponse_withB2CAccount
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponse];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDAccountCacheItem *accountCacheItem = account.accountCacheItem;

    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
                                   @"family_name": @"SDK Test",
                                   @"local_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"username": @"Missing from the token response",
                                   @"authority_type": @"MSSTS",
                                   @"given_name": @"MSAL",
                                   @"environment": @"login.microsoftonline.com",
                                   @"name": @"MSAL SDK Test",
                                   @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"client_info": @"eyJ1aWQiOiJhZDAyMGY4ZS1iMWJhLTQ0YjItYmQ2OS1jMjJiZTg2NzM3ZjUtYjJjXzFfc2lnbmluIiwidXRpZCI6ImJhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOCJ9"
                                   };

    XCTAssertEqualObjects(accountCacheItem.jsonDictionary, expectedJSON);

    // 2. Verify cache key

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountCacheItem.homeAccountId
                                                                                    environment:accountCacheItem.environment
                                                                                          realm:accountCacheItem.realm
                                                                                           type:accountCacheItem.accountType];

    key.username = account.username;

    NSString *expectedServiceKey = @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"missing from the token response";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @1003);
}

#pragma mark - B2C account with tenantId (new conf)

- (MSIDTokenResponse *)b2cTestTokenResponseWithTenantId
{
    NSString *jsonResponse = @"{\"access_token\":\"<removed_at>\",\"id_token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1Mzg4MDQ4NjAsIm5iZiI6MTUzODgwMTI2MCwidmVyIjoiMS4wIiwiaXNzIjoiaHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2JhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOC92Mi4wLyIsInN1YiI6ImFkMDIwZjhlLWIxYmEtNDRiMi1iZDY5LWMyMmJlODY3MzdmNSIsImF1ZCI6IjBhN2Y1MmRkLTI2MGUtNDMyZi05NGRlLWI0NzgyOGMzZjM3MiIsImlhdCI6MTUzODgwMTI2MCwiYXV0aF90aW1lIjoxNTM4ODAxMjYwLCJpZHAiOiJsaXZlLmNvbSIsIm5hbWUiOiJNU0FMIFNESyBUZXN0Iiwib2lkIjoiYWQwMjBmOGUtYjFiYS00NGIyLWJkNjktYzIyYmU4NjczN2Y1IiwiZmFtaWx5X25hbWUiOiJTREsgVGVzdCIsImdpdmVuX25hbWUiOiJNU0FMIiwiZW1haWxzIjpbIm1zYWxzZGt0ZXN0QG91dGxvb2suY29tIl0sInRmcCI6IkIyQ18xX1NpZ25pbiIsImF0X2hhc2giOiJRNE8zSERDbGNhTGw3eTB1VS1iSkFnIiwidGlkIjoiYmE2YzBkOTQtYThkYS00NWIyLTgzYWUtMzM4NzFmOWMyZGQ4IiwicHJlZmVycmVkX3VzZXJuYW1lIjoibXNhbHNka3Rlc3RAb3V0bG9vay5jb20ifQ.\",\"token_type\":\"Bearer\",\"not_before\":1538801260,\"expires_in\":3600,\"expires_on\":1538804860,\"resource\":\"14df2240-96cc-4f42-a133-ef0807492869\",\"client_info\":\"eyJ1aWQiOiJhZDAyMGY4ZS1iMWJhLTQ0YjItYmQ2OS1jMjJiZTg2NzM3ZjUtYjJjXzFfc2lnbmluIiwidXRpZCI6ImJhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOCJ9\",\"scope\":\"https://iosmsalb2c.onmicrosoft.com/webapitest/user.read\",\"refresh_token\":\"<removed_rt>\",\"refresh_token_expires_in\":1209600}";

    NSError *responseError = nil;
    MSIDB2CTokenResponse *response = [[MSIDB2CTokenResponse alloc] initWithJSONData:[jsonResponse dataUsingEncoding:NSUTF8StringEncoding] error:&responseError];

    XCTAssertNotNil(response);
    XCTAssertNil(responseError);

    return response;
}

- (void)testSchemaComplianceForAccessToken_whenMSSTSResponse_withB2CAccountAndTenantId
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponseWithTenantId];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response
                                                      configuration:configuration];

    MSIDCredentialCacheItem *credential = accessToken.tokenCacheItem;
    NSDictionary *accessTokenJSON = credential.jsonDictionary;

    NSDate *currentDate = [NSDate new];
    NSString *expiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 3600)];
    NSString *cachedAt = [NSString stringWithFormat:@"%ld", (long)[currentDate timeIntervalSince1970]];

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"<removed_at>",
                                   @"target": @"https://iosmsalb2c.onmicrosoft.com/webapitest/user.read",
                                   @"credential_type": @"AccessToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"expires_on": expiresOn,
                                   @"cached_at": cachedAt,
                                   @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8"
                                   };

    XCTAssertEqualObjects(accessTokenJSON, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"accesstoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-https://iosmsalb2c.onmicrosoft.com/webapitest/user.read";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"accesstoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testSchemaComplianceForIDToken_whenMSSTSResponse_withB2CAccountAndTenantId
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponseWithTenantId];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = idToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1Mzg4MDQ4NjAsIm5iZiI6MTUzODgwMTI2MCwidmVyIjoiMS4wIiwiaXNzIjoiaHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2JhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOC92Mi4wLyIsInN1YiI6ImFkMDIwZjhlLWIxYmEtNDRiMi1iZDY5LWMyMmJlODY3MzdmNSIsImF1ZCI6IjBhN2Y1MmRkLTI2MGUtNDMyZi05NGRlLWI0NzgyOGMzZjM3MiIsImlhdCI6MTUzODgwMTI2MCwiYXV0aF90aW1lIjoxNTM4ODAxMjYwLCJpZHAiOiJsaXZlLmNvbSIsIm5hbWUiOiJNU0FMIFNESyBUZXN0Iiwib2lkIjoiYWQwMjBmOGUtYjFiYS00NGIyLWJkNjktYzIyYmU4NjczN2Y1IiwiZmFtaWx5X25hbWUiOiJTREsgVGVzdCIsImdpdmVuX25hbWUiOiJNU0FMIiwiZW1haWxzIjpbIm1zYWxzZGt0ZXN0QG91dGxvb2suY29tIl0sInRmcCI6IkIyQ18xX1NpZ25pbiIsImF0X2hhc2giOiJRNE8zSERDbGNhTGw3eTB1VS1iSkFnIiwidGlkIjoiYmE2YzBkOTQtYThkYS00NWIyLTgzYWUtMzM4NzFmOWMyZGQ4IiwicHJlZmVycmVkX3VzZXJuYW1lIjoibXNhbHNka3Rlc3RAb3V0bG9vay5jb20ifQ.",
                                   @"credential_type": @"IdToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"idtoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"idtoken-0a7f52dd-260e-432f-94de-b47828c3f372-ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2003);
}

- (void)testSchemaComplianceForRefreshToken_whenMSSTSResponse_withB2CAccountAndTenantId
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponseWithTenantId];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;

    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"0a7f52dd-260e-432f-94de-b47828c3f372",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8"
                                   };

    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);

    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    NSString *expectedServiceKey = @"refreshtoken-0a7f52dd-260e-432f-94de-b47828c3f372--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"refreshtoken-0a7f52dd-260e-432f-94de-b47828c3f372-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForAccount_whenMSSTSResponse_withB2CAccountAndTenantId
{
    MSIDB2COauth2Factory *factory = [MSIDB2COauth2Factory new];
    MSIDTokenResponse *response = [self b2cTestTokenResponseWithTenantId];
    MSIDConfiguration *configuration = [self b2cTestConfiguration];

    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDAccountCacheItem *accountCacheItem = account.accountCacheItem;

    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
                                   @"family_name": @"SDK Test",
                                   @"local_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5",
                                   @"home_account_id": @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"username": @"msalsdktest@outlook.com",
                                   @"authority_type": @"MSSTS",
                                   @"given_name": @"MSAL",
                                   @"environment": @"login.microsoftonline.com",
                                   @"name": @"MSAL SDK Test",
                                   @"realm": @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8",
                                   @"client_info": @"eyJ1aWQiOiJhZDAyMGY4ZS1iMWJhLTQ0YjItYmQ2OS1jMjJiZTg2NzM3ZjUtYjJjXzFfc2lnbmluIiwidXRpZCI6ImJhNmMwZDk0LWE4ZGEtNDViMi04M2FlLTMzODcxZjljMmRkOCJ9"
                                   };

    XCTAssertEqualObjects(accountCacheItem.jsonDictionary, expectedJSON);

    // 2. Verify cache key

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountCacheItem.homeAccountId
                                                                                    environment:accountCacheItem.environment
                                                                                          realm:accountCacheItem.realm
                                                                                           type:accountCacheItem.accountType];

    key.username = account.username;

    NSString *expectedServiceKey = @"ba6c0d94-a8da-45b2-83ae-33871f9c2dd8";
    XCTAssertEqualObjects(key.service, expectedServiceKey);

    NSString *expectedAccountKey = @"ad020f8e-b1ba-44b2-bd69-c22be86737f5-b2c_1_signin.ba6c0d94-a8da-45b2-83ae-33871f9c2dd8-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);

    NSString *expectedGenericKey = @"msalsdktest@outlook.com";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);

    XCTAssertEqualObjects(key.type, @1003);
}

#pragma mark - MSSTS + AAD account + FOCI Client

- (MSIDTokenResponse *)aadTestFociTokenResponse
{
    NSString *jsonResponse = @"{\"token_type\":\"Bearer\",\"scope\":\"Calendars.Read openid profile Tasks.Read User.Read email\",\"expires_in\":3600,\"ext_expires_in\":262800,\"access_token\":\"<removed_at>\",\"refresh_token\":\"<removed_rt>\",\"id_token\":\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJiNmM2OWEzNy1kZjk2LTRkYjAtOTA4OC0yYWI5NmUxZDgyMTUiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhL3YyLjAiLCJpYXQiOjE1Mzg1Mzg0MjIsIm5iZiI6MTUzODUzODQyMiwiZXhwIjoxNTM4NTQyMzIyLCJuYW1lIjoiQ2xvdWQgSURMQUIgQmFzaWMgVXNlciIsIm9pZCI6IjlmNDg4MGQ4LTgwYmEtNGM0MC05N2JjLWY3YTIzYzcwMzA4NCIsInByZWZlcnJlZF91c2VybmFtZSI6ImlkbGFiQG1zaWRsYWI0Lm9ubWljcm9zb2Z0LmNvbSIsInN1YiI6Ilk2WWtCZEhOTkxITm1US2VsOUtoUno4d3Jhc3hkTFJGaVAxNEJSUFdybjQiLCJ0aWQiOiJmNjQ1YWQ5Mi1lMzhkLTRkMWEtYjUxMC1kMWIwOWE3NGE4Y2EiLCJ1dGkiOiI2bmNpWDAyU01raTlrNzMtRjFzWkFBIiwidmVyIjoiMi4wIn0.\",\"client_info\":\"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0\",\"foci\":\"1\"}";
    
    NSError *responseError = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONData:[jsonResponse dataUsingEncoding:NSUTF8StringEncoding] error:&responseError];
    
    XCTAssertNotNil(response);
    XCTAssertEqualObjects(response.familyId, @"1");
    XCTAssertNil(responseError);
    
    return response;
}

- (void)testSchemaComplianceForAccessToken_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response
                                                      configuration:configuration];
    
    MSIDCredentialCacheItem *credential = accessToken.tokenCacheItem;
    NSDictionary *accessTokenJSON = credential.jsonDictionary;
    
    NSDate *currentDate = [NSDate new];
    NSString *expiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 3600)];
    NSString *extExpiresOn = [NSString stringWithFormat:@"%ld", (long)([currentDate timeIntervalSince1970] + 262800)];
    NSString *cachedAt = [NSString stringWithFormat:@"%ld", (long)[currentDate timeIntervalSince1970]];
    
    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"<removed_at>",
                                   @"target": @"Calendars.Read openid profile Tasks.Read User.Read email",
                                   @"extended_expires_on": extExpiresOn,
                                   @"credential_type": @"AccessToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"expires_on": expiresOn,
                                   @"cached_at": cachedAt,
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
                                   };
    
    XCTAssertEqualObjects(accessTokenJSON, expectedJSON);
    
    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;
    
    NSString *expectedServiceKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca-calendars.read openid profile tasks.read user.read email";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"accesstoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testSchemaComplianceForIDToken_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDIdToken *idToken = [factory idTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = idToken.tokenCacheItem;
    
    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"secret": @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJiNmM2OWEzNy1kZjk2LTRkYjAtOTA4OC0yYWI5NmUxZDgyMTUiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhL3YyLjAiLCJpYXQiOjE1Mzg1Mzg0MjIsIm5iZiI6MTUzODUzODQyMiwiZXhwIjoxNTM4NTQyMzIyLCJuYW1lIjoiQ2xvdWQgSURMQUIgQmFzaWMgVXNlciIsIm9pZCI6IjlmNDg4MGQ4LTgwYmEtNGM0MC05N2JjLWY3YTIzYzcwMzA4NCIsInByZWZlcnJlZF91c2VybmFtZSI6ImlkbGFiQG1zaWRsYWI0Lm9ubWljcm9zb2Z0LmNvbSIsInN1YiI6Ilk2WWtCZEhOTkxITm1US2VsOUtoUno4d3Jhc3hkTFJGaVAxNEJSUFdybjQiLCJ0aWQiOiJmNjQ1YWQ5Mi1lMzhkLTRkMWEtYjUxMC1kMWIwOWE3NGE4Y2EiLCJ1dGkiOiI2bmNpWDAyU01raTlrNzMtRjFzWkFBIiwidmVyIjoiMi4wIn0.",
                                   @"credential_type": @"IdToken",
                                   @"environment": @"login.microsoftonline.com",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215"
                                   };
    
    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);
    
    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;
    
    NSString *expectedServiceKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca-";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"idtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @2003);
}

- (void)testSchemaComplianceForRefreshToken_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    refreshToken.familyId = nil;
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;
    
    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
                                   };
    
    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);
    
    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;
    
    NSString *expectedServiceKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"refreshtoken-b6c69a37-df96-4db0-9088-2ab96e1d8215-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForFamilyRefreshToken_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDRefreshToken *refreshToken = [factory refreshTokenFromResponse:response configuration:configuration];
    MSIDCredentialCacheItem *credential = refreshToken.tokenCacheItem;
    
    // 1. Verify payload
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"secret": @"<removed_rt>",
                                   @"environment": @"login.microsoftonline.com",
                                   @"credential_type": @"RefreshToken",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"family_id":@"1"
                                   };
    
    XCTAssertEqualObjects(credential.jsonDictionary, expectedJSON);
    
    // 2. Verify cache key
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;
    
    NSString *expectedServiceKey = @"refreshtoken-1--";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"refreshtoken-1-";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testSchemaComplianceForAccount_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDAccountCacheItem *accountCacheItem = account.accountCacheItem;
    
    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
                                   @"local_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084",
                                   @"home_account_id": @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"username": @"idlab@msidlab4.onmicrosoft.com",
                                   @"environment": @"login.microsoftonline.com",
                                   @"realm": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                   @"authority_type": @"MSSTS",
                                   @"name": @"Cloud IDLAB Basic User",
                                   @"client_info": @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"
                                   };
    
    XCTAssertEqualObjects(accountCacheItem.jsonDictionary, expectedJSON);
    
    // 2. Verify cache key
    
    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:accountCacheItem.homeAccountId
                                                                                    environment:accountCacheItem.environment
                                                                                          realm:accountCacheItem.realm
                                                                                           type:accountCacheItem.accountType];
    
    key.username = account.username;
    
    NSString *expectedServiceKey = @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca-login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"idlab@msidlab4.onmicrosoft.com";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @1003);
}

- (void)testSchemaComplianceForAppMetadata_whenMSSTSResponse_withAADAccountAndFociClient
{
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [self aadTestFociTokenResponse];
    MSIDConfiguration *configuration = [self aadTestConfiguration];
    
    MSIDAppMetadataCacheItem *appMetadata = [factory appMetadataFromResponse:response configuration:configuration];
    
    // 1. Verify payload compliance
    NSDictionary *expectedJSON = @{
                                   @"client_id": @"b6c69a37-df96-4db0-9088-2ab96e1d8215",
                                   @"environment": @"login.microsoftonline.com",
                                   @"family_id": @"1"
                                   };
    
    XCTAssertEqualObjects(appMetadata.jsonDictionary, expectedJSON);
    
    // 2. Verify cache key
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata.clientId
                                                                         environment:appMetadata.environment
                                                                            familyId:appMetadata.familyId
                                                                         generalType:MSIDAppMetadataType];
    
    NSString *expectedServiceKey = @"appmetadata-b6c69a37-df96-4db0-9088-2ab96e1d8215";
    XCTAssertEqualObjects(key.service, expectedServiceKey);
    
    NSString *expectedAccountKey = @"login.microsoftonline.com";
    XCTAssertEqualObjects(key.account, expectedAccountKey);
    
    NSString *expectedGenericKey = @"1";
    XCTAssertEqualObjects(key.generic, [expectedGenericKey dataUsingEncoding:NSUTF8StringEncoding]);
    
    XCTAssertEqualObjects(key.type, @3001);
}
@end
