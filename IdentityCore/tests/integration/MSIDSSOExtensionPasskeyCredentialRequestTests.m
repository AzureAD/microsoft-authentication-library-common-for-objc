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


#if MSID_ENABLE_SSO_EXTENSION

#import <XCTest/XCTest.h>
#import "MSIDSSOExtensionPasskeyCredentialRequest.h"
#import "MSIDPasskeyCredential.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSSOExtensionPasskeyCredentialRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"

API_AVAILABLE(macos(14.0))
@interface MSIDSSOExtensionPasskeyCredentialRequestTests : XCTestCase

@end

@implementation MSIDSSOExtensionPasskeyCredentialRequestTests

#if TARGET_OS_OSX

- (void)setUp
{
}

- (void)testExecuteRequest_whenCouldntCreateRequestJSON_shouldReturnNilAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];

    NSError *error;
    MSIDSSOExtensionPasskeyCredentialRequest *request = [[MSIDSSOExtensionPasskeyCredentialRequest alloc] initWithRequestParameters:params
                                                                                                                      correlationId:[NSUUID UUID]
                                                                                                                              error:&error];
    XCTAssertNotNil(request);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    [request executeRequestWithCompletion:^(MSIDPasskeyCredential * _Nullable passkeyCredential, NSError * _Nullable localError) {
        XCTAssertNotNil(localError);
        XCTAssertNil(passkeyCredential);
        XCTAssertEqualObjects(localError.domain, MSIDErrorDomain);
        XCTAssertEqual(localError.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientBrokerKeyCapabilityNotSupported = YES;

    MSIDSSOExtensionPasskeyCredentialRequestMock *request = [[MSIDSSOExtensionPasskeyCredentialRequestMock alloc] initWithRequestParameters:params
                                                                                                                              correlationId:[NSUUID UUID]
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];

    request.authorizationControllerToReturn = authorizationControllerMock;

    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    [request executeRequestWithCompletion:^(MSIDPasskeyCredential * _Nullable passkeyCredential, NSError * _Nullable error) {
        XCTAssertNil(passkeyCredential);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"[Get Passkey Credential] - Failed to get credential");
        
        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];

    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);

    NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"[Get Passkey Credential] - Failed to get credential", nil, nil, nil, nil, nil, NO);
    NSError *error = [NSError errorWithDomain:ASAuthorizationErrorDomain code:MSIDSSOExtensionUnderlyingError userInfo:@{NSUnderlyingErrorKey : msidError}];

    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithError:error];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withCredential_shouldReturnNonEmptyResultAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientBrokerKeyCapabilityNotSupported = YES;

    MSIDSSOExtensionPasskeyCredentialRequestMock *request = [[MSIDSSOExtensionPasskeyCredentialRequestMock alloc] initWithRequestParameters:params
                                                                                                                              correlationId:[NSUUID UUID]
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];

    request.authorizationControllerToReturn = authorizationControllerMock;

    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];

    [request executeRequestWithCompletion:^(MSIDPasskeyCredential * _Nullable passkeyCredential, NSError * _Nullable error) {
        XCTAssertNotNil(passkeyCredential);
        XCTAssertNotNil(passkeyCredential.credentialKeyId);
        XCTAssertNotNil(passkeyCredential.userHandle);
        XCTAssertNotNil(passkeyCredential.userName);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];

    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);

    NSDictionary *responseJSON = @{
        @"operation": @"passkey_credential_operation",
        @"operation_response_type": @"operation_get_passkey_credential_response",
        @"success": @"1",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
        @"userHandle": @"73616d706c6520757365722068616e646c65",
        @"userName": @"sampleUserName"
    };

    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];

    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

#endif

@end

#endif
