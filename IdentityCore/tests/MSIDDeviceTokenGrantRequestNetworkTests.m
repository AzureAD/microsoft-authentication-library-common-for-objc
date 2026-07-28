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
#import "MSIDDeviceTokenGrantRequest.h"
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDRequestParameters.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDExternalSSOContextMock.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDAADAuthority.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "NSData+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "MSIDError.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestIdTokenUtil.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDHttpRequestProtocol.h"
#import "MSIDRequestContext.h"
#import "MSIDDeviceTokenGrantRequestMock.h"

#pragma mark - Tests

@interface MSIDDeviceTokenGrantRequestNetworkTests : XCTestCase

@property (nonatomic) NSURL *testEndpoint;
@property (nonatomic) MSIDRequestParameters *defaultRequestParameters;
@property (nonatomic) MSIDWPJKeyPairWithCertMock *mockRegistrationInfo;
@property (nonatomic) MSIDDeviceTokenResponseHandler *defaultResponseHandler;
@property (nonatomic) SecKeyRef eccPrivateKey;

@end

@implementation MSIDDeviceTokenGrantRequestNetworkTests

- (void)setUp
{
    [super setUp];
    [MSIDTestURLSession clearResponses];

    self.testEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];

    self.defaultRequestParameters = [MSIDRequestParameters new];
    self.defaultRequestParameters.clientId = @"test-client-id";
    self.defaultRequestParameters.redirectUri = @"msauth.com.test://auth";
    self.defaultRequestParameters.authScheme = [MSIDAuthenticationScheme new];
    self.defaultRequestParameters.correlationId = [NSUUID UUID];
    self.defaultRequestParameters.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                                          rawTenant:nil
                                                                            context:nil
                                                                              error:nil];

    NSData *mockCertData = [NSData msidDataFromBase64UrlEncodedString:[self dummyEccCertificate]];
    MSIDTestSecureEnclaveKeyPairGenerator *keyGen = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:@"test" useSecureEnclave:NO applicationTag:@"test"];
    SecCertificateRef mockCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)mockCertData);
    self.eccPrivateKey = keyGen.eccPrivateKey;
    self.mockRegistrationInfo = [[MSIDWPJKeyPairWithCertMock alloc] initWithPrivateKey:self.eccPrivateKey certificate:mockCert certificateIssuer:@"some-issuer"];

    __auto_type factory = [MSIDAADV2Oauth2Factory new];
    self.defaultResponseHandler = [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:self.defaultRequestParameters
                                                                                       oauthFactory:factory];
}

- (void)tearDown
{
    self.testEndpoint = nil;
    self.defaultRequestParameters = nil;
    self.mockRegistrationInfo = nil;
    self.defaultResponseHandler = nil;
    [MSIDTestURLSession clearResponses];

    [super tearDown];
}

- (MSIDDeviceTokenGrantRequestMock *)mockRequest
{
    MSIDDeviceTokenGrantRequestMock *request = [[MSIDDeviceTokenGrantRequestMock alloc] initWithEndpoint:self.testEndpoint
                                                                                      requestParameters:self.defaultRequestParameters
                                                                                                 scopes:@"scope1 scope2"
                                                                                registrationInformation:self.mockRegistrationInfo
                                                                                               resource:@"https://graph.microsoft.com"
                                                                                           enrollmentId:@"enrollment-id"
                                                                                        extraParameters:nil
                                                                                             ssoContext:nil
                                                                                   tokenResponseHandler:self.defaultResponseHandler
                                                                                                  error:nil];
    request.nonce = @"test-nonce";
    return request;
}

#pragma mark - sendWithBlock: error path

- (void)testExecuteRequest_whenSendWithBlockReturnsError_shouldCallCompletionBlockWithSameError
{
    // Arrange
    MSIDDeviceTokenGrantRequestMock *request = [self mockRequest];
    XCTAssertNotNil(request);

    NSError *networkError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerUnhandledResponse, @"Simulated network failure", nil, nil, nil, nil, nil, YES);
    request.expectedResponse = nil;
    request.expectedError = networkError;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    __block NSError *capturedError = nil;
    __block MSIDTokenResult *capturedResult = nil;

    // Act
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        capturedResult = result;
        capturedError = error;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Assert
    XCTAssertTrue(request.sendWithBlockCalled);
    XCTAssertNil(capturedResult);
    XCTAssertNotNil(capturedError);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
    XCTAssertEqual(capturedError.code, MSIDErrorServerUnhandledResponse);
}

#pragma mark - sendWithBlock: success path

