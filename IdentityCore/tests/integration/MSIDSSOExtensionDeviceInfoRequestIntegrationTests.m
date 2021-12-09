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

#if MSID_ENABLE_SSO_EXTENSION

#import <XCTest/XCTest.h>
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSSOExtensionGetDeviceInfoRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"
#import "MSIDDeviceInfo.h"

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MSIDSSOExtensionDeviceInfoRequestIntegrationTests : XCTestCase

@end

@implementation MSIDSSOExtensionDeviceInfoRequestIntegrationTests

#if TARGET_OS_IPHONE

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetDeviceInfoRequestMock *request = [[MSIDSSOExtensionGetDeviceInfoRequestMock alloc] initWithRequestParameters:params error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(MSIDDeviceInfo * _Nullable deviceInfo, NSError * _Nullable error)
    {
        XCTAssertNil(deviceInfo);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Invalid param");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"invalid_grant");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"bad_token");
        
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Invalid param", @"invalid_grant", @"bad_token", nil, nil, nil, NO);
    NSError *error = [NSError errorWithDomain:ASAuthorizationErrorDomain code:MSIDSSOExtensionUnderlyingError userInfo:@{NSUnderlyingErrorKey : msidError}];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithError:error];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withSharedDeviceMode_shouldReturnDeviceInfo
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetDeviceInfoRequestMock *request = [[MSIDSSOExtensionGetDeviceInfoRequestMock alloc] initWithRequestParameters:params error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(MSIDDeviceInfo * _Nullable deviceInfo, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInfo);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInfo.deviceMode, MSIDDeviceModeShared);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    XCTAssertNotNil(delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_device_info",
        @"success" : @"1",
        @"operation_response_type" : @"operation_generic_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"nonjoined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3"
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

#endif

@end

#endif
