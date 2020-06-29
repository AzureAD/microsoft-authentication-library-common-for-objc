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
#import "MSIDTestBrokerResponseHelper.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestBrokerKeyProviderHelper.h"
#import "MSIDLegacyBrokerResponseHandler.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDLegacyTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyAccessToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDTestCacheAccessorHelper.h"

@interface MSIDLegacyBrokerResponseHandlerTests : XCTestCase

@property (nonatomic) id<MSIDCacheAccessor> cacheAccessor;

@end

@implementation MSIDLegacyBrokerResponseHandlerTests

- (void)setUp
{
    [super setUp];
    [MSIDTestBrokerKeyProviderHelper addKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"] accessGroup:@"com.microsoft.adalcache" applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    id<MSIDExtendedTokenCacheDataSource> dataSource = [MSIDKeychainTokenCache defaultKeychainCache];
    [dataSource clearWithContext:nil error:nil];
    MSIDDefaultTokenCacheAccessor *otherAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.cacheAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor]];
}

- (void)tearDown
{
    // Clear keychain
    NSDictionary *query = @{(id)kSecClass : (id)kSecClassKey,
                            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric};

    SecItemDelete((CFDictionaryRef)query);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    
    [super tearDown];
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNonNil_andBrokerNonceMatches_shouldReturnResultAndNilError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];

    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"foci": @"1",
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);

    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(result.tokenResponse.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(result.rawIdToken, idToken);
    XCTAssertEqualObjects(result.accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(result.account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(result.accessToken.realm, @"common");
    XCTAssertEqualObjects(result.accessToken.resource, @"https://graph.windows.net");
    XCTAssertFalse(result.accessToken.isExpired);
    XCTAssertEqualObjects(result.correlationId.UUIDString, correlationId);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"common");

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 2);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNonNil_andNonceMissingInResponse_shouldReturnResultAndNilError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];
    
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"foci": @"1"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNil_andBrokerNonceMatches_shouldReturnResultAndNilError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];
    
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"foci": @"1",
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNil_andNonceMissingInResponse_shouldReturnResumeStateError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];
    
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"foci": @"1"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Broker nonce mismatch!");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNil_andNonceMismatch_shouldReturnResumeStateError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];
    
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"foci": @"1",
      @"broker_nonce" : @"incorrect_nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Broker nonce mismatch!");
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNonNil_andBrokerNonceMatches_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSDictionary *brokerResponseParams =
    @{
      @"protocol_code": @"invalid_grant",
      @"error_domain": @"ADAuthenticationErrorDomain",
      @"error_code": @"213",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"suberror": @"consent_required",
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
    XCTAssertEqualObjects(error.domain, @"ADAuthenticationErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"consent_required");
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Error occured");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertNil(error.userInfo[MSIDUserDisplayableIdkey]);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNonNil_andNonceMissingInResponse_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"protocol_code": @"invalid_grant",
      @"error_domain": @"ADAuthenticationErrorDomain",
      @"error_code": @"213",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"suberror": @"consent_required"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNil_andBrokerNonceMatches_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"protocol_code": @"invalid_grant",
      @"error_domain": @"ADAuthenticationErrorDomain",
      @"error_code": @"213",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"suberror": @"consent_required",
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNil_andNonceMissingInResponse_shouldReturnResumeStateError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"protocol_code": @"invalid_grant",
      @"error_domain": @"ADAuthenticationErrorDomain",
      @"error_code": @"213",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"suberror": @"consent_required",
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Broker nonce mismatch!");
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNil_andNonceMismatch_shouldReturnResumeStateError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *brokerResponseParams =
    @{
      @"protocol_code": @"invalid_grant",
      @"error_domain": @"ADAuthenticationErrorDomain",
      @"error_code": @"213",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"suberror": @"consent_required",
      @"broker_nonce" : @"incorrect_nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];
    
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Broker nonce mismatch!");
}

- (void)testHandleBrokerResponse_whenBrokerIntuneErrorResponse_withNoAdditionalToken_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSDictionary *brokerResponseParams =
    @{
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_code" : @"213", // AD_ERROR_SERVER_PROTECTION_POLICY_REQUIRED
      @"error_description" : @"AADSTS53005: Application needs to enforce intune protection policies",
      @"protocol_code" : @"unauthorized_client",
      @"suberror" : @"protection_policies_required",
      @"user_id": @"user@contoso.com",
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"unauthorized_client");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"protection_policies_required");
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"AADSTS53005: Application needs to enforce intune protection policies");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDUserDisplayableIdkey], @"user@contoso.com");
}

