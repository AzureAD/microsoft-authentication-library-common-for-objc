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
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"

@interface MSIDDeviceTokenGrantRequestTests : XCTestCase

@property (nonatomic) NSURL *testEndpoint;
@property (nonatomic) MSIDRequestParameters *defaultRequestParameters;
@property (nonatomic) MSIDWPJKeyPairWithCertMock *mockRegistrationInfo;
@property (nonatomic) MSIDDeviceTokenResponseHandler *defaultResponseHandler;
@property (nonatomic) SecKeyRef eccPrivateKey;

@end

@implementation MSIDDeviceTokenGrantRequestTests

- (void)setUp
{
    [super setUp];

    self.testEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];

    self.defaultRequestParameters = [MSIDRequestParameters new];
    self.defaultRequestParameters.clientId = @"test-client-id";
    self.defaultRequestParameters.redirectUri = @"msauth.com.test://auth";
    self.defaultRequestParameters.authScheme = [MSIDAuthenticationScheme new];
    self.defaultRequestParameters.correlationId = [NSUUID UUID];
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

    [super tearDown];
}

#pragma mark - init: registrationInformation validation

- (void)testInit_whenRegistrationInformationIsNil_shouldReturnNil
{
    MSIDWPJKeyPairWithCert *nilReg;
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:nilReg
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:@"enrollment-id"
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

#pragma mark - init: clientId validation

- (void)testInit_whenClientIdIsNil_shouldReturnNil
{
    // Arrange
    self.defaultRequestParameters.clientId = nil;

    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

- (void)testInit_whenClientIdIsEmptyString_shouldReturnNil
{
    // Arrange
    self.defaultRequestParameters.clientId = @"";

    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

#pragma mark - init: resource validation

- (void)testInit_whenResourceIsNil_shouldReturnNil
{
    NSString *nilResource = nil;
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:nilResource
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

- (void)testInit_whenResourceIsEmptyString_shouldReturnNil
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@""
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

#pragma mark - init: redirectUri validation

- (void)testInit_whenRedirectUriIsNil_shouldReturnNil
{
    // Arrange
    self.defaultRequestParameters.redirectUri = nil;

    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

- (void)testInit_whenRedirectUriIsEmptyString_shouldReturnNil
{
    // Arrange
    self.defaultRequestParameters.redirectUri = @"";

    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

#pragma mark - init: scopes validation

- (void)testInit_whenScopesIsNil_shouldReturnNil
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:nil
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

- (void)testInit_whenScopesContainsAza_shouldReturnNil
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 aza scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNil(request);
}

#pragma mark - init: valid parameters

- (void)testInit_whenAllParametersAreValid_shouldReturnNonNilRequest
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:@"enrollment-id"
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(request.wpjInfo, self.mockRegistrationInfo);
}

- (void)testInit_whenEnrollmentIdIsNil_shouldReturnNonNilRequest
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNotNil(request);
}

- (void)testInit_whenExtraParametersProvided_shouldReturnNonNilRequest
{
    // Arrange
    NSDictionary *extraParams = @{@"extra_key": @"extra_value"};

    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"scope1 scope2"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:@"enrollment-id"
                                                                                extraParameters:extraParams
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNotNil(request);
}

- (void)testInit_whenSingleScope_shouldReturnNonNilRequest
{
    // Act
    MSIDDeviceTokenGrantRequest *request = [[MSIDDeviceTokenGrantRequest alloc] initWithEndpoint:self.testEndpoint
                                                                              requestParameters:self.defaultRequestParameters
                                                                                         scopes:@"openid"
                                                                        registrationInformation:self.mockRegistrationInfo
                                                                                       resource:@"https://graph.microsoft.com"
                                                                                   enrollmentId:nil
                                                                                extraParameters:nil
                                                                                     ssoContext:nil
                                                                           tokenResponseHandler:self.defaultResponseHandler
                                                                                          error:nil];

    // Assert
    XCTAssertNotNil(request);
}

- (NSString *)dummyEccCertificate
{
    return  @"MIIDNzCCAh-gAwIBAgIQKBcXojifRIxLIuut33ZknzANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTIzMDMxMzIxMjk0OFoXDTMzMDMxMzIxNTk0OFowLzEtMCsGA1UEAxMkOWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRiMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEl-xbT_nXgQkkzQOX7NPrvh9vPMt7yrzLqBthSpZXuIjV77izK_GW91qHTzZImhwbvXG6AcVH9Qs7ilN-VIb9xaOB0DCBzTAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB_wQMMAoGCCsGAQUFBwMCMA4GA1UdDwEB_wQEAwIHgDAiBgsqhkiG9xQBBYIcAgQTBIEQo8MK5pvg9k-6UZTxtj7IITAiBgsqhkiG9xQBBYIcAwQTBIEQj-LgHz1F-kSyqt3J40Sn7zAiBgsqhkiG9xQBBYIcBQQTBIEQkq1F9o3jGk21ENGwmnSoyjAUBgsqhkiG9xQBBYIcCAQFBIECTkEwEwYLKoZIhvcUAQWCHAcEBASBATAwDQYJKoZIhvcNAQELBQADggEBAFYbeUHpPcZj6Z8BcPhQ59dOi3-aGSYKX6Ub6GBv1CgiqU9EJ-P6VOipCL5dR458nMXJ4j97_pOXwPT0sS1rSTJ8_x3YpGLIJXpvkqDEHIoUvX1sR1tOlvXhUiP0O6l35-sil1itUZAKqS7RZtd8TWnMIgw3rCHbDHA9OlagunL6o75YC5Y74VdedZbCUjTy-IuU_VKM5gpa3c6uf_QleYgdQFlDjMH9w4TkqaWNONNoYulLZI8AykT9QtYB0iAsFr4KRL58ot1svOhqMil9vKDTkDrixEyThCcHmyyHeNoBjmXtaubOAiE3cMoJs7bV7I1uOS9aAI-Hm0W9NV-CkeE";
}

@end
