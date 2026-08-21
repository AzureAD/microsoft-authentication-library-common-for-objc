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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import <XCTest/XCTest.h>
#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDFlightManagerMockProvider.h"

@interface MSIDTokenResponseMock : MSIDTokenResponse

@property (nonatomic) NSDictionary *responseJson;
@property (nonatomic) BOOL returnNilAccounUpn;

@end

@implementation MSIDTokenResponseMock

- (NSString *)accountUpn
{
    if (self.returnNilAccounUpn) return nil;
    
    return [super accountUpn];
}

- (NSDictionary *)jsonDictionary
{
    return self.responseJson;
}

@end

@interface MSIDBrowserNativeMessageGetTokenResponseTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetTokenResponseTests

- (void)tearDown
{
    MSIDFlightManager.sharedInstance.flightProvider = nil;
    [super tearDown];
}

- (MSIDTokenResult *)tokenResultWithTokenResponse:(MSIDTokenResponse *)tokenResponse
{
    MSIDTokenResult *result = [MSIDTokenResult new];
    result.tokenResponse = tokenResponse;
    return result;
}

- (void)testResponseType_shouldBeGenericResponse
{
    // We don't use this operation directly, it is wrapped by "BrokerOperationBrowserNativeMessage" operation, so we don't care about response type and return generic response.
    XCTAssertEqualObjects(@"operation_generic_response", [MSIDBrowserNativeMessageGetTokenResponse responseType]);
}

- (void)testInitWithTokenResult_whenNoAccessTokenOrTokenResponse_shouldReturnNil
{
    MSIDTokenResult *result = [MSIDTokenResult new];
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                                          state:nil
                                                                      fallbackRequestAccountUpn:nil];

    XCTAssertNil(response);
}

- (void)testJsonDictionary_whenPayloadExist_shouldBeCorrect
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    NSDictionary *jsonInput = @{@"id_token": idToken};
    
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:jsonInput error:nil];
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};
    
    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                                          state:@"1234"
                                                                      fallbackRequestAccountUpn:nil];
    
    __auto_type expectedJson = @{
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": tokenResponseMock.idTokenObj.username
        },
        @"properties": @{
            @"UPN": tokenResponseMock.idTokenObj.username
        },
        @"state": @"1234",
        @"some_key": @"some_value"
    };
    
    XCTAssertNotNil([response jsonDictionary]);
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testJsonDictionary_whenInitializedWithLegacyTokenResponse_shouldPreserveLegacyShape
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{@"id_token": idToken} error:nil];
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};

    __auto_type operationTokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
    operationTokenResponse.tokenResponse = tokenResponseMock;

    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:operationTokenResponse];
    response.state = @"1234";
    response.requestAccountUpn = @"fallback@contoso.com";

    NSDictionary *json = [response jsonDictionary];

    XCTAssertEqualObjects(json[@"some_key"], @"some_value");
    XCTAssertEqualObjects(json[@"state"], @"1234");
    XCTAssertEqualObjects(json[@"account"][@"userName"], tokenResponseMock.accountUpn);
    XCTAssertEqualObjects(json[@"account"][@"id"], tokenResponseMock.accountIdentifier);
    XCTAssertEqualObjects(json[@"properties"][@"UPN"], tokenResponseMock.accountUpn);
}

- (void)testJsonDictionary_whenResponseSanitizationFlightEnabled_shouldOnlyIncludeBrowserContractFields
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{@"id_token": idToken} error:nil];
    tokenResponseMock.responseJson = @{
        @"access_token": @"synthetic-access-token",
        @"id_token": @"synthetic-id-token",
        @"token_type": @"Bearer",
        @"expires_in": @"3600",
        @"expires_on": @"2000000000",
        @"scope": @"openid profile",
        @"req_cnf": @"synthetic-request-confirmation",
        @"refresh_token": @"synthetic-refresh-token",
        @"client_info": @"synthetic-client-info",
        @"foci": @"1",
        @"adi": @"synthetic-adi",
        @"provider_type": @"aad",
        @"future_server_field": @"synthetic-future-value"
    };

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION: @YES};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:@"synthetic-state"
                                                fallbackRequestAccountUpn:nil];

    NSDictionary *expectedJson = @{
        @"access_token": @"synthetic-access-token",
        @"id_token": @"synthetic-id-token",
        @"token_type": @"Bearer",
        @"expires_in": @"3600",
        @"expires_on": @"2000000000",
        @"scope": @"openid profile",
        @"req_cnf": @"synthetic-request-confirmation",
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": tokenResponseMock.accountUpn
        },
        @"state": @"synthetic-state",
        @"properties": @{
            @"UPN": tokenResponseMock.accountUpn
        }
    };

    XCTAssertEqualObjects(expectedJson, response.jsonDictionary);
}

