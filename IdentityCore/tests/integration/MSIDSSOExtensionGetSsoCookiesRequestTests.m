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
#import "MSIDSSOExtensionGetSsoCookiesRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSSOExtensionGetSsoCookiesRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDCredentialHeader.h"
#import "MSIDConstants.h"

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MSIDSSOExtensionGetSsoCookiesRequestTests : XCTestCase

@end

@implementation MSIDSSOExtensionGetSsoCookiesRequestTests

#if TARGET_OS_IPHONE

- (void)testExecuteRequest_whenCouldntCreateRequestJSON_shouldReturnNilAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    NSError *error;
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"demouser1@contoso.com" homeAccountId:@"uid.utid"];
    MSIDSSOExtensionGetSsoCookiesRequest *request = [[MSIDSSOExtensionGetSsoCookiesRequest alloc] initWithRequestParameters:params
                                                                                                              headerTypes:@[@(MSIDHeaderTypeAll)]
                                                                                                          accountIdentifier:accountIdentifier
                                                                                                                     ssoUrl:@""
                                                                                                              correlationId:[NSUUID UUID]
                                                                                                                      error:&error];
    XCTAssertNotNil(request);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    [request executeRequestWithCompletion:^(NSArray<MSIDCredentialHeader *> * _Nullable prtHeaders, NSArray<MSIDCredentialHeader *> * _Nullable deviceHeaders, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertNil(prtHeaders);
        XCTAssertNil(deviceHeaders);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"demouser1@contoso.com" homeAccountId:@"uid.utid"];
    MSIDSSOExtensionGetSsoCookiesRequestMock *request = [[MSIDSSOExtensionGetSsoCookiesRequestMock alloc] initWithRequestParameters:params
                                                                                                                      headerTypes:@[@(MSIDHeaderTypeAll)]
                                                                                                                  accountIdentifier:accountIdentifier
                                                                                                                             ssoUrl:@"https://www.contoso.com"
                                                                                                                      correlationId:[NSUUID UUID]
                                                                                                                              error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDCredentialHeader *> * _Nullable prtHeaders, NSArray<MSIDCredentialHeader *> * _Nullable deviceHeaders, NSError * _Nullable error) {
        XCTAssertNil(prtHeaders);
        XCTAssertNil(deviceHeaders);
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

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withNoSsoCookie_shouldReturnNilResultAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"demouser1@contoso.com" homeAccountId:@"uid.utid"];
    MSIDSSOExtensionGetSsoCookiesRequestMock *request = [[MSIDSSOExtensionGetSsoCookiesRequestMock alloc] initWithRequestParameters:params
                                                                                                                      headerTypes:@[@(MSIDHeaderTypeAll)]
                                                                                                                  accountIdentifier:accountIdentifier
                                                                                                                             ssoUrl:@"https://www.contoso.com"
                                                                                                                      correlationId:[NSUUID UUID]
                                                                                                                              error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDCredentialHeader *> * _Nullable prtHeaders, NSArray<MSIDCredentialHeader *> * _Nullable deviceHeaders, NSError * _Nullable error) {
        XCTAssertNil(prtHeaders);
        XCTAssertNil(deviceHeaders);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_sso_cookies_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies": @""
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withCredentialHeaderPresent_shouldReturnNonEmptyResultAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"demouser1@contoso.com" homeAccountId:@"uid.utid"];
    MSIDSSOExtensionGetSsoCookiesRequestMock *request = [[MSIDSSOExtensionGetSsoCookiesRequestMock alloc] initWithRequestParameters:params
                                                                                                                      headerTypes:@[@(MSIDHeaderTypePrt), @(MSIDHeaderTypeDeviceRegistration)]
                                                                                                                  accountIdentifier:accountIdentifier
                                                                                                                             ssoUrl:@"https://www.contoso.com"
                                                                                                                      correlationId:[NSUUID UUID]
                                                                                                                              error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDCredentialHeader *> * _Nullable prtHeaders, NSArray<MSIDCredentialHeader *> * _Nullable deviceHeaders, NSError * _Nullable error) {
        XCTAssertNotNil(prtHeaders);
        XCTAssertNotNil(deviceHeaders);
        XCTAssertEqual(prtHeaders.count, 3);
        XCTAssertEqual(deviceHeaders.count, 2);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *ssoCookies =
    @{
        @"prt_headers":
            @[
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential1": @"Base 64 Encoded JWT1"},
                  @"account_identifier": @"uid.utid1",
                  @"displayable_id": @"demo1@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential2": @"Base 64 Encoded JWT2"},
                  @"account_identifier": @"uid.utid2",
                  @"displayable_id": @"demo2@contoso.com"
              },
              @{
                  @"header": @{@"x-ms-RefreshTokenCredential3": @"Base 64 Encoded JWT3"},
                  @"account_identifier": @"uid.utid3",
                  @"displayable_id":@"demo3@contoso.com"
              }
            ],
         @"device_headers":
            @[
               @{
                  @"header": @{@"x-ms-DeviceCredential1": @"Base 64 Encoded JWT1"},
                  @"tenant_id": @"tenantId1",
               },
               @{
                  @"header": @{@"x-ms-DeviceCredential2": @"Base 64 Encoded JWT2"},
                  @"tenant_id": @"tenantId2",
               }
            ]
    };
    
    NSString *jsonSsoCookiesString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:ssoCookies options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_sso_cookies_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies": jsonSsoCookiesString
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenCorruptResponseFromSSOExtension_shouldReturnErrorFromJSONDecoder
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"demouser1@contoso.com" homeAccountId:@"uid.utid"];
    MSIDSSOExtensionGetSsoCookiesRequestMock *request = [[MSIDSSOExtensionGetSsoCookiesRequestMock alloc] initWithRequestParameters:params
                                                                                                                      headerTypes:@[@(MSIDHeaderTypeAll)]
                                                                                                                  accountIdentifier:accountIdentifier
                                                                                                                             ssoUrl:@"https://www.contoso.com"
                                                                                                                      correlationId:[NSUUID UUID]
                                                                                                                              error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDCredentialHeader *> * _Nullable prtHeaders, NSArray<MSIDCredentialHeader *> * _Nullable deviceHeaders, NSError * _Nullable error) {
        XCTAssertNil(prtHeaders);
        XCTAssertNil(deviceHeaders);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_sso_cookies",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_sso_cookies_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"sso_cookies": @"{^!&@(!)@}"
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
