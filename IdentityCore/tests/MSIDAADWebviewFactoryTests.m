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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAADWebviewFactory.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDDeviceId.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDSignoutWebRequestConfiguration.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDClaimsRequest.h"
#import "MSIDPkce.h"
#import "MSIDWebAADAuthCodeResponse.h"
#import "MSIDBrokerConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"

@interface MSIDAADWebviewFactoryTests : XCTestCase

@end

@implementation MSIDAADWebviewFactoryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testAuthorizationParametersFromParameters_withValidParams_shouldContainAADConfiguration
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.promptType = MSIDPromptTypeLogin;
    
    NSDictionary *claimsJsonDictionary = @{@"id_token":@{@"given_name":@{@"essential":@YES}}};
    parameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];
    parameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    
    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];
    
    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];

    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"claims" : @"{\"id_token\":{\"given_name\":{\"essential\":true}}}",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : parameters.correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"prompt" : @"login",
                                          @"haschrome" : @"1",
                                          @"scope" : @"scope1",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new],
                                          @"code_challenge_method" : @"S256",
                                          @"code_challenge" : pkce.codeChallenge,
                                          @"X-AnchorMailbox" : [MSIDTestRequireValueSentinel new],
                                          }];
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
#if TARGET_OS_IPHONE
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_DUNA_CBA])
    {
        expectedQPs[@"switch_browser"] = @"1";
    }
#endif
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testWebViewConfiguration_whenNonPreferredNetworkAuthorityProvided_shouldSetPreferredAuthorityToConfiguration
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.microsoftonline.com";
    [cache setObject:record forKey:@"login.windows.net"];

    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];

    MSIDAuthority *authority = [@"https://login.windows.net/common" aadAuthority];
    MSIDOpenIdProviderMetadata *metadata = [MSIDOpenIdProviderMetadata new];
    metadata.authorizationEndpoint = [NSURL URLWithString:@"https://login.windows.net/contoso.com/mypath/oauth/authorize"];
    authority.metadata = metadata;
    
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority = authority;

    MSIDAuthorizeWebRequestConfiguration *configuration = [factory authorizeWebRequestConfigurationWithRequestParameters:parameters];
    XCTAssertNotNil(configuration);
    XCTAssertEqualObjects(configuration.endRedirectUrl, parameters.redirectUri);
    
    NSURLComponents *startURLComponents = [NSURLComponents componentsWithURL:configuration.startURL resolvingAgainstBaseURL:NO];
    startURLComponents.query = nil;
    
    NSURL *expectedAuthorizationEndpoint = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com/mypath/oauth/authorize"];
    XCTAssertEqualObjects(startURLComponents.URL, expectedAuthorizationEndpoint);
}

- (void)testAuthorizationParametersFromParameters_withInstanceAwareFlagSet_shouldSetInstanceAwareTrue
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.instanceAware = YES;
    
    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];
    
    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];

    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : parameters.correlationId.UUIDString,
                                          @"instance_aware" : @"true",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"haschrome" : @"1",
                                          @"scope" : @"scope1",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new],
                                          @"code_challenge_method" : @"S256",
                                          @"code_challenge" : pkce.codeChallenge
                                          }];
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
#if TARGET_OS_IPHONE
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_SUPPORT_DUNA_CBA])
    {
        expectedQPs[@"switch_browser"] = @"1";
    }
#endif
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testResponseWithURL_whenURLSchemeMsauthAndHostWPJ_shouldReturnWPJResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=link"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
}

- (void)testResponseWithURL_whenURLSchemeMsauthAndHostUpgradeReg_shouldReturnUpgradeRegResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    NSString *responseUrl = @"msauth://upgradeReg?username=XXX@upn.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0";
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:responseUrl]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    MSIDWebUpgradeRegResponse *upgradeResponse = (MSIDWebUpgradeRegResponse *)response;
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
    XCTAssertNil(error);
}

