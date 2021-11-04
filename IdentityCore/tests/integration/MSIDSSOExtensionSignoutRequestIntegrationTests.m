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
#if MSID_ENABLE_SSO_EXTENSION

#import "MSIDSSOExtensionSignoutRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDSSOExtensionSignoutRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"
#import "NSDictionary+MSIDQueryItems.h"

#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MSIDSSOExtensionSignoutRequestIntegrationTests : XCTestCase

@end

@implementation MSIDSSOExtensionSignoutRequestIntegrationTests

- (void)testExecuteRequest_whenNoAccountIdentifier_shouldReturnNilAndFillError
{
    MSIDInteractiveRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.accountIdentifier = nil;
    
    MSIDSSOExtensionSignoutRequest *request = [[MSIDSSOExtensionSignoutRequest alloc] initWithRequestParameters:params
                                                                                       shouldSignoutFromBrowser:YES
                                                                                              shouldWipeAccount:NO
                                                                                       clearSSOExtensionCookies:NO
                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]];
    XCTAssertNotNil(request);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorMissingAccountParameter);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

#if TARGET_OS_IPHONE

- (void)testExecuteRequest_whenCouldntCreateRequestJSON_shouldReturnNilAndFillError
{
    MSIDInteractiveRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.authority = nil;
    params.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    
    MSIDSSOExtensionSignoutRequest *request = [[MSIDSSOExtensionSignoutRequest alloc] initWithRequestParameters:params
                                                                                       shouldSignoutFromBrowser:YES
                                                                                              shouldWipeAccount:NO
                                                                                       clearSSOExtensionCookies:NO
                                                                                                   oauthFactory:[MSIDAADV2Oauth2Factory new]];
    XCTAssertNotNil(request);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testExecuteRequest_whenCancelledErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    MSIDSSOExtensionSignoutRequestMock *request = [self defaultSignoutRequestWithAuthorizationControllerMock:authorizationControllerMock];
    XCTAssertNotNil(request);
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorUserCancel);
        
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSError *error = [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorCanceled userInfo:nil];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithError:error];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    MSIDSSOExtensionSignoutRequestMock *request = [self defaultSignoutRequestWithAuthorizationControllerMock:authorizationControllerMock];
    XCTAssertNotNil(request);
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
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

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_shouldReturnResultAndNilError
{
    MSIDInteractiveRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    
    MSIDSSOExtensionSignoutRequestMock *request = [[MSIDSSOExtensionSignoutRequestMock alloc] initWithRequestParameters:params
                                                                                               shouldSignoutFromBrowser:YES
                                                                                                      shouldWipeAccount:YES
                                                                                               clearSSOExtensionCookies:NO
                                                                                                           oauthFactory:[MSIDAADV2Oauth2Factory new]];
    
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertTrue(success);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *requestDictionary = [NSDictionary msidDictionaryFromQueryItems:authorizationControllerMock.request.authorizationOptions];
    XCTAssertEqualObjects(requestDictionary[@"wipe_account"], @"1");
    XCTAssertEqualObjects(requestDictionary[@"signout_from_browser"], @"1");
    XCTAssertEqualObjects(requestDictionary[@"clear_sso_extension_cookies"], @"0");
    
    NSDictionary *responseHeaders = @{
        @"client_app_version": @"1.0",
        @"operation_response_type": @"operation_generic_response",
        @"success": @"1",
        @"operation": @"signout_account_operation",
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseHeaders];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (MSIDSSOExtensionSignoutRequestMock *)defaultSignoutRequestWithAuthorizationControllerMock:(MSIDAuthorizationControllerMock *)mock
{
    MSIDInteractiveRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
    
    MSIDSSOExtensionSignoutRequestMock *request = [[MSIDSSOExtensionSignoutRequestMock alloc] initWithRequestParameters:params
                                                                                               shouldSignoutFromBrowser:YES
                                                                                                      shouldWipeAccount:NO
                                                                                               clearSSOExtensionCookies:NO
                                                                                                           oauthFactory:[MSIDAADV2Oauth2Factory new]];
    
    XCTAssertNotNil(request);
    
    request.authorizationControllerToReturn = mock;
    return request;
}

#endif

@end

#endif
