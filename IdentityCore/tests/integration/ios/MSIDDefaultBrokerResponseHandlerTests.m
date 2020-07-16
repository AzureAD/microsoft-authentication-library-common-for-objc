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
#import "MSIDTestCacheAccessorHelper.h"
#import "MSIDRefreshToken.h"
#import "MSIDIdToken.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"

@interface MSIDDefaultBrokerResponseHandlerTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *cacheAccessor;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

@end

@implementation MSIDDefaultBrokerResponseHandlerTests

- (void)setUp {
    [super setUp];
    [MSIDTestBrokerKeyProviderHelper addKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"] accessGroup:@"com.microsoft.adalcache" applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];
    
    id<MSIDExtendedTokenCacheDataSource> dataSource =  [[MSIDKeychainTokenCache alloc] init];
    [dataSource clearWithContext:nil error:nil];
    MSIDLegacyTokenCacheAccessor *otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.cacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor]];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
}

- (void)tearDown {
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(brokerResponseHandler.providedAuthority.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqual(brokerResponseHandler.instanceAware, NO);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(result.accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(result.accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(result.accessToken.realm, @"contoso.com-guid");
    
    XCTAssertTrue([expiresOn timeIntervalSinceDate:result.accessToken.expiresOn] < 1);
    XCTAssertTrue([extExpiresOn timeIntervalSinceDate:result.accessToken.extendedExpiresOn] < 1);
    
    XCTAssertEqualObjects(result.rawIdToken, idTokenString);
    XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertEqualObjects(result.correlationId.UUIDString, correlationId);
    XCTAssertEqual(result.extendedLifeTimeToken, NO);
    
    XCTAssertTrue([result.tokenResponse isKindOfClass:[MSIDAADV2TokenResponse class]]);
    MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)result.tokenResponse;
    XCTAssertEqualObjects(tokenResponse.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(tokenResponse.tokenType, @"Bearer");
    XCTAssertEqualObjects(tokenResponse.idToken, idTokenString);
    XCTAssertEqualObjects(tokenResponse.scope, scopes);
    XCTAssertEqualObjects(tokenResponse.familyId, @"1");
    
    XCTAssertEqualObjects(result.account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.account.clientInfo.rawClientInfo, rawClientInfo);
    XCTAssertEqualObjects(result.account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(result.account.realm, @"contoso.com-guid");
    
    XCTAssertFalse(result.accessToken.isExpired);
    
    //Check access token in cache
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"contoso.com-guid");
    XCTAssertEqualObjects(accessToken.expiresOn, result.accessToken.expiresOn);
    XCTAssertEqualObjects(accessToken.extendedExpiresOn, result.accessToken.extendedExpiresOn);
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    
    //Check refresh token in cache
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 2);
    
    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(refreshToken.familyId, @"1");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(refreshToken.realm);
    
    //Check id token in cache
    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:self.cacheAccessor];
    XCTAssertEqual([idTokens count], 1);
    
    MSIDIdToken *idToken = idTokens[0];
    XCTAssertEqualObjects(idToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(idToken.realm, @"contoso.com-guid");
    XCTAssertEqualObjects(idToken.rawIdToken, idTokenString);
    
    //Check account in cache
    NSArray *accounts = [self.cacheAccessor accountsWithAuthority:nil clientId:nil familyId:nil accountIdentifier:nil context:nil error:nil];
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"contoso.com-guid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(account.clientInfo.rawClientInfo, rawClientInfo);
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andDeviceIsShared_shouldReturnResultButNotSaveAccessTokenToCache
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
      @"expires_on" : expiresOnString,
      @"ext_expires_on" : extExpiresOnString,
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      @"broker_nonce" : @"nonce",
      @"device_mode": @"shared",
      @"wpj_status": @"notJoined"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertEqualObjects(result.accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(result.accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.accessToken.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(result.accessToken.realm, @"contoso.com-guid");
    
    XCTAssertEqualObjects(result.rawIdToken, idTokenString);
    XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com-guid");
    XCTAssertEqualObjects(result.correlationId.UUIDString, correlationId);
    XCTAssertEqual(result.extendedLifeTimeToken, NO);
    
    XCTAssertTrue([result.tokenResponse isKindOfClass:[MSIDAADV2TokenResponse class]]);
    MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)result.tokenResponse;
    XCTAssertNil(tokenResponse.refreshToken, @"i-am-a-refresh-token");
    XCTAssertEqualObjects(tokenResponse.tokenType, @"Bearer");
    XCTAssertEqualObjects(tokenResponse.idToken, idTokenString);
    XCTAssertEqualObjects(tokenResponse.scope, scopes);
    XCTAssertEqualObjects(tokenResponse.familyId, @"1");
    
    XCTAssertEqualObjects(result.account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(result.account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(result.account.clientInfo.rawClientInfo, rawClientInfo);
    XCTAssertEqualObjects(result.account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(result.account.realm, @"contoso.com-guid");
    
    XCTAssertFalse(result.accessToken.isExpired);
    
    //Check access token is NOT in cache
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 0);
    
    //Check refresh token is NOT in cache
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 0);
    
    //Check id token is NOT in cache
    NSArray *idTokens = [MSIDTestCacheAccessorHelper getAllIdTokens:self.cacheAccessor];
    XCTAssertEqual([idTokens count], 0);
    
    //Check account IS in cache
    NSArray *accounts = [self.cacheAccessor accountsWithAuthority:nil clientId:nil familyId:nil accountIdentifier:nil accountMetadataCache:nil signedInAccountsOnly:NO context:nil error:nil];
    MSIDAccount *account = accounts[0];
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.realm, @"contoso.com-guid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(account.accountIdentifier.displayableId, @"user@contoso.com");
    XCTAssertEqualObjects(account.clientInfo.rawClientInfo, rawClientInfo);
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNonNil_andNonceMissingInResponse_shouldReturnResultAndNilError
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNil_andBrokerNonceMatches_shouldReturnResultAndNilError
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_andSourceApplicationNil_andNonceMissingInResponse_shouldReturnResumeStateError
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      @"broker_nonce" : @"incorrect_nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
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
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"declined_scopes" : @"decliendScope1 decliendScope2",
      @"granted_scopes" : @"grantedScope1 grantedScope2",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description": @"Error occured",
      @"success": @NO,
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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
    XCTAssertEqualObjects(error.userInfo[MSIDHomeAccountIdkey], @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], @"decliendScope1 decliendScope2");
    XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], @"grantedScope1 grantedScope2");
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNonNil_andNonceMissingInResponse_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"declined_scopes" : @"decliendScope1 decliendScope2",
      @"granted_scopes" : @"grantedScope1 grantedScope2",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description": @"Error occured",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, -42004);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNil_andBrokerNonceMatches_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"declined_scopes" : @"decliendScope1 decliendScope2",
      @"granted_scopes" : @"grantedScope1 grantedScope2",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description": @"Error occured",
      @"success": @NO,
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, -42004);
}