- (void)testResponseWithURL_whenURLSchemeMsauthAndHostUpgradeRegWithDifferentCapitalLetters_shouldReturnUpgradeRegResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    NSString *responseUrl = @"msauth://UpGrAdEreg?username=XXX@upn.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0";
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:responseUrl]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    MSIDWebUpgradeRegResponse *upgradeResponse = (MSIDWebUpgradeRegResponse *)response;
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
    XCTAssertNil(error);
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_shouldReturnWPJResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"msauth.com.microsoft.myapp://auth/msauth/wpj?app_link=app.link&username=XXX@upn.com&token_protection_required=true"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertTrue(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_withStrongerAuthFalse_shouldReturnUseStrongerAuthFalse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"msauth.com.microsoft.myapp://auth/msauth/wpj?app_link=app.link&username=XXX@upn.com&token_protection_required=false"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertFalse(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_withStrongerAuthEqualsTRUE_shouldReturnUseStrongerAuthFalse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"msauth.com.microsoft.myapp://auth/msauth/wpj?app_link=app.link&username=XXX@upn.com&token_protection_required=TRUE"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertFalse(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_withStrongerAuthNotExist_shouldReturnUseStrongerAuthFalse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"msauth.com.microsoft.myapp://auth/msauth/wpj?app_link=app.link&username=XXX@upn.com"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertFalse(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenBrokerUpgradeRegResponseInSystemBrowser_shouldReturnUpgradeRegResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"msauth.com.microsoft.myapp://auth/msauth/upgradeReg?username=XXX@upn.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebUpgradeRegResponse *upgradeResponse = (MSIDWebUpgradeRegResponse *)response;
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_andLocalhostRedirectUri_shouldReturnWPJResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"https://localhost/msauth/wpj?app_link=app.link&username=XXX@upn.com&token_protection_required=true"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertTrue(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenBrokerUpgradeResponseInSystemBrowser_andLocalhostRedirectUri_shouldReturnUpgradeRegResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"https://localhost/msauth/upgradeReg?username=XXX@upn.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebUpgradeRegResponse *upgradeResponse = (MSIDWebUpgradeRegResponse *)response;
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
}

- (void)testResponseWithURL_whenBrokerUpgradeWithDifferentCasesInSystemBrowser_andLocalhostRedirectUri_shouldReturnUpgradeRegResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"https://localhost/msauth/uPgRaderEg?username=XXX@upn.com&client_info=eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebUpgradeRegResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebUpgradeRegResponse *upgradeResponse = (MSIDWebUpgradeRegResponse *)response;
    XCTAssertEqualObjects(upgradeResponse.upn, @"XXX@upn.com");
    XCTAssertNotNil(upgradeResponse.clientInfo, @"clientInfo should be valid");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.uid, @"9f4880d8-80ba-4c40-97bc-f7a23c703084");
    XCTAssertEqualObjects(upgradeResponse.clientInfo.utid, @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca");
}

- (void)testResponseWithURL_whenBrokerInstallResponseInSystemBrowser_andRedirectUriEndingInSlash_shouldReturnWPJResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:@"https://localhost//msauth/wpj?app_link=app.link&username=XXX@upn.com&token_protection_required=true"];
    __auto_type response = [factory oAuthResponseWithURL:url requestState:nil ignoreInvalidState:YES endRedirectUri:nil context:nil error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJResponse.class]);
    XCTAssertNil(error);
    
    MSIDWebWPJResponse *wpjResponse = (MSIDWebWPJResponse *)response;
    XCTAssertEqualObjects(wpjResponse.appInstallLink, @"app.link");
    XCTAssertEqualObjects(wpjResponse.upn, @"XXX@upn.com");
    XCTAssertTrue(wpjResponse.tokenProtectionRequired);
}

- (void)testResponseWithURL_whenURLSchemeNotMsauth_shouldReturnAADAuthResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode&cloud_instance_host_name=somename"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebAADAuthCodeResponse.class]);
    XCTAssertNil(error);
}


