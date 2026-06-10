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
#import "MSIDSSOExtensionGetDefaultAccountRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDSSOExtensionGetDefaultAccountRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConstants.h"
#import "MSIDAccount.h"
#import "MSIDJsonSerializableTypes.h"

@interface MSIDSSOExtensionGetDefaultAccountRequestTests : XCTestCase

@end

@implementation MSIDSSOExtensionGetDefaultAccountRequestTests

#if TARGET_OS_OSX

- (void)testInit_whenValidRequestParameters_shouldInitialize
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    NSError *error;
    MSIDSSOExtensionGetDefaultAccountRequest *request = [[MSIDSSOExtensionGetDefaultAccountRequest alloc] initWithRequestParameters:params
                                                                                                                               error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
}

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilAccountAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetDefaultAccountRequestMock *request = [[MSIDSSOExtensionGetDefaultAccountRequestMock alloc] initWithRequestParameters:params
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];

    [request executeRequestWithCompletion:^(MSIDAccount * _Nullable account, NSError * _Nullable error) {
        XCTAssertNil(account);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);

        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withAccount_shouldReturnAccountAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientBrokerKeyCapabilityNotSupported = YES;

    MSIDSSOExtensionGetDefaultAccountRequestMock *request = [[MSIDSSOExtensionGetDefaultAccountRequestMock alloc] initWithRequestParameters:params
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];

    request.authorizationControllerToReturn = authorizationControllerMock;

    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];

    [request executeRequestWithCompletion:^(MSIDAccount * _Nullable account, NSError * _Nullable error) {
        XCTAssertNotNil(account);
        XCTAssertNil(error);
        XCTAssertEqualObjects(account.accountIdentifier.homeAccountId, @"uid.utid");
        XCTAssertEqualObjects(account.username, @"user@contoso.com");
        XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];

    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);

    NSDictionary *responseJSON = @{
        @"operation" : @"get_default_account",
        @"success" : @"1",
        @"operation_response_type" : MSID_JSON_TYPE_BROKER_OPERATION_GET_DEFAULT_ACCOUNT_RESPONSE,
        @"home_account_id" : @"uid.utid",
        @"account_type" : @"MSSTS",
        @"environment" : @"login.microsoftonline.com",
        @"realm" : @"common",
        @"username" : @"user@contoso.com",
    };

    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];

    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withoutAccount_shouldReturnNilAccountAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientBrokerKeyCapabilityNotSupported = YES;

    MSIDSSOExtensionGetDefaultAccountRequestMock *request = [[MSIDSSOExtensionGetDefaultAccountRequestMock alloc] initWithRequestParameters:params
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];

    request.authorizationControllerToReturn = authorizationControllerMock;

    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];

    [request executeRequestWithCompletion:^(MSIDAccount * _Nullable account, NSError * _Nullable error) {
        XCTAssertNil(account);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];

    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);

    NSDictionary *responseJSON = @{
        @"operation" : @"get_default_account",
        @"success" : @"0",
        @"operation_response_type" : MSID_JSON_TYPE_BROKER_OPERATION_GET_DEFAULT_ACCOUNT_RESPONSE,
    };

    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];

    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenIncorrectResponseType_shouldReturnError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientBrokerKeyCapabilityNotSupported = YES;


    MSIDSSOExtensionGetDefaultAccountRequestMock *request = [[MSIDSSOExtensionGetDefaultAccountRequestMock alloc] initWithRequestParameters:params
                                                                                                                                      error:nil];
    XCTAssertNotNil(request);

    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];

    request.authorizationControllerToReturn = authorizationControllerMock;

    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];

    [request executeRequestWithCompletion:^(MSIDAccount * _Nullable account, NSError * _Nullable error) {
        XCTAssertNil(account);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [executeRequestExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];

    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);

    // Send wrong response type
    NSDictionary *responseJSON = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_accounts_response",
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