- (void)testHandleBrokerResponse_whenValidBrokerErrorResponse_andSourceApplicationNil_andNonceMissingInResponse_shouldReturnResumeStateError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"declined_scopes" : @"decliendScope1 decliendScope2",
      @"granted_scopes" : @"grantedScope1 grantedScope2",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description": @"Error occured",
      @"success": @NO,
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
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
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"declined_scopes" : @"decliendScope1 decliendScope2",
      @"granted_scopes" : @"grantedScope1 grantedScope2",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description": @"Error occured",
      @"success": @NO,
      @"broker_nonce" : @"incorrect_nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Broker nonce mismatch!");
}

- (void)testHandleBrokerResponse_whenBrokerErrorResponseWithHttpHeadersAsEncodedString_shouldReturnNilResultAndErrorWithHeaders
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @429,
      @"http_response_headers" : @"Content-Type=application%2Fjson%3B+charset%3Dutf-8&P3P=CP%3D%22DSP+CUR+OTPi+IND+OTRi+ONL+FIN%22&Access-Control-Allow-Origin=%2A&x-ms-request-id=1739e4e0-4b6e-4aba-b404-4979a0d41c00&Cache-Control=private&Date=Sat%2C+17+Nov+2018+23%3A20%3A03+GMT&Strict-Transport-Security=max-age%3D31536000%3B+includeSubDomains&client-request-id=14202594-2dfc-4ee8-a908-d337ca2b266b&Content-Length=975&X-Content-Type-Options=nosniff"
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"111",
      @"broker_error_domain" : @"NSURLErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error_description" : @"Error occured",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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

