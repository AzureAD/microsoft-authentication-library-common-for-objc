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
#import "MSIDTestBrokerKeyProviderHelper.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDConstants.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestBrokerResponseHelper.h"
#import "MSIDDefaultBrokerResponseHandler.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccountIdentifier.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"

@interface MSIDDefaultBrokerResponseHandlerTests : XCTestCase

@property (nonatomic) id<MSIDCacheAccessor> cacheAccessor;

@end

@implementation MSIDDefaultBrokerResponseHandlerTests

- (void)setUp {
    [super setUp];
    [MSIDTestBrokerKeyProviderHelper addKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"] accessGroup:@"com.microsoft.adalcache" applicationTag:@"com.microsoft.adBrokerKey"];
    
    id<MSIDTokenCacheDataSource> dataSource =  [[MSIDKeychainTokenCache alloc] init];
    [dataSource clearWithContext:nil error:nil];
    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDLegacyTokenCacheAccessor *otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:factory];
    self.cacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor] factory:factory];
}

- (void)tearDown {
    // Clear keychain
    NSDictionary *query = @{(id)kSecClass : (id)kSecClassKey,
                            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric};
    
    SecItemDelete((CFDictionaryRef)query);
    
    [super tearDown];
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_shouldReturnResultAndNilError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *idTokenString = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"user@contoso.com"
                                                                        subject:@"mysubject"
                                                                      givenName:@"myGivenName"
                                                                     familyName:@"myFamilyName"
                                                                           name:@"Contoso"
                                                                        version:@"2.0"
                                                                            tid:@"contoso.com-guid"];
    
    NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    NSString *rawClientInfo = [clientInfo msidBase64UrlJson];
    
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    
    NSDate *extExpiresOn = [NSDate dateWithTimeIntervalSinceNow:36000];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSString *scopes = @"myscope1 myscope2";
    
    NSDictionary *brokerResponseParams =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"scope" : scopes,
      @"client_id" : @"my_client_id",
      @"id_token" : idTokenString,
      @"client_info" : rawClientInfo,
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"access_token" : @"i-am-a-access-token",
      @"token_type" : @"Bearer",
      @"refresh_token" : @"i-am-a-refresh-token",
      @"expires_on" : expiresOnString,
      @"ext_expires_on" : extExpiresOnString,
      @"user_id" : @"user@contoso.com",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(result.accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(result.accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.legacyAccountId, @"user@contoso.com");
    XCTAssertEqualObjects(result.accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertTrue([expiresOn timeIntervalSinceDate:result.accessToken.expiresOn] < 1);
    XCTAssertTrue([extExpiresOn timeIntervalSinceDate:result.accessToken.extendedExpireTime] < 1);
    
    XCTAssertEqualObjects(result.rawIdToken, idTokenString);
    XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqualObjects(result.correlationId.UUIDString, correlationId);
    XCTAssertEqual(result.extendedLifeTimeToken, NO);
    
    XCTAssertTrue([result.tokenResponse isKindOfClass:[MSIDAADV2TokenResponse class]]);
    MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)result.tokenResponse;
    XCTAssertEqualObjects(tokenResponse.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(tokenResponse.tokenType, @"Bearer");
    XCTAssertEqualObjects(tokenResponse.idToken, idTokenString);
    XCTAssertEqualObjects(tokenResponse.scope, scopes);
    XCTAssertEqualObjects(tokenResponse.familyId, @"1");
    
    XCTAssertEqualObjects(result.account.accountIdentifier.legacyAccountId, @"user@contoso.com");
    XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.account.clientInfo.rawClientInfo, rawClientInfo);
    XCTAssertEqualObjects(result.account.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    
    XCTAssertFalse(result.accessToken.isExpired);
    
    //Check access token in cache
    NSArray *accessTokens = [MSIDKeychainTokenCache getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertEqualObjects(accessToken.expiresOn, result.accessToken.expiresOn);
    XCTAssertEqualObjects(accessToken.extendedExpireTime, result.accessToken.extendedExpireTime);
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    
    //Check refresh token in cache
    NSArray *refreshTokens = [MSIDKeychainTokenCache getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 2);
    
    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(refreshToken.familyId, @"1");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    
    //Check id token in cache
    NSArray *idTokens = [MSIDKeychainTokenCache getAllIdTokens:self.cacheAccessor];
    XCTAssertEqual([idTokens count], 1);
    
    MSIDIdToken *idToken = idTokens[0];
    XCTAssertEqualObjects(idToken.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertEqualObjects(idToken.rawIdToken, idTokenString);
    
    //Check account in cache
    NSArray *accounts = [self.cacheAccessor allAccountsForAuthority:nil clientId:nil familyId:nil context:nil error:nil];
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.accountIdentifier.legacyAccountId, @"user@contoso.com");
    XCTAssertEqualObjects(account.clientInfo.rawClientInfo, rawClientInfo);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"error_description" : @"Error occured",
      @"oauth_error" : @"invalid_grant",
      @"oauth_sub_error" : @"consent_required",
      @"user_id" : @"user@contoso.com",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"error_code" : @"-42004",
      @"error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, -42004);
    XCTAssertEqualObjects(error.domain, @"MSALErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @200);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Error occured");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"consent_required");
    XCTAssertEqualObjects(error.userInfo[MSIDUserDisplayableIdkey], @"user@contoso.com");
}

- (void)testHandleBrokerResponse_whenBrokerErrorResponseWithHttpHeaders_shouldReturnNilResultAndErrorWithHeaders
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @429,
      @"error_description" : @"Error occured",
      @"http_headers" : @"Content-Type=application%2Fjson%3B+charset%3Dutf-8&P3P=CP%3D%22DSP+CUR+OTPi+IND+OTRi+ONL+FIN%22&Access-Control-Allow-Origin=%2A&x-ms-request-id=1739e4e0-4b6e-4aba-b404-4979a0d41c00&Cache-Control=private&Date=Sat%2C+17+Nov+2018+23%3A20%3A03+GMT&Strict-Transport-Security=max-age%3D31536000%3B+includeSubDomains&client-request-id=14202594-2dfc-4ee8-a908-d337ca2b266b&Content-Length=975&X-Content-Type-Options=nosniff"
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"error_code" : @"111",
      @"error_domain" : @"NSURLErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 111);
    XCTAssertEqualObjects(error.domain, @"NSURLErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @429);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Error occured");
    XCTAssertNil(error.userInfo[MSIDUserDisplayableIdkey]);
    XCTAssertNil(error.userInfo[MSIDOAuthErrorKey]);
    XCTAssertNil(error.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertNil(error.userInfo[MSIDDeclinedScopesKey]);
    XCTAssertNil(error.userInfo[MSIDGrantedScopesKey]);
    
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

- (void)testHandleBrokerResponse_whenBrokerIntuneErrorResponse_withNoAdditionalToken_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"error_description" : @"AADSTS53005: Application needs to enforce intune protection policies",
      @"oauth_error" : @"unauthorized_client",
      @"oauth_sub_error" : @"protection_policies_required",
      @"user_id" : @"user@contoso.com",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"error_code" : @"213",
      @"error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
    XCTAssertEqualObjects(error.domain, @"MSALErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @200);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"AADSTS53005: Application needs to enforce intune protection policies");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"unauthorized_client");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"protection_policies_required");
    XCTAssertEqualObjects(error.userInfo[MSIDUserDisplayableIdkey], @"user@contoso.com");
    XCTAssertNil(error.userInfo[MSIDDeclinedScopesKey]);
    XCTAssertNil(error.userInfo[MSIDGrantedScopesKey]);
}

- (void)testHandleBrokerResponse_whenBrokerIntuneErrorResponse_withAdditionalToken_shouldReturnNilResultAndError_andCacheMAMToken
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSString *mamIdTokenString = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:@"user@contoso.com"
                                                                           subject:@"mysubject"
                                                                         givenName:@"myGivenName"
                                                                        familyName:@"myFamilyName"
                                                                              name:@"Contoso"
                                                                           version:@"2.0"
                                                                               tid:@"contoso.com-guid"];
    
    NSDictionary *mamClientInfo = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    NSString *mamRawClientInfo = [mamClientInfo msidBase64UrlJson];
    
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    
    NSDate *extExpiresOn = [NSDate dateWithTimeIntervalSinceNow:36000];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    
    NSString *scopes = @"myscope1 myscope2";
    
    NSDictionary *intuneMAMTokenDictionary =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"scope" : scopes,
      @"client_id" : @"my_client_id",
      @"id_token" : mamIdTokenString,
      @"client_info" : mamRawClientInfo,
      @"access_token" : @"intune-mam-accesstoken",
      @"token_type" : @"Bearer",
      @"refresh_token" : @"intune-mam-refreshtoken",
      @"expires_on" : expiresOnString,
      @"ext_expires_on" : extExpiresOnString,
      @"user_id" : @"user@contoso.com",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      };
    NSString *intuneMAMTokenString = [intuneMAMTokenDictionary msidJSONSerializeWithContext:nil];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"error_description" : @"AADSTS53005: Application needs to enforce intune protection policies",
      @"oauth_error" : @"unauthorized_client",
      @"oauth_sub_error" : @"protection_policies_required",
      @"user_id" : @"user@contoso.com",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"error_code" : @"213",
      @"error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"additional_tokens" : intuneMAMTokenString,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 213);
    XCTAssertEqualObjects(error.domain, @"MSALErrorDomain");
    XCTAssertEqualObjects(error.userInfo[MSIDCorrelationIdKey], correlationId);
    XCTAssertEqualObjects(error.userInfo[MSIDBrokerVersionKey], @"1.0.0");
    XCTAssertEqualObjects(error.userInfo[MSIDHTTPResponseCodeKey], @200);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"AADSTS53005: Application needs to enforce intune protection policies");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"unauthorized_client");
    XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"protection_policies_required");
    XCTAssertEqualObjects(error.userInfo[MSIDUserDisplayableIdkey], @"user@contoso.com");
    XCTAssertNil(error.userInfo[MSIDDeclinedScopesKey]);
    XCTAssertNil(error.userInfo[MSIDGrantedScopesKey]);
    
    NSArray *accessTokens = [MSIDKeychainTokenCache getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"intune-mam-accesstoken");
    XCTAssertEqualObjects(accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(accessToken.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertTrue([expiresOn timeIntervalSinceDate:accessToken.expiresOn] < 1);
    XCTAssertTrue([extExpiresOn timeIntervalSinceDate:accessToken.extendedExpireTime] < 1);
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    
    NSArray *refreshTokens = [MSIDKeychainTokenCache getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"intune-mam-refreshtoken");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(refreshToken.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertNil(refreshToken.familyId);
}

#pragma mark - Helpers

- (void)saveResumeStateWithAuthority:(NSString *)authority
{
    NSDictionary *resumeState = @{@"authority" : authority,
                                  @"scope" : @"myscope1 myscope2",
                                  @"keychain_group" : @"com.microsoft.adalcache",
                                  @"redirect_uri" : @"x-msauth-test://com.microsoft.testapp"
                                  };
    
    [[NSUserDefaults standardUserDefaults] setObject:resumeState forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
}

@end