- (void)testJsonDictionary_whenResponseSanitizationFlightDisabled_shouldPreserveLegacyPassthrough
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{@"future_server_field": @"synthetic-future-value"};

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:nil
                                                fallbackRequestAccountUpn:nil];

    XCTAssertEqualObjects(response.jsonDictionary, @{@"future_server_field": @"synthetic-future-value"});
}

- (void)testJsonDictionary_whenResponseSanitizationFlightIsAbsent_shouldPreserveLegacyPassthrough
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{@"future_server_field": @"synthetic-future-value"};

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:nil
                                                fallbackRequestAccountUpn:nil];

    XCTAssertEqualObjects(response.jsonDictionary, @{@"future_server_field": @"synthetic-future-value"});
}

- (void)testJsonDictionary_whenLegacyResponseSanitizationFlightEnabled_shouldOnlyIncludeBrowserContractFields
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{@"id_token": idToken} error:nil];
    tokenResponseMock.responseJson = @{
        @"access_token": @"synthetic-access-token",
        @"refresh_token": @"synthetic-refresh-token"
    };

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION: @YES};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDBrokerOperationTokenResponse *operationTokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
    operationTokenResponse.tokenResponse = tokenResponseMock;
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:operationTokenResponse];
    response.state = @"synthetic-state";

    NSDictionary *expectedJson = @{
        @"access_token": @"synthetic-access-token",
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": tokenResponseMock.accountUpn
        },
        @"state": @"synthetic-state",
        @"properties": @{
            @"UPN": tokenResponseMock.accountUpn
        }
    };

    XCTAssertEqualObjects(expectedJson, response.jsonDictionary);
}

- (void)testJsonDictionary_whenTokenResponseDictionaryIsNil_shouldReturnNil
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = nil;

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:nil
                                                fallbackRequestAccountUpn:nil];

    XCTAssertNil(response.jsonDictionary);
}

- (void)testJsonDictionary_whenNoUpnInReponse_shouldUseProvidedUpn
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    NSDictionary *jsonInput = @{@"id_token": idToken};
    
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:jsonInput error:nil];
    tokenResponseMock.returnNilAccounUpn = YES;
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};
    
    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                                          state:@"1234"
                                                                      fallbackRequestAccountUpn:@"a@b.c"];
    
    __auto_type expectedJson = @{
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": @"a@b.c"
        },
        @"properties": @{
            @"UPN": @"a@b.c"
        },
        @"state": @"1234",
        @"some_key": @"some_value"
    };
    
    XCTAssertNotNil([response jsonDictionary]);
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testInitWithTokenResultStateAndFallbackUpn_setsConvenienceProperties
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                                          state:@"state"
                                                                      fallbackRequestAccountUpn:@"user@contoso.com"];

    XCTAssertEqualObjects(response.state, @"state");
    XCTAssertEqualObjects(response.requestAccountUpn, @"user@contoso.com");
}

// Lookup / discovery mode (nativebroker_mode = Lookup) returns a token response whose access_token
// and id_token are "none". The response must NOT be gated on a materialized access token; the raw
// token response fields pass through untouched. Mirrors dev behavior, which only required a non-nil
// underlying token response payload.
- (void)testJsonDictionary_whenLookupModeAccessTokenIsNone_passesThroughWithoutGating
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{
        @"access_token": @"none",
        @"id_token": @"none",
        @"refresh_token": @"1.wqeqweqwe",
        @"token_type": @"Bearer",
        @"scope": @"https://management.core.windows.net//.default"
    };

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    // The result carries only a token response (no materialized MSIDAccessToken).
    XCTAssertNil(result.accessToken);
    XCTAssertNotNil(result.tokenResponse);

    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                                          state:@"1234"
                                                                      fallbackRequestAccountUpn:@"idlab@msidlab4.onmicrosoft.com"];

    NSDictionary *json = [response jsonDictionary];
    XCTAssertNotNil(json);
    XCTAssertEqualObjects(json[@"access_token"], @"none");
    XCTAssertEqualObjects(json[@"id_token"], @"none");
    XCTAssertEqualObjects(json[@"refresh_token"], @"1.wqeqweqwe");
    XCTAssertEqualObjects(json[@"state"], @"1234");
}