- (void)testHandleBrokerResponse_whenBrokerIntuneErrorResponse_withAdditionalToken_shouldReturnNilResultAndError_andCacheMAMToken
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];

    NSDictionary *intuneMAMTokenDictionary = @{@"authority":@"https://login.microsoftonline.de/common",
                                               @"client_id": @"my_client_id",
                                               @"resource": @"intune_resource",
                                               @"user_id": @"user@contoso.com",
                                               @"correlation_id": correlationId,
                                               @"access_token": @"intune-mam-accesstoken",
                                               @"refresh_token": @"intune-mam-refreshtoken",
                                               @"expires_on": expiresOnString,
                                               @"id_token": idToken,
                                               @"x-broker-app-ver": @"1.0.0",
                                               @"vt": @"YES"
                                               };

    NSDictionary *encryptedIntuneMAMToken = [MSIDTestBrokerResponseHelper createLegacyBrokerResponseDictionary:intuneMAMTokenDictionary encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];

    NSDictionary *brokerResponseParams =
    @{
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_code" : @"213", // AD_ERROR_SERVER_PROTECTION_POLICY_REQUIRED
      @"error_description" : @"AADSTS53005: Application needs to enforce intune protection policies",
      @"protocol_code" : @"unauthorized_client",
      @"suberror" : @"protection_policies_required",
      @"intune_mam_token": encryptedIntuneMAMToken[@"response"],
      @"intune_mam_token_hash": encryptedIntuneMAMToken[@"hash"],
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"unauthorized_client");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"protection_policies_required");
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"AADSTS53005: Application needs to enforce intune protection policies");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDUserDisplayableIdkey], @"user@contoso.com");

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"intune-mam-accesstoken");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.de");
    XCTAssertEqualObjects(accessToken.realm, @"common");

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"intune-mam-refreshtoken");
    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.de");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

- (void)testHandleBrokerResponse_whenBrokerErrorResponseWithHttpHeaders_shouldReturnNilResultAndErrorWithHeaders
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSDictionary *brokerResponseParams =
    @{
      @"error_domain": @"NSURLErrorDomain",
      @"error_code": @"429",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"error_description": @"Error occured",
      @"http_headers": @"Content-Type=application%2Fjson%3B+charset%3Dutf-8&P3P=CP%3D%22DSP+CUR+OTPi+IND+OTRi+ONL+FIN%22&Access-Control-Allow-Origin=%2A&x-ms-request-id=1739e4e0-4b6e-4aba-b404-4979a0d41c00&Cache-Control=private&Date=Sat%2C+17+Nov+2018+23%3A20%3A03+GMT&Strict-Transport-Security=max-age%3D31536000%3B+includeSubDomains&client-request-id=14202594-2dfc-4ee8-a908-d337ca2b266b&Content-Length=975&X-Content-Type-Options=nosniff",
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerErrorResponse:brokerResponseParams
                                                                                 redirectUri:@"x-msauth-test://com.microsoft.testapp"];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 429);
    XCTAssertEqualObjects(error.domain, @"NSURLErrorDomain");
    XCTAssertNil(error.userInfo[MSIDOAuthErrorKey]);
    XCTAssertNil(error.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Error occured");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertNil(error.userInfo[MSIDUserDisplayableIdkey]);

    NSDictionary *expectedHeaders = @{
                                      @"Access-Control-Allow-Origin" : @"*",
                                      @"Cache-Control" : @"private",
                                      @"Content-Length" : @"975",
                                      @"Content-Type" : @"application/json; charset=utf-8",
                                      @"Date" : @"Sat, 17 Nov 2018 23:20:03 GMT",
                                      @"P3P" : @"CP=\"DSP CUR OTPi IND OTRi ONL FIN\"",
                                      @"Strict-Transport-Security" : @"max-age=31536000; includeSubDomains",
                                      @"X-Content-Type-Options" : @"nosniff",
                                      @"client-request-id" : @"14202594-2dfc-4ee8-a908-d337ca2b266b",
                                      @"x-ms-request-id" : @"1739e4e0-4b6e-4aba-b404-4979a0d41c00"};

    XCTAssertEqualObjects(error.userInfo[MSIDHTTPHeadersKey], expectedHeaders);
}

