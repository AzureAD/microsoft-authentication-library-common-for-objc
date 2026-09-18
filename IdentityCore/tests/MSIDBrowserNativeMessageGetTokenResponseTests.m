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
#import "MSIDClientInfo.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDTokenResponseMock : MSIDTokenResponse

@property (nonatomic) NSDictionary *responseJson;
@property (nonatomic) BOOL returnNilAccounUpn;
@property (nonatomic) NSString *accountUpnToReturn;

@end

@implementation MSIDTokenResponseMock

- (NSString *)accountUpn
{
    if (self.returnNilAccounUpn) return nil;

    if (self.accountUpnToReturn) return self.accountUpnToReturn;
    
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
        @"expires_in": @"3600",
        @"scope": @"openid profile",
        @"client_info": @"synthetic-client-info",
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

    XCTAssertEqualObjects(response.jsonDictionary, (@{
        @"future_server_field": @"synthetic-future-value",
        @"properties": @{}
    }));
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

    XCTAssertEqualObjects(response.jsonDictionary, (@{
        @"future_server_field": @"synthetic-future-value",
        @"properties": @{}
    }));
}

- (void)testJsonDictionary_whenLegacyResponseSanitizationFlightEnabled_shouldOnlyIncludeBrowserContractFields
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{@"id_token": idToken} error:nil];
    tokenResponseMock.responseJson = @{
        @"access_token": @"synthetic-access-token",
        @"client_info": @"synthetic-client-info",
        @"token_type": @"Bearer",
        @"expires_on": @"2000000000",
        @"req_cnf": @"synthetic-request-confirmation",
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
        @"client_info": @"synthetic-client-info",
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

- (void)testJsonDictionary_whenTokenResponseStateIsEmptyOrWhitespace_shouldPreserveState
{
    for (NSString *state in @[@"", @" \t "])
    {
        MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
        tokenResponseMock.responseJson = @{};
        tokenResponseMock.returnNilAccounUpn = YES;

        MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
        MSIDBrowserNativeMessageGetTokenResponse *response =
        [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                        state:state
                                                    fallbackRequestAccountUpn:nil];

        XCTAssertEqualObjects(response.jsonDictionary[@"state"], state);
    }
}

- (void)testJsonDictionary_whenTokenResponseUpnIsEmptyOrWhitespace_shouldPreserveResponseUpn
{
    for (NSString *responseUpn in @[@"", @" \t "])
    {
        MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
        tokenResponseMock.responseJson = @{};
        tokenResponseMock.accountUpnToReturn = responseUpn;

        MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
        MSIDBrowserNativeMessageGetTokenResponse *response =
        [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                        state:nil
                                                    fallbackRequestAccountUpn:@"fallback@contoso.com"];

        NSDictionary *json = response.jsonDictionary;
        XCTAssertEqualObjects(json[@"account"][@"userName"], responseUpn);
        XCTAssertEqualObjects(json[@"properties"][@"UPN"], responseUpn);
    }
}

- (void)testJsonDictionary_whenTokenResponseUpnIsNil_shouldPreserveRequestUpnFallback
{
    for (NSString *requestUpn in @[@"fallback@contoso.com", @"", @" \t "])
    {
        MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
        tokenResponseMock.responseJson = @{};
        tokenResponseMock.returnNilAccounUpn = YES;

        MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
        MSIDBrowserNativeMessageGetTokenResponse *response =
        [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                        state:nil
                                                    fallbackRequestAccountUpn:requestUpn];

        NSDictionary *json = response.jsonDictionary;
        XCTAssertEqualObjects(json[@"account"][@"userName"], requestUpn);
        XCTAssertEqualObjects(json[@"properties"][@"UPN"], requestUpn);
    }
}

- (void)testJsonDictionary_whenTokenResponseHasNoUpnOrMats_shouldIncludeEmptyProperties
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{};
    tokenResponseMock.returnNilAccounUpn = YES;

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:nil
                                                fallbackRequestAccountUpn:nil];

    NSDictionary *json = response.jsonDictionary;
    XCTAssertNotNil(json[@"properties"]);
    XCTAssertEqualObjects(json[@"properties"], @{});
    XCTAssertNil(json[@"account"][@"userName"]);
}