- (void)testHandleBrokerResponse_whenBrokerErrorResponseWithHttpHeadersAsDictionary_shouldReturnNilResultAndErrorWithHeaders
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *headers = @{
        @"Access-Control-Allow-Origin" : @"*",
        @"Cache-Control" : @"private",
        @"Content-Length" : @"975",
        @"Content-Type" : @"application/json; charset=utf-8",
        @"Date" : @"Sat, 17 Nov 2018 23:20:03 GMT",
        @"P3P" : @"CP=\"DSP CUR OTPi IND OTRi ONL FIN\"",
        @"Strict-Transport-Security" : @"max-age=31536000; includeSubDomains",
        @"X-Content-Type-Options" : @"nosniff",
        @"client-request-id" : @"14202594-2dfc-4ee8-a908-d337ca2b266b",
        @"x-ms-request-id" : @"1739e4e0-4b6e-4aba-b404-4979a0d41c00" };
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @429,
      @"http_response_headers" : headers,
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"111",
      @"broker_error_domain" : @"NSURLErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error_description" : @"Error occured",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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
    XCTAssertEqualObjects(error.userInfo[MSIDHTTPHeadersKey], headers);
}


- (void)testHandleBrokerResponse_whenBrokerIntuneErrorResponse_withNoAdditionalToken_shouldReturnNilResultAndError
{
    [self saveResumeStateWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSString *correlationId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"213",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"error": @"unauthorized_client",
      @"suberror": @"protection_policies_required",
      @"error_description": @"AADSTS53005: Application needs to enforce intune protection policies",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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
    XCTAssertEqualObjects(error.userInfo[MSIDHomeAccountIdkey], @"1.1234-5678-90abcdefg");
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      };
    NSString *intuneMAMTokenString = [intuneMAMTokenDictionary msidJSONSerializeWithContext:nil];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"213",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"additional_tokens" : intuneMAMTokenString,
      @"error": @"unauthorized_client",
      @"suberror": @"protection_policies_required",
      @"error_description" : @"AADSTS53005: Application needs to enforce intune protection policies",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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
    XCTAssertEqualObjects(error.userInfo[MSIDHomeAccountIdkey], @"1.1234-5678-90abcdefg");
    XCTAssertNil(error.userInfo[MSIDDeclinedScopesKey]);
    XCTAssertNil(error.userInfo[MSIDGrantedScopesKey]);
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"intune-mam-accesstoken");
    XCTAssertEqualObjects(accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"contoso.com-guid");
    
    XCTAssertTrue([expiresOn timeIntervalSinceDate:accessToken.expiresOn] < 1);
    XCTAssertTrue([extExpiresOn timeIntervalSinceDate:accessToken.extendedExpiresOn] < 1);
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"intune-mam-refreshtoken");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(refreshToken.realm);
    
    XCTAssertNil(refreshToken.familyId);
}