- (void)testResponseWithURL_whenURLSchemeBrowser_shouldReturnBrowserResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"browser://somehost"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebOpenBrowserResponse.class]);
    XCTAssertNil(error);
}

- (void)testAuthorizationParametersFromParameters_whenNestedAuthParametersMissing_shouldNotBeIncluded
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];

    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.instanceAware = YES;
    parameters.nestedAuthBrokerClientId = nil;
    parameters.nestedAuthBrokerRedirectUri = nil;

    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];

    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];

    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_CLIENT_ID]);
    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_REDIRECT_URI]);
}

- (void)testAuthorizationParametersFromParameters_whenNestedAuthParametersIncomplete1_shouldNotBeIncluded
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];

    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.instanceAware = YES;
    parameters.nestedAuthBrokerClientId = @"123-456-7890-123";
    parameters.nestedAuthBrokerRedirectUri = nil;

    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];

    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];

    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_CLIENT_ID]);
    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_REDIRECT_URI]);
}

- (void)testAuthorizationParametersFromParameters_whenNestedAuthParametersIncomplete2_shouldNotBeIncluded
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];

    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.instanceAware = YES;
    parameters.nestedAuthBrokerClientId = nil;
    parameters.nestedAuthBrokerRedirectUri = @"msauth.com.app.id://auth";

    NSString *requestState = @"state";
    MSIDPkce *pkce = [MSIDPkce new];

    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];

    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_CLIENT_ID]);
    XCTAssertFalse([[params allKeys] containsObject:MSID_NESTED_AUTH_BROKER_REDIRECT_URI]);
}

- (void)testWebViewConfiguration_whenNestedAuth_shouldSetEndUrlToNestedRedirectUri
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.microsoftonline.com";
    [cache setObject:record forKey:@"login.windows.net"];

    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];

    MSIDAuthority *authority = [@"https://login.windows.net/common" aadAuthority];
    MSIDOpenIdProviderMetadata *metadata = [MSIDOpenIdProviderMetadata new];
    metadata.authorizationEndpoint = [NSURL URLWithString:@"https://login.windows.net/contoso.com/mypath/oauth/authorize"];
    authority.metadata = metadata;

    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.authority = authority;
    parameters.nestedAuthBrokerClientId = @"123-456-7890-123";
    parameters.nestedAuthBrokerRedirectUri = @"msauth.com.app.id://auth";

    MSIDAuthorizeWebRequestConfiguration *configuration = [factory authorizeWebRequestConfigurationWithRequestParameters:parameters];
    XCTAssertNotNil(configuration);
    XCTAssertEqualObjects(configuration.endRedirectUrl, parameters.nestedAuthBrokerRedirectUri);
}

#if AD_BROKER
- (void)testResponseWithURL_whenReceivedSSONonceRedirect_shouldReturnError
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/authorize?response_type=code&redirect_uri=msauth.com.microsoft.SomeApp%3A%2F%2Fauth&sso_nonce=SERVER_SSO_NONCE"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertNotNil(error.userInfo);
    XCTAssertNotNil(MSID_SSO_NONCE_QUERY_PARAM_KEY);
    XCTAssertNotNil(error.userInfo[MSID_SSO_NONCE_QUERY_PARAM_KEY]);
    XCTAssertEqualObjects(error.userInfo[MSID_SSO_NONCE_QUERY_PARAM_KEY], @"SERVER_SSO_NONCE");
}

- (void)testResponseWithURL_whenReceivedRetryUrlButInvalidStatus_shouldReturnNilAndErrorJITRetryRequired
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"msauth://compliance_status?status=7854"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorJITUnknownStatusWebCP);
}

- (void)testResponseWithURL_whenReceivedRetryUrl_shouldReturnNilAndErrorJITRetryRequired
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory oAuthResponseWithURL:[NSURL URLWithString:@"msauth://compliance_status?status=4"]
                                            requestState:nil
                                      ignoreInvalidState:NO
                                          endRedirectUri:nil
                                                 context:nil
                                                   error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorJITRetryRequired);
}

#endif
@end
