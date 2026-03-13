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
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccount.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDCache.h"
#import "MSIDBrokerResponse.h"
#import "MSIDAADV2BrokerResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"

@interface MSIDDefaultTokenResponseValidatorTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenResponseValidator *validator;
@property (nonatomic) MSIDTestCacheDataSource *dataSource;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

@end

@implementation MSIDDefaultTokenResponseValidatorTests

- (void)setUp
{
    self.validator = [MSIDDefaultTokenResponseValidator new];
    self.dataSource = [[MSIDTestCacheDataSource alloc] init];
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:self.dataSource otherCacheAccessors:nil];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:self.dataSource];
}

- (void)tearDown
{
}

#pragma mark - Tests

- (void)testValidateTokenResult_whenSomeScopesRejectedByServer_shouldReturnErrorWithGrantedScopesButWithoutDefaultOidcScopes
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:@"fakescope1 fakescope2"];
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                               responseRT:nil
                                                               responseID:nil
                                                            responseScope:@"openid profile offline_access user.read user.write"
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    NSError *error;
    
    [self.validator validateTokenResult:result
                          configuration:configuration
                              oidcScope:defaultOidcScope
                         validateScopes:YES
                          correlationID:correlationID
                                  error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerDeclinedScopes);
    NSArray *declinedScopes = @[@"fakescope1", @"fakescope2"];
    XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], declinedScopes);
    NSArray *grantedScopes = @[@"user.read", @"user.write"];
    XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], grantedScopes);
}

- (void)testValidateTokenResult_whenEmailScopesNotIncludedByServer_shouldReturnValidResult
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:@"email user.read user.write"];
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                               responseRT:nil
                                                               responseID:nil
                                                            responseScope:@"User.Read User.Write"
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    NSError *error;
    
    BOOL validated = [self.validator validateTokenResult:result
                                           configuration:configuration
                                               oidcScope:defaultOidcScope
                                          validateScopes:YES
                                           correlationID:correlationID
                                                   error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateTokenResult_whenEmailScopesIncludedByServer_shouldReturnValidResult
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:@"email user.read user.write"];
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                               responseRT:nil
                                                               responseID:nil
                                                            responseScope:@"email User.Read User.Write"
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    NSError *error;
    
    BOOL validated = [self.validator validateTokenResult:result
                                           configuration:configuration
                                               oidcScope:defaultOidcScope
                                          validateScopes:YES
                                           correlationID:correlationID
                                                   error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateTokenResult_whenWithValidResponse_shouldReturnValidResult
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];

    NSError *error;
    
    BOOL validated = [self.validator validateTokenResult:result
                                        configuration:configuration
                                            oidcScope:defaultOidcScope
                                          validateScopes:YES
                                        correlationID:correlationID
                                                error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenUIDMatch_shouldReturnYES
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    
    NSError *error;
    
    BOOL validated = [self.validator validateAccount:account.accountIdentifier
                                         tokenResult:result
                                       correlationID:correlationID
                                               error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenUIDMismatch_shouldReturnNO
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    
    NSError *error;
    
    BOOL validated = [self.validator validateAccount:[[MSIDAccountIdentifier alloc] initWithDisplayableId:@"somedisplayableid"
                                                                                            homeAccountId:@"someuid.someutid"]
                                         tokenResult:result
                                       correlationID:correlationID
                                               error:&error];
    
    XCTAssertFalse(validated);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorMismatchedAccount);
}

#pragma mark - Client Data Tests

- (void)testValidateTokenResponse_whenClientDataIsPresent_shouldInsertClientDataIntoBrokerMetaData
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    response.clientData = @"test_client_data_value";

    NSError *error;
    MSIDTokenResult *result = [self.validator validateTokenResponse:response
                                                       oauthFactory:factory
                                                      configuration:configuration
                                                     requestAccount:nil
                                                      correlationID:correlationID
                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualObjects([result.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA], @"test_client_data_value");
}

- (void)testValidateTokenResponse_whenClientDataIsNil_shouldNotInsertClientDataIntoBrokerMetaData
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    // clientData intentionally not set

    NSError *error;
    MSIDTokenResult *result = [self.validator validateTokenResponse:response
                                                       oauthFactory:factory
                                                      configuration:configuration
                                                     requestAccount:nil
                                                      correlationID:correlationID
                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertNil([result.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA]);
}

- (void)testValidateTokenResponse_whenTokenResponseHasErrorAndClientDataIsPresent_shouldPropagateClientDataIntoErrorUserInfo
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    // Simulate a /token failure response (e.g. invalid_grant) that also carries clientData.
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{@"error" : @"invalid_grant",
                                                                                                 @"error_description" : @"AADSTS50076"}
                                                                                         error:nil];
    response.clientData = @"test_client_data_value";

    NSError *error;
    MSIDTokenResult *result = [self.validator validateTokenResponse:response
                                                       oauthFactory:factory
                                                      configuration:configuration
                                                     requestAccount:nil
                                                      correlationID:correlationID
                                                              error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSID_CLIENT_DATA_RESPONSE], @"test_client_data_value");
}