- (void)testHandleBrokerResponse_whenScopesDeclinedErrorResponse_withAdditionalToken_shouldReturnNilResultAndError_andCacheAdditionalToken
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
    
    NSString *scopes = @"myscope1 myscope2 myscope3 myscope4";
    
    NSDictionary *additionalTokenDictionary =
    @{
      @"authority" : @"https://login.microsoftonline.com/common",
      @"scope" : scopes,
      @"client_id" : @"my_client_id",
      @"id_token" : mamIdTokenString,
      @"client_info" : mamRawClientInfo,
      @"access_token" : @"additional-accesstoken",
      @"token_type" : @"Bearer",
      @"refresh_token" : @"additional-refreshtoken",
      @"expires_on" : expiresOnString,
      @"ext_expires_on" : extExpiresOnString,
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      };
    NSString *additionalTokenString = [additionalTokenDictionary msidJSONSerializeWithContext:nil];
    
    NSDictionary *errorMetadata =
    @{
      @"http_response_code" : @200,
      @"username" : @"user@contoso.com",
      @"home_account_id" : @"1.1234-5678-90abcdefg",
      @"granted_scopes" : @"myscope1 myscope2",
      @"declined_scopes" : @"myscope3 myscope4",
      };
    NSString *errorMetaDataString = [errorMetadata msidJSONSerializeWithContext:nil];
    
    NSDictionary *brokerResponseParams =
    @{
      @"broker_error_code" : @"-42004",
      @"broker_error_domain" : @"MSALErrorDomain",
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"error_metadata" : errorMetaDataString,
      @"additional_tokens" : additionalTokenString,
      @"error": @"invalid_grant",
      @"suberror": @"consent_required",
      @"error_description" : @"Error occured",
      @"success": @NO
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
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
    XCTAssertEqualObjects(error.userInfo[MSIDHomeAccountIdkey], @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], @"myscope3 myscope4");
    XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], @"myscope1 myscope2");
    
    NSArray *accessTokens = [MSIDTestCacheAccessorHelper getAllDefaultAccessTokens:self.cacheAccessor];
    XCTAssertEqual([accessTokens count], 1);
    
    MSIDAccessToken *accessToken = accessTokens[0];
    XCTAssertEqualObjects(accessToken.accessToken, @"additional-accesstoken");
    XCTAssertEqualObjects(accessToken.scopes, [scopes msidScopeSet]);
    XCTAssertEqualObjects(accessToken.clientId, @"my_client_id");
    XCTAssertEqualObjects(accessToken.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(accessToken.realm, @"contoso.com-guid");
    XCTAssertTrue([expiresOn timeIntervalSinceDate:accessToken.expiresOn] < 1);
    XCTAssertTrue([extExpiresOn timeIntervalSinceDate:accessToken.extendedExpiresOn] < 1);
    XCTAssertEqualObjects(accessToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    
    NSArray *refreshTokens = [MSIDTestCacheAccessorHelper getAllDefaultRefreshTokens:self.cacheAccessor];
    XCTAssertEqual([refreshTokens count], 1);
    
    MSIDRefreshToken *refreshToken = refreshTokens[0];
    XCTAssertEqualObjects(refreshToken.refreshToken, @"additional-refreshtoken");
    XCTAssertEqualObjects(refreshToken.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
    XCTAssertEqualObjects(refreshToken.environment, @"login.microsoftonline.com");
    XCTAssertNil(refreshToken.realm);
    XCTAssertNil(refreshToken.familyId);
}

- (void)testHandleBrokerResponse_whenValidBrokerResponse_shouldUpdateAccountMetadata
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
      @"correlation_id" : correlationId,
      @"x-broker-app-ver" : @"1.0.0",
      @"foci" : @"1",
      @"success": @YES,
      @"broker_nonce" : @"nonce"
      };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.accessToken.accessToken, @"i-am-a-access-token");
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(brokerResponseHandler.providedAuthority.absoluteString, @"https://login.microsoftonline.com/common");
    XCTAssertEqual(brokerResponseHandler.instanceAware, NO);
    
    // Verify sign in state
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"1.1234-5678-90abcdefg" clientId:@"my_client_id" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateSignedIn);
    
    // Verify authority mapping
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"1.1234-5678-90abcdefg"
                                                                 clientId:@"my_client_id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso.com-guid", retrievedCacheURL.absoluteString);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs3AndRequestIntiatedByMsalAndHasCompletionBlock_shouldReturnYes
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_MSAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=3&response=someEncryptedResponse"];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertTrue(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs3AndRequestIsNotIntiatedByMsalAndHasCompletionBlock_shouldReturnNo
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_ADAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=3&response=someEncryptedResponse"];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertFalse(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs3AndNoResumeDictionaryAndNoCompletionBlock_shouldReturnNo
{
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=3&response=someEncryptedResponse"];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:NO];
    
    XCTAssertFalse(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs3AndNoResumeDictionaryAndHasCompletionBlock_shouldReturnYes
{
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=3&response=someEncryptedResponse"];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertTrue(result);
}

-(void)testCanHandleBrokerResponse_whenProtocolVersionIs2AndRequestIntiatedByMSALAndHasCompletionBlock_shouldReturnNo
{
    NSDictionary *resumeDictionary = @{MSID_SDK_NAME_KEY: MSID_ADAL_SDK_NAME};
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    NSURL *url = [[NSURL alloc] initWithString:@"testapp://com.microsoft.testapp/broker?msg_protocol_ver=2&response=someEncryptedResponse"];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:url hasCompletionBlock:YES];
    
    XCTAssertFalse(result);
}


-(void)testCanHandleBrokerResponse_whenAuthSchemeinResumeStateIsPop_AndBrokerResponseIsSuccess_AndAuthSchemeinBrokerResponseIsPop_shouldReturnBrokerResponse
{
    [self saveResumeStateWithauthScheme:@"Pop"];
    NSURL *brokerResponseURL = [self createPopResponseFromBroker];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
        NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
}

-(void)testCanHandleBrokerResponse_whenAuthSchemeinResumeStateIsBearer_AndBrokerResponseIsSuccess_AndAuthSchemeinBrokerResponseIsBearer_shouldReturnBrokerResponse
{
    [self saveResumeStateWithauthScheme:@"Bearer"];
    NSURL *brokerResponseURL = [self createBearerResponseFromBroker];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    XCTAssertNotNil(result);
    XCTAssertNil(error);
}

-(void)testCanHandleBrokerResponse_whenAuthSchemeinResumeStateIsPop_AndBrokerResponseIsSuccess_AndAuthSchemeinBrokerResponseIsBearer_shouldReturnAuthSchemeError
{
    [self saveResumeStateWithauthScheme:@"Pop"];
    NSURL *brokerResponseURL = [self createBearerResponseFromBroker];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    NSString *expectedErrorDescription = @"Please update Microsoft Authenticator to the latest version. Pop tokens are not supported with this broker version.";
    XCTAssertEqual(error.userInfo[MSIDErrorDescriptionKey], expectedErrorDescription);
}

-(void)testCanHandleBrokerResponse_whenAuthSchemeinResumeStateIsPop_AndBrokerResponseIsFailure_AndAuthSchemeinBrokerResponseIsBearer_shouldReturnResponseError
{
    [self saveResumeStateWithauthScheme:@"Pop"];
    NSURL *brokerResponseURL = [self createFailureResponseFromBroker];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    NSString *authMismatchErrorDescription = @"Please update Microsoft Authenticator to the latest version. Pop tokens are not supported with this broker version.";
    XCTAssertNotEqual(error.userInfo[MSIDErrorDescriptionKey], authMismatchErrorDescription);
}

-(void)testCanHandleBrokerResponse_whenAuthSchemeinResumeStateIsPop_AndBrokerResponseIsFailure_WithAdditionalTokens_shouldReturnResponseError
{
    [self saveResumeStateWithauthScheme:@"Pop"];
    NSURL *brokerResponseURL = [self createFailureResponseFromBrokerWithAdditionalToken];
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    NSError *error = nil;
    MSIDTokenResult *result = [brokerResponseHandler handleBrokerResponseWithURL:brokerResponseURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    NSString *authMismatchErrorDescription = @"Please update Microsoft Authenticator to the latest version. Pop tokens are not supported with this broker version.";
    XCTAssertNotEqual(error.userInfo[MSIDErrorDescriptionKey], authMismatchErrorDescription);
}


#pragma mark - Helpers

- (void)saveResumeStateWithAuthority:(NSString *)authority
{
    NSDictionary *resumeState = @{@"authority" : authority,
                                  @"scope" : @"myscope1 myscope2",
                                  @"keychain_group" : @"com.microsoft.adalcache",
                                  @"redirect_uri" : @"x-msauth-test://com.microsoft.testapp",
                                  @"broker_nonce" : @"nonce",
                                  @"instance_aware" : @"NO",
                                  @"provided_authority_url" : authority,
                                  };
    
    [[NSUserDefaults standardUserDefaults] setObject:resumeState forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
}

- (void)saveResumeStateWithauthScheme:(NSString *)authScheme
{
    NSDictionary *resumeState = nil;
    if ([authScheme isEqualToString:@"Pop"])
    {
        resumeState = @{@"authority" : @"https://login.microsoftonline.com/common",
                        @"scope" : @"myscope1 myscope2",
                        @"keychain_group" : @"com.microsoft.adalcache",
                        @"redirect_uri" : @"x-msauth-test://com.microsoft.testapp",
                        @"broker_nonce" : @"nonce",
                        @"instance_aware" : @"NO",
                        @"provided_authority_url" : @"https://login.microsoftonline.com/common",
                        @"token_type": @"Pop",
                        @"req_cnf": @"eyJraWQiOiJPeEF6UW55cEpBTnNtTERXTU1lRWJFZHM5ZERHbGtRS09iZkJrRW4zXzk0In0",
        };
    }
    else
    {
        resumeState = @{@"authority" : @"https://login.microsoftonline.com/common",
            @"scope" : @"myscope1 myscope2",
            @"keychain_group" : @"com.microsoft.adalcache",
            @"redirect_uri" : @"x-msauth-test://com.microsoft.testapp",
            @"broker_nonce" : @"nonce",
            @"instance_aware" : @"NO",
            @"provided_authority_url" : @"https://login.microsoftonline.com/common",
        };
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:resumeState forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
}

- (NSURL *)createBearerResponseFromBroker
{
    NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    NSString *rawClientInfo = [clientInfo msidBase64UrlJson];
    NSDictionary *brokerResponseParams =
    @{
        @"authority" : @"https://login.microsoftonline.com/common",
        @"scope" : @"myscope",
        @"client_id" : @"my_client_id",
        @"id_token" : @"token_string",
        @"client_info" : rawClientInfo,
        @"home_account_id" : @"1.1234-5678-90abcdefg",
        @"access_token" : @"i-am-a-access-token",
        @"token_type" : @"Bearer",
        @"refresh_token" : @"i-am-a-refresh-token",
        @"correlation_id" : @"uuid1",
        @"x-broker-app-ver" : @"1.0.0",
        @"foci" : @"1",
        @"success": @YES,
        @"broker_nonce" : @"nonce"
    };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    return brokerResponseURL;
}

- (NSURL *)createPopResponseFromBroker
{
    NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    NSString *rawClientInfo = [clientInfo msidBase64UrlJson];
    NSDictionary *brokerResponseParams =
    @{
        @"authority" : @"https://login.microsoftonline.com/common",
        @"scope" : @"myscope",
        @"client_id" : @"my_client_id",
        @"id_token" : @"token_string",
        @"client_info" : rawClientInfo,
        @"home_account_id" : @"1.1234-5678-90abcdefg",
        @"access_token" : @"i-am-a-access-token",
        @"token_type" : @"Pop",
        @"req_cnf" : @"eyJraWQiOiJPeEF6UW55cEpBTnNtTERXTU1lRWJFZHM5ZERHbGtRS09iZkJrRW4zXzk0In0",
        @"refresh_token" : @"i-am-a-refresh-token",
        @"correlation_id" : @"uuid1",
        @"x-broker-app-ver" : @"1.0.0",
        @"foci" : @"1",
        @"success": @YES,
        @"broker_nonce" : @"nonce"
    };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    return brokerResponseURL;
}

- (NSURL *)createFailureResponseFromBroker
{
    NSDictionary *brokerResponseParams =
    @{
        @"broker_error_code" : @"-50005",
        @"broker_error_domain" : @"MSALErrorDomain",
        @"broker_nonce" : @"nonce",
        @"correlation_id" : @"uuid",
        @"error_description" : @"Authentication error - User cancelled authentication flow",
        @"error_metadata" : @"{}",
        @"success" : @NO,
        @"x-broker-app-ver" : @"1.0",
    };
    
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    return brokerResponseURL;
}

- (NSURL *)createFailureResponseFromBrokerWithAdditionalToken
{
    NSDictionary *brokerResponseParams =
    @{
            
        @"additional_tokens" :@"{\"client_info\":\"eyJ1aWQiOiI1ODY4YWUzYS0wY2IwLTQwODUtYmI1ZC1mYzc3YzAwN2Q2ODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0\",\"authority\":\"https://login.microsoftonline.com/f645ad92-e38d-4d1a-b510-d1b09a74a8ca\",\"token_type\":\"Bearer\",\"x-broker-app-ver\":\"1.0\",\"refresh_token\":\"refreshtoken\",\"scope\":\"https://msmamservice.api.application/user_impersonation https://msmamservice.api.application/.default\",\"ext_expires_on\":\"1594853027\",\"foci\":\"1\",\"application_token\":\"app token\",\"expires_on\":\"1594853027\",\"success\":true,\"correlation_id\":\"0D74889A-AAC4-4D0C-9956-797E47AFACFB\",\"client_id\":\"27922004-5251-4030-b22d-91ecd9a37ea4\",\"id_token\":\"idtoken\",\"vt\":\"YES\",\"access_token\":\"access token\"}",
        @"broker_error_code" : @"-50004",
        @"broker_error_domain" : @"MSALErrorDomain",
        @"broker_nonce" : @"nonce",
        @"correlation_id" : @"UUID",
        @"error" : @"unauthorized_client",
        @"error_description" : @"AADSTS53005: Application needs to enforce Intune protection policies",
        @"suberror" : @"protection_policy_required",
        @"success" : @NO,
        @"x-broker-app-ver" : @"1.0",
    };
    NSURL *brokerResponseURL = [MSIDTestBrokerResponseHelper createDefaultBrokerResponse:brokerResponseParams
                                                                             redirectUri:@"x-msauth-test://com.microsoft.testapp"
                                                                           encryptionKey:[NSData msidDataFromBase64UrlEncodedString:@"BU-bLN3zTfHmyhJ325A8dJJ1tzrnKMHEfsTlStdMo0U"]];
    return brokerResponseURL;
}

@end
