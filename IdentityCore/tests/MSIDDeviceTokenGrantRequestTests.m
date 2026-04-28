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

@interface MSIDDeviceTokenGrantRequestTests : XCTestCase

@property (nonatomic) NSURL *testEndpoint;
@property (nonatomic) MSIDRequestParameters *defaultRequestParameters;
@property (nonatomic) MSIDWPJKeyPairWithCertMock *mockRegistrationInfo;
@property (nonatomic) MSIDDeviceTokenResponseHandler *defaultResponseHandler;

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

    self.mockRegistrationInfo = [MSIDWPJKeyPairWithCertMock new];

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

@end