- (void)testJsonDictionary_whenResultHasTokenResponseAndAccessToken_shouldUseTokenResponseSemantics
{
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponseMock.responseJson = @{};
    tokenResponseMock.accountUpnToReturn = @"";

    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponseMock];
    result.accessToken = [MSIDAccessToken new];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                    state:@""
                                                fallbackRequestAccountUpn:@"fallback@contoso.com"];

    NSDictionary *json = response.jsonDictionary;
    XCTAssertEqualObjects(json[@"state"], @"");
    XCTAssertEqualObjects(json[@"account"][@"userName"], @"");
    XCTAssertEqualObjects(json[@"properties"][@"UPN"], @"");
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
    NSString *rawClientInfo = [@{@"uid": @"uid", @"utid": @"utid"} msidBase64UrlJson];
    account.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:nil];

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
    XCTAssertTrue([json[@"expires_in"] isKindOfClass:NSNumber.class]);
    XCTAssertGreaterThan([json[@"expires_in"] doubleValue], 0);
    XCTAssertEqualObjects(json[@"client_info"], rawClientInfo);
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

- (void)testJsonDictionary_whenBoundSPAAndSanitizationFlightDisabled_shouldExcludeNativeCredentials
{
    MSIDFlightManagerMockProvider *flights = [MSIDFlightManagerMockProvider new];
    flights.boolForKeyContainer = @{MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION: @NO};
    MSIDFlightManager.sharedInstance.flightProvider = flights;
    MSIDTokenResponseMock *tokenResponse = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:@{} error:nil];
    tokenResponse.responseJson = @{
        @"access_token": @"synthetic-at", @"id_token": @"synthetic-id",
        @"expires_in": @"3600", @"scope": @"User.Read", @"client_info": @"synthetic-client-info",
        @"refresh_token": @"synthetic-rt", @"foci": @"1", @"session_key": @"synthetic-key",
        @"additional_tokens": @{@"refresh_token": @"synthetic-additional-rt"}
    };
    MSIDTokenResult *result = [self tokenResultWithTokenResponse:tokenResponse];
    result.accessToken = [MSIDAccessToken new];
    result.accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:3600];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                  state:@"state"
                                              fallbackRequestAccountUpn:nil];
    response.requiresBoundTokenResponse = YES;
    NSDictionary *json = response.jsonDictionary;
    XCTAssertEqualObjects(json[@"access_token"], @"synthetic-at");
    XCTAssertEqualObjects(json[@"client_info"], @"synthetic-client-info");
    XCTAssertTrue([json[@"expires_in"] isKindOfClass:NSNumber.class]);
    XCTAssertGreaterThan([json[@"expires_in"] integerValue], 3500);
    XCTAssertLessThanOrEqual([json[@"expires_in"] integerValue], 3600);
    XCTAssertNil(json[@"refresh_token"]);
    XCTAssertNil(json[@"foci"]);
    XCTAssertNil(json[@"session_key"]);
    XCTAssertNil(json[@"additional_tokens"]);
    XCTAssertEqualObjects(json[@"state"], @"state");
}

- (void)testJsonDictionary_whenCachedTokenExpired_shouldEmitNumericZeroLifetime
{
    MSIDTokenResult *result = [MSIDTokenResult new];
    result.accessToken = [MSIDAccessToken new];
    result.accessToken.expiresOn = [NSDate dateWithTimeIntervalSince1970:1];
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:result
                                                                  state:nil fallbackRequestAccountUpn:nil];
    XCTAssertEqualObjects(response.jsonDictionary[@"expires_in"], @0);
}

@end
