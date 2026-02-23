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
#import "MSIDTokenResponseHandler.h"
#import "MSIDTokenResponse.h"
#import "MSIDTokenResult.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDCache.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"

@interface MSIDMockTokenResponseValidator : MSIDTokenResponseValidator

@property (nonatomic) MSIDTokenResult *mockResult;

@end

@implementation MSIDMockTokenResponseValidator

- (nullable MSIDTokenResult *)validateAndSaveTokenResponse:(nonnull MSIDTokenResponse *)tokenResponse
                                              oauthFactory:(nonnull id)factory
                                                tokenCache:(nonnull id)tokenCache
                                      accountMetadataCache:(nullable id)metadataCache
                                         requestParameters:(nonnull id)parameters
                                          saveSSOStateOnly:(BOOL)saveSSOStateOnly
                                                     error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return self.mockResult;
}

@end

@interface MSIDTokenResponseHandlerTests : XCTestCase

@property (nonatomic) MSIDTokenResponseHandler *handler;
@property (nonatomic) MSIDMockTokenResponseValidator *mockValidator;

@end

@implementation MSIDTokenResponseHandlerTests

- (void)setUp
{
    [super setUp];
    self.handler = [MSIDTokenResponseHandler new];
    self.mockValidator = [MSIDMockTokenResponseValidator new];
    self.mockValidator.mockResult = [self createMockTokenResult];
}

- (MSIDTokenResult *)createMockTokenResult
{
    MSIDAuthority *authority = [@DEFAULT_TEST_AUTHORITY aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:DEFAULT_TEST_CLIENT_ID
                                                                             target:DEFAULT_TEST_SCOPE];

    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                               responseRT:DEFAULT_TEST_REFRESH_TOKEN
                                                               responseID:nil
                                                            responseScope:DEFAULT_TEST_SCOPE
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];

    return [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                           refreshToken:nil
                                                idToken:response.idToken
                                                account:account
                                              authority:authority
                                          correlationId:[NSUUID new]
                                          tokenResponse:response];
}

#pragma mark - Tests

- (void)testHandleTokenResponse_whenClientDataIsPresent_shouldInsertClientDataIntoBrokerMetaData
{
    MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"access_token": @"at"} error:nil];
    tokenResponse.clientData = @"test_client_data";

    MSIDInteractiveTokenRequestParameters *requestParameters = [MSIDTestParametersProvider testInteractiveParameters];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion block called"];
    __block MSIDTokenResult *resultTokenResult = nil;

    [self.handler handleTokenResponse:tokenResponse
                    requestParameters:requestParameters
                        homeAccountId:nil
               tokenResponseValidator:self.mockValidator
                         oauthFactory:[MSIDAADV2Oauth2Factory new]
                           tokenCache:(id<MSIDCacheAccessor>)nil
                 accountMetadataCache:nil
                      validateAccount:NO
                     saveSSOStateOnly:NO
                     brokerAppVersion:nil
    brokerResponseGenerationTimeStamp:nil
       brokerRequestReceivedTimeStamp:nil
                                error:nil
                      completionBlock:^(MSIDTokenResult *result, NSError *error)
    {
        resultTokenResult = result;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertNotNil(resultTokenResult);
    XCTAssertEqualObjects([resultTokenResult.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA], @"test_client_data");
}

- (void)testHandleTokenResponse_whenClientDataIsNil_shouldNotInsertClientDataIntoBrokerMetaData
{
    MSIDTokenResponse *tokenResponse = [[MSIDTokenResponse alloc] initWithJSONDictionary:@{@"access_token": @"at"} error:nil];
    // clientData intentionally not set, remains nil

    MSIDInteractiveTokenRequestParameters *requestParameters = [MSIDTestParametersProvider testInteractiveParameters];

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion block called"];
    __block MSIDTokenResult *resultTokenResult = nil;

    [self.handler handleTokenResponse:tokenResponse
                    requestParameters:requestParameters
                        homeAccountId:nil
               tokenResponseValidator:self.mockValidator
                         oauthFactory:[MSIDAADV2Oauth2Factory new]
                           tokenCache:(id<MSIDCacheAccessor>)nil
                 accountMetadataCache:nil
                      validateAccount:NO
                     saveSSOStateOnly:NO
                     brokerAppVersion:nil
    brokerResponseGenerationTimeStamp:nil
       brokerRequestReceivedTimeStamp:nil
                                error:nil
                      completionBlock:^(MSIDTokenResult *result, NSError *error)
    {
        resultTokenResult = result;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertNotNil(resultTokenResult);
    XCTAssertNil([resultTokenResult.brokerMetaData objectForKey:MSID_TOKEN_RESULT_CLIENT_DATA]);
}

@end
