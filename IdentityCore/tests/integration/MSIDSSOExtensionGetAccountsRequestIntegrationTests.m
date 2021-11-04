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
#import "MSIDSSOExtensionGetAccountsRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSSOExtensionGetAccountsRequestMock.h"
#import "MSIDAuthorizationControllerMock.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationSingleSignOnCredentialMock.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MSIDSSOExtensionGetAccountsRequestIntegrationTests : XCTestCase

@end

@implementation MSIDSSOExtensionGetAccountsRequestIntegrationTests

#if TARGET_OS_IPHONE

- (void)testExecuteRequest_whenCouldntCreateRequestJSON_shouldReturnNilAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    params.clientId = nil;
    
    NSError *error;
    MSIDSSOExtensionGetAccountsRequest *request = [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:&error];
    XCTAssertNotNil(request);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertNotNil(error);
        XCTAssertNil(accounts);
        XCTAssertFalse(returnBrokerAccountsOnly);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
        
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testExecuteRequest_whenErrorResponseFromSSOExtension_shouldReturnNilResultAndFillError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetAccountsRequestMock *request = [[MSIDSSOExtensionGetAccountsRequestMock alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertFalse(returnBrokerAccountsOnly);
        XCTAssertNil(accounts);
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

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withNoAccounts_shouldReturnEmptyResultAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetAccountsRequestMock *request = [[MSIDSSOExtensionGetAccountsRequestMock alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertFalse(returnBrokerAccountsOnly);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 0);
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    XCTAssertNotNil(authorizationControllerMock.delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_accounts_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"accounts": @""
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withAccountsPresent_shouldReturnNonEmptyResultAndNilError
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetAccountsRequestMock *request = [[MSIDSSOExtensionGetAccountsRequestMock alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertFalse(returnBrokerAccountsOnly);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 2);
        MSIDAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
        MSIDAccount *secondAccount = accounts[1];
        XCTAssertEqualObjects(secondAccount.accountIdentifier.homeAccountId, @"uid.utid");
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    XCTAssertNotNil(delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSArray *accounts = @[
        @{
            @"home_account_id" : @"uid.utid",
            @"account_type" : @"MSSTS",
            @"alternative_account_id" : @"AltID",
            @"client_info" : @"eyJrZXkiOiJ2YWx1ZSJ9",
            @"environment" : @"login.microsoftonline.com",
            @"family_name" : @"Last",
            @"given_name" : @"Eric",
            @"local_account_id" : @"local",
            @"middle_name" : @"Middle",
            @"name" : @"Eric Middle Last",
            @"realm" : @"common",
            @"storage_environment" : @"login.windows2.net",
            @"username" : @"username",
        },
        @{
            @"home_account_id" : @"uid.utid",
            @"account_type" : @"MSSTS",
            @"alternative_account_id" : @"AltID",
            @"client_info" : @"eyJrZXkiOiJ2YWx1ZSJ9",
            @"environment" : @"login.microsoftonline.com",
            @"family_name" : @"Last",
            @"given_name" : @"Eric",
            @"local_account_id" : @"local",
            @"middle_name" : @"Middle",
            @"name" : @"Eric Middle Last",
            @"realm" : @"tenant",
            @"storage_environment" : @"login.windows2.net",
            @"username" : @"username",
        }
    ];
    
    NSString *jsonAccountsString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:accounts options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_accounts_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"personal",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"accounts": jsonAccountsString
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenSuccessResponseFromSSOExtension_withAccountPresent_andSharedDevice_shouldReturnNonEmptyResultAndNilError_andReturnBrokerAccountsOnlyYES
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetAccountsRequestMock *request = [[MSIDSSOExtensionGetAccountsRequestMock alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertTrue(returnBrokerAccountsOnly);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        MSIDAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.accountIdentifier.homeAccountId, @"uid.utid");
        XCTAssertNil(error);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    XCTAssertNotNil(delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSArray *accounts = @[
        @{
            @"home_account_id" : @"uid.utid",
            @"account_type" : @"MSSTS",
            @"alternative_account_id" : @"AltID",
            @"client_info" : @"eyJrZXkiOiJ2YWx1ZSJ9",
            @"environment" : @"login.microsoftonline.com",
            @"family_name" : @"Last",
            @"given_name" : @"Eric",
            @"local_account_id" : @"local",
            @"middle_name" : @"Middle",
            @"name" : @"Eric Middle Last",
            @"realm" : @"common",
            @"storage_environment" : @"login.windows2.net",
            @"username" : @"username",
        }
    ];
    
    NSString *jsonAccountsString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:accounts options:0 error:nil] encoding:NSUTF8StringEncoding];
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_accounts_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"accounts": jsonAccountsString
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

- (void)testExecuteRequest_whenCorruptResponseFromSSOExtension_shouldReturnErrorFromJSONDecoder
{
    MSIDRequestParameters *params = [MSIDTestParametersProvider testInteractiveParameters];
    
    MSIDSSOExtensionGetAccountsRequestMock *request = [[MSIDSSOExtensionGetAccountsRequestMock alloc] initWithRequestParameters:params returnOnlySignedInAccounts:YES error:nil];
    XCTAssertNotNil(request);
    
    MSIDAuthorizationControllerMock *authorizationControllerMock = [[MSIDAuthorizationControllerMock alloc] initWithAuthorizationRequests:@[[[ASAuthorizationSingleSignOnProvider msidSharedProvider] createRequest]]];
    
    request.authorizationControllerToReturn = authorizationControllerMock;
    
    XCTestExpectation *expectation = [self keyValueObservingExpectationForObject:authorizationControllerMock keyPath:@"performRequestsCalledCount" expectedValue:@1];
    XCTestExpectation *executeRequestExpectation = [self expectationWithDescription:@"Execute request"];
    
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error) {
        
        XCTAssertFalse(returnBrokerAccountsOnly);
        XCTAssertNil(accounts);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
        XCTAssertEqual(error.code, 3840);
        [executeRequestExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
    __typeof__(authorizationControllerMock.delegate) delegate = authorizationControllerMock.delegate;
    XCTAssertNotNil(delegate);
    XCTAssertNotNil(authorizationControllerMock.request);
    
    NSDictionary *responseJSON = @{
        @"operation" : @"get_accounts",
        @"success" : @"1",
        @"operation_response_type" : @"operation_get_accounts_response",
        MSID_BROKER_DEVICE_MODE_KEY : @"shared",
        MSID_BROKER_WPJ_STATUS_KEY : @"joined",
        MSID_BROKER_BROKER_VERSION_KEY : @"1.2.3",
        @"accounts": @"{\\,, corrupt response}"
    };
    
    ASAuthorizationSingleSignOnCredentialMock *credential = [[ASAuthorizationSingleSignOnCredentialMock alloc] initResponseHeaders:responseJSON];
    
    ASAuthorizationMock *authorization = [[ASAuthorizationMock alloc] initWithCredential:credential];
    [delegate authorizationController:authorizationControllerMock didCompleteWithAuthorization:authorization];
    [self waitForExpectations:@[executeRequestExpectation] timeout:1];
}

#endif

@end

#endif