- (void)testJsonDictionary_whenAccessTokenComesFromCache_shouldBuildResponseFromResult
{
    MSIDAccessToken *accessToken = [MSIDAccessToken new];
    accessToken.accessToken = @"cached-access-token";
    accessToken.tokenType = @"Bearer";
    accessToken.scopes = [NSOrderedSet orderedSetWithArray:@[@"openid", @"profile", @"User.Read"]];
    accessToken.expiresOn = [NSDate dateWithTimeIntervalSince1970:2000000000];

    MSIDAccount *account = [MSIDAccount new];
    account.username = @"user@contoso.com";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:account.username
                                                                      homeAccountId:@"uid.utid"];

    MSIDTokenResult *result = [MSIDTokenResult new];
    result.accessToken = accessToken;
    result.rawIdToken = @"cached-id-token";
    result.account = account;

    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:@"state"
                                                fallbackRequestAccountUpn:nil];

    NSDictionary *json = [response jsonDictionary];

    XCTAssertEqualObjects(json[@"access_token"], @"cached-access-token");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"id_token"], @"cached-id-token");
    XCTAssertEqualObjects(json[@"scope"], @"openid profile User.Read");
    XCTAssertEqualObjects(json[@"expires_on"], @"2000000000");
    XCTAssertTrue([json[@"expires_in"] isKindOfClass:NSString.class]);
    XCTAssertEqualObjects(json[@"account"][@"id"], @"uid.utid");
    XCTAssertEqualObjects(json[@"account"][@"userName"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"properties"][@"UPN"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"state"], @"state");
}

- (void)testJsonDictionary_whenCachedPathWithSanitizationFlightEnabled_shouldBuildResponseFromResult
{
    MSIDAccessToken *accessToken = [MSIDAccessToken new];
    accessToken.accessToken = @"cached-access-token";
    accessToken.tokenType = @"Bearer";
    accessToken.scopes = [NSOrderedSet orderedSetWithArray:@[@"openid", @"profile"]];
    accessToken.expiresOn = [NSDate dateWithTimeIntervalSince1970:2000000000];

    MSIDAccount *account = [MSIDAccount new];
    account.username = @"user@contoso.com";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:account.username
                                                                       homeAccountId:@"uid.utid"];

    MSIDTokenResult *result = [MSIDTokenResult new];
    result.accessToken = accessToken;
    result.rawIdToken = @"cached-id-token";
    result.account = account;

    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION: @YES};
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;

    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:@"state"
                                                fallbackRequestAccountUpn:nil];

    NSDictionary *json = [response jsonDictionary];

    XCTAssertEqualObjects(json[@"access_token"], @"cached-access-token");
    XCTAssertEqualObjects(json[@"token_type"], @"Bearer");
    XCTAssertEqualObjects(json[@"id_token"], @"cached-id-token");
    XCTAssertEqualObjects(json[@"scope"], @"openid profile");
    XCTAssertEqualObjects(json[@"expires_on"], @"2000000000");
    XCTAssertTrue([json[@"expires_in"] isKindOfClass:NSString.class]);
    XCTAssertEqualObjects(json[@"account"][@"id"], @"uid.utid");
    XCTAssertEqualObjects(json[@"account"][@"userName"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"properties"][@"UPN"], @"user@contoso.com");
    XCTAssertEqualObjects(json[@"state"], @"state");
}

- (void)testJsonDictionary_whenCachedResultHasNoOptionalValues_shouldOmitEmptyFields
{
    MSIDTokenResult *result = [MSIDTokenResult new];
    result.accessToken = [MSIDAccessToken new];

    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:nil
                                                fallbackRequestAccountUpn:nil];

    XCTAssertEqualObjects([response jsonDictionary], @{});
}

@end