- (void)testValidateAccount_whenUIDMismatch_ForDeletedAndRecreatedUser_shouldReturnYES
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    
    NSError *error;
    XCTAssertEqualObjects(result.account.accountIdentifier.uid, @"fedcba98-7654-3210-0000-000000000000");
    XCTAssertEqualObjects(result.account.accountIdentifier.utid, @"00000000-0000-1234-5678-90abcdefffff");
    XCTAssertEqualObjects(result.account.accountIdentifier.displayableId, @"user@contoso.com");
    BOOL validated = [self.validator validateAccount:[[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                                            homeAccountId:@"some-other-uid-other-than-fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff"]
                                         tokenResult:result
                                       correlationID:correlationID
                                               error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

#pragma mark - Broker Response Client Data Tests

- (void)testValidateAndSaveBrokerResponse_whenClientDataIsPresent_shouldPropagateClientDataIntoBrokerMetaData
{
    __auto_type correlationID = [NSUUID new];
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID } msidBase64UrlJson];

    NSDictionary *brokerDictionary = @{
        @"authority" : @"https://login.microsoftonline.com/common",
        @"client_id" : DEFAULT_TEST_CLIENT_ID,
        @"scope" : DEFAULT_TEST_SCOPE,
        @"access_token" : DEFAULT_TEST_ACCESS_TOKEN,
        @"refresh_token" : DEFAULT_TEST_REFRESH_TOKEN,
        @"expires_on" : @"35674848",
        @"id_token" : [MSIDTestIdTokenUtil defaultV2IdToken],
        @"x-broker-app-ver" : @"1.2",
        @"vt" : @YES,
        @"client_info" : clientInfoString,
        @"correlation_id" : [correlationID UUIDString],
        MSID_CLIENT_DATA_RESPONSE : @"test_broker_client_data"
    };

    NSError *brokerError = nil;
    MSIDAADV2BrokerResponse *brokerResponse = [[MSIDAADV2BrokerResponse alloc] initWithDictionary:brokerDictionary error:&brokerError];
    XCTAssertNotNil(brokerResponse);
    XCTAssertNil(brokerError);

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    NSError *error = nil;
    MSIDTokenResult *result = [self.validator validateAndSaveBrokerResponse:brokerResponse
                                                                 oidcScope:@"openid profile offline_access"
                                                          requestAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                             instanceAware:NO
                                                              oauthFactory:factory
                                                                tokenCache:self.tokenCache
                                                      accountMetadataCache:self.accountMetadataCache
                                                             correlationID:correlationID
                                                          saveSSOStateOnly:YES
                                                                authScheme:[MSIDAuthenticationScheme new]
                                                                     error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualObjects([result.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA], @"test_broker_client_data");
}

- (void)testValidateAndSaveBrokerResponse_whenVerificationFailsAndClientDataIsPresent_shouldReturnNilResultAndPropagateClientDataIntoError
{
    __auto_type correlationID = [NSUUID new];

    // Omit client_info to trigger MSIDAADV2Oauth2Factory's verifyResponse failure ("Client info was not returned")
    NSDictionary *brokerDictionary = @{
        @"authority" : @"https://login.microsoftonline.com/common",
        @"client_id" : DEFAULT_TEST_CLIENT_ID,
        @"scope" : DEFAULT_TEST_SCOPE,
        @"access_token" : DEFAULT_TEST_ACCESS_TOKEN,
        @"refresh_token" : DEFAULT_TEST_REFRESH_TOKEN,
        @"expires_on" : @"35674848",
        @"id_token" : [MSIDTestIdTokenUtil defaultV2IdToken],
        @"x-broker-app-ver" : @"1.2",
        @"vt" : @YES,
        @"correlation_id" : [correlationID UUIDString],
        MSID_CLIENT_DATA_RESPONSE : @"test_broker_client_data"
    };

    NSError *brokerError = nil;
    MSIDAADV2BrokerResponse *brokerResponse = [[MSIDAADV2BrokerResponse alloc] initWithDictionary:brokerDictionary error:&brokerError];
    XCTAssertNotNil(brokerResponse);
    XCTAssertNil(brokerError);

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];

    NSError *error = nil;
    MSIDTokenResult *result = [self.validator validateAndSaveBrokerResponse:brokerResponse
                                                                 oidcScope:@"openid profile offline_access"
                                                          requestAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                             instanceAware:NO
                                                              oauthFactory:factory
                                                                tokenCache:self.tokenCache
                                                      accountMetadataCache:self.accountMetadataCache
                                                             correlationID:correlationID
                                                          saveSSOStateOnly:YES
                                                                authScheme:[MSIDAuthenticationScheme new]
                                                                     error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSID_CLIENT_DATA_RESPONSE], @"test_broker_client_data");
}

- (void)testValidateAndSaveTokenResponse_whenClientDataIsPresent_shouldPropagateClientDataIntoBrokerMetaData
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];

    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"some_uri"
                                                                                clientId:@"myclient"
                                                                                  scopes:[NSOrderedSet orderedSetWithObject:DEFAULT_TEST_SCOPE]
                                                                              oidcScopes:[NSOrderedSet orderedSetWithObjects:@"openid", @"profile", @"offline_access", nil]
                                                                           correlationId:correlationID
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:nil
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:nil];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    response.clientData = @"test_client_data_value";

    NSError *error = nil;
    MSIDTokenResult *result = [self.validator validateAndSaveTokenResponse:response
                                                             oauthFactory:factory
                                                               tokenCache:self.tokenCache
                                                     accountMetadataCache:self.accountMetadataCache
                                                        requestParameters:parameters
                                                         saveSSOStateOnly:YES
                                                                    error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualObjects([result.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA], @"test_client_data_value");
}


@end