- (void)testHandleBrokerResponse_whenValidBrokerResponseWithSovereignAuthority_shouldReturnResultWithSovereignAuthority
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Contoso" upn:@"user@contoso.com" oid:nil tenantId:@"contoso.com-guid"];

    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:3600] timeIntervalSince1970]];

    NSString *correlationId = [[NSUUID UUID] UUIDString];

    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.de/common",
      @"resource" : @"https://graph.windows.net",
      @"client_id" : @"my_client_id",
      @"id_token" : idToken,
      @"access_token" : @"i-am-a-access-token",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"user_id": @"user@contoso.com",
      @"correlation_id": correlationId,
      @"x-broker-app-ver": @"1.0.0",
      @"broker_nonce" : @"nonce"
      };

    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createLegacyBrokerResponse:brokerResponseParams
                                                                            redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                          encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];

    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];

    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);

    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(result.tokenResponse.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(result.rawIdToken, idToken);
    XCTAssertEqualObjects(result.accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(result.account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.accessToken.environment, @"login.microsoftonline.de");
    XCTAssertEqualObjects(result.accessToken.realm, @"common");
    XCTAssertEqualObjects(result.accessToken.resource, @"https://graph.windows.net");
    XCTAssertFalse(result.accessToken.isExpired);
    XCTAssertEqualObjects(result.correlationId.UUIDString, correlationId);

    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllLegacyAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);

    MSIDLegacyAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(accessToken.idToken, idToken);
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.de");
    XCTAssertEqualObjects(accessToken.realm, @"common");

    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllLegacyRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 1);

    MSIDLegacyRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(refreshToken.idToken, idToken);
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.de");
    XCTAssertEqualObjects(refreshToken.realm, @"common");
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs2AndRequestIntiatedByAdalAndHasCompletionBlock_shouldReturnYes
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_ADAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=2&response=someEncryptedResponse"];
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertTrue(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs2AndRequestIsNotIntiatedByAdalAndHasCompletionBlock_shouldReturnNo
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_MSAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=2&response=someEncryptedResponse"];
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertFalse(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs2AndNoResumeDictionaryAndNoCompletionBlock_shouldReturnNo
{
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=2&response=someEncryptedResponse"];
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:NO];
    
    XCTAssertFalse(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs2AndNoResumeDictionaryAndHasCompletionBlock_shouldReturnYes
{
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=2&response=someEncryptedResponse"];
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertTrue(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs3AndRequestIntiatedByAdalAndHasCompletionBlock_shouldReturnNo
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_ADAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=3&response=someEncryptedResponse"];
    MSIDLegacyBrokerResponseHandler *brokerResponseHandler = [[MSIDLegacyBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV1Oauth2Factory new] tokenResponseValidator:[MSIDLegacyTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertFalse(result);
}

#pragma mark - Helpers

- (void)saveResumeStateWithAuthority:(NSString *)authority
{
    NSDictionary *resumeState = @{@"authority": authority,
                                  @"resource": @"https://graph.windows.net",
                                  @"keychain_group": @"com.microsoft.adalcache",
                                  @"redirect_uri": @"x-msauth-test://com.microsoft.testapp",
                                  @"sdk_name": @"adal-objc",
                                  @"broker_nonce" : @"nonce"
                                  };

    [[NSUserDefaults standardUserDefaults] setObject:resumeState forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
}

@end