- (void)testExecuteRequest_whenSendWithBlockReturnsValidResponse_shouldCallCompletionBlockWithTokenResult
{
    // Arrange
    MSIDDeviceTokenGrantRequestMock *request = [self mockRequest];
    XCTAssertNotNil(request);

    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID } msidBase64UrlJson];
    NSDictionary *tokenResponse = @{
        MSID_OAUTH2_TOKEN_TYPE : @"Bearer",
        MSID_OAUTH2_ACCESS_TOKEN : @"test-device-access-token",
        MSID_OAUTH2_EXPIRES_IN : @"3600",
        MSID_OAUTH2_SCOPE : @"scope1 scope2",
        MSID_OAUTH2_CLIENT_INFO : clientInfoString,
        MSID_OAUTH2_ID_TOKEN : [MSIDTestIdTokenUtil defaultV2IdToken]
    };
    request.expectedResponse = tokenResponse;
    request.expectedError = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    __block NSError *capturedError = nil;
    __block MSIDTokenResult *capturedResult = nil;

    // Act
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        capturedResult = result;
        capturedError = error;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Assert
    XCTAssertTrue(request.sendWithBlockCalled);
    XCTAssertNil(capturedError);
    XCTAssertNotNil(capturedResult);
    XCTAssertEqualObjects(capturedResult.accessToken.accessToken, @"test-device-access-token");
}

#pragma mark - sendWithBlock: malformed response

- (void)testExecuteRequest_whenSendWithBlockReturnsResponseWithoutClientInfo_shouldCallCompletionBlockWithError
{
    // Arrange
    MSIDDeviceTokenGrantRequestMock *request = [self mockRequest];
    XCTAssertNotNil(request);

    // Missing client_info causes AAD v2 response verification to fail.
    NSDictionary *malformedResponse = @{
        MSID_OAUTH2_TOKEN_TYPE : @"Bearer",
        MSID_OAUTH2_ACCESS_TOKEN : @"test-device-access-token",
        MSID_OAUTH2_EXPIRES_IN : @"3600",
        MSID_OAUTH2_SCOPE : @"scope1 scope2"
    };
    request.expectedResponse = malformedResponse;
    request.expectedError = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
    __block NSError *capturedError = nil;
    __block MSIDTokenResult *capturedResult = nil;

    // Act
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        capturedResult = result;
        capturedError = error;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Assert
    XCTAssertTrue(request.sendWithBlockCalled);
    XCTAssertNil(capturedResult);
    XCTAssertNotNil(capturedError);
    XCTAssertEqualObjects(capturedError.domain, MSIDErrorDomain);
}

#pragma mark - Helpers

- (NSString *)dummyEccCertificate
{
    return  @"MIIDNzCCAh-gAwIBAgIQKBcXojifRIxLIuut33ZknzANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTIzMDMxMzIxMjk0OFoXDTMzMDMxMzIxNTk0OFowLzEtMCsGA1UEAxMkOWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRiMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEl-xbT_nXgQkkzQOX7NPrvh9vPMt7yrzLqBthSpZXuIjV77izK_GW91qHTzZImhwbvXG6AcVH9Qs7ilN-VIb9xaOB0DCBzTAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB_wQMMAoGCCsGAQUFBwMCMA4GA1UdDwEB_wQEAwIHgDAiBgsqhkiG9xQBBYIcAgQTBIEQo8MK5pvg9k-6UZTxtj7IITAiBgsqhkiG9xQBBYIcAwQTBIEQj-LgHz1F-kSyqt3J40Sn7zAiBgsqhkiG9xQBBYIcBQQTBIEQkq1F9o3jGk21ENGwmnSoyjAUBgsqhkiG9xQBBYIcCAQFBIECTkEwEwYLKoZIhvcUAQWCHAcEBASBATAwDQYJKoZIhvcNAQELBQADggEBAFYbeUHpPcZj6Z8BcPhQ59dOi3-aGSYKX6Ub6GBv1CgiqU9EJ-P6VOipCL5dR458nMXJ4j97_pOXwPT0sS1rSTJ8_x3YpGLIJXpvkqDEHIoUvX1sR1tOlvXhUiP0O6l35-sil1itUZAKqS7RZtd8TWnMIgw3rCHbDHA9OlagunL6o75YC5Y74VdedZbCUjTy-IuU_VKM5gpa3c6uf_QleYgdQFlDjMH9w4TkqaWNONNoYulLZI8AykT9QtYB0iAsFr4KRL58ot1svOhqMil9vKDTkDrixEyThCcHmyyHeNoBjmXtaubOAiE3cMoJs7bV7I1uOS9aAI-Hm0W9NV-CkeE";
}

@end
