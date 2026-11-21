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
#import "MSIDSSOExtensionGetAccountsRequest.h"

#if MSID_ENABLE_SSO_EXTENSION
#import "MSIDRequestParameters.h"
#import "MSIDBrokerOperationGetAccountsRequest.h"
#import "MSIDBrokerOperationGetAccountsResponse.h"
#import "MSIDSSOExtensionRequestDelegate.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDDeviceInfo.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestSwizzle.h"
#import "MSIDError.h"

@interface MSIDSSOExtensionGetAccountsRequestTests : XCTestCase

@property (nonatomic) MSIDRequestParameters *parameters;
@property (nonatomic) MSIDBrokerOperationGetAccountsRequest *capturedOperation;
@property (nonatomic) MSIDBrokerNativeAppOperationResponse *operationResponse;
@property (nonatomic) NSError *operationError;
@property (nonatomic) NSError *creationError;
@property (nonatomic) MSIDSSOExtensionRequestDelegate *capturedDelegate;
@property (nonatomic) NSUInteger performCount;

@end

@implementation MSIDSSOExtensionGetAccountsRequestTests

- (void)setUp
{
    [super setUp];
    self.parameters = [MSIDRequestParameters new];
    self.parameters.clientId = @"get-accounts-test-client";
    self.parameters.correlationId = NSUUID.UUID;
    [MSIDTestSwizzle instanceMethod:@selector(createSSORequestWithOperationRequest:requestParameters:requiresUI:error:)
                              class:ASAuthorizationSingleSignOnProvider.class
                              block:^ASAuthorizationSingleSignOnRequest *(ASAuthorizationSingleSignOnProvider *provider,
                                                                          MSIDBrokerOperationRequest *operation,
                                                                          MSIDRequestParameters *parameters,
                                                                          BOOL requiresUI, NSError **error)
    {
        XCTAssertTrue([operation isKindOfClass:MSIDBrokerOperationGetAccountsRequest.class]);
        self.capturedOperation = (MSIDBrokerOperationGetAccountsRequest *)operation;
        XCTAssertEqual(parameters, self.parameters);
        XCTAssertFalse(requiresUI);
        if (self.creationError)
        {
            if (error)
            {
                *error = self.creationError;
            }
            return nil;
        }
        return [provider createRequest];
    }];
    [MSIDTestSwizzle instanceMethod:@selector(msidPerformRequests)
                              class:ASAuthorizationController.class
                              block:^(ASAuthorizationController *controller)
    {
        self.performCount++;
        id<ASAuthorizationControllerDelegate> delegate = controller.delegate;
        XCTAssertTrue([delegate isKindOfClass:MSIDSSOExtensionRequestDelegate.class]);
        self.capturedDelegate = (MSIDSSOExtensionRequestDelegate *)delegate;
        self.capturedDelegate.completionBlock(self.operationResponse, self.operationError);
    }];
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    self.capturedDelegate = nil;
    [super tearDown];
}

- (void)testInit_whenParametersMissing_returnsExplicitInvalidParameterError
{
    MSIDRequestParameters *parameters = nil;
    NSError *error = nil;
    MSIDSSOExtensionGetAccountsRequest *request =
    [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:parameters returnOnlySignedInAccounts:YES error:&error];
    XCTAssertNil(request);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqual(self.performCount, 0u);
}

- (void)testExecute_whenRequestCreationFails_forwardsOriginalErrorWithoutPerformingAuthorization
{
    self.creationError = [NSError errorWithDomain:@"sso-request-test" code:31 userInfo:nil];
    NSError *error = nil;
    MSIDSSOExtensionGetAccountsRequest *request =
    [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:self.parameters returnOnlySignedInAccounts:YES error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    __block NSUInteger completions = 0;
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> *accounts, BOOL brokerOnly, NSError *resultError)
    {
        completions++;
        XCTAssertNil(accounts);
        XCTAssertFalse(brokerOnly);
        XCTAssertEqual(resultError, self.creationError);
    }];
    XCTAssertEqual(completions, 1u);
    XCTAssertEqual(self.performCount, 0u);
    XCTAssertEqualObjects(self.capturedOperation.clientId, self.parameters.clientId);
    XCTAssertTrue(self.capturedOperation.returnOnlySignedInAccounts);
}

- (void)testExecute_success_preservesRequestedFilterAndSharedDeviceAccountBoundaryAndCompletesOnce
{
    for (NSNumber *signedInOnly in @[@YES, @NO])
    {
        for (NSNumber *sharedDevice in @[@YES, @NO])
        {
            self.performCount = 0;
            MSIDDeviceInfo *device = [MSIDDeviceInfo new];
            device.deviceMode = sharedDevice.boolValue ? MSIDDeviceModeShared : MSIDDeviceModePersonal;
            MSIDBrokerOperationGetAccountsResponse *response =
            [[MSIDBrokerOperationGetAccountsResponse alloc] initWithDeviceInfo:device];
            response.success = YES;
            MSIDAccount *account = [MSIDAccount new];
            account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"account@contoso.com"
                                                                             homeAccountId:@"account.tenant"];
            response.accounts = @[account];
            self.operationResponse = response;
            NSError *error = nil;
            MSIDSSOExtensionGetAccountsRequest *request =
            [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:self.parameters
                                                      returnOnlySignedInAccounts:signedInOnly.boolValue error:&error];
            XCTAssertNotNil(request);
            XCTAssertNil(error);
            __block NSUInteger completions = 0;
            [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> *accounts, BOOL brokerOnly, NSError *resultError)
            {
                completions++;
                XCTAssertEqualObjects(accounts, @[account]);
                XCTAssertEqual(brokerOnly, sharedDevice.boolValue);
                XCTAssertNil(resultError);
            }];
            XCTAssertEqual(completions, 1u);
            XCTAssertEqual(self.performCount, 1u);
            XCTAssertEqualObjects(self.capturedOperation.clientId, self.parameters.clientId);
            XCTAssertEqual(self.capturedOperation.returnOnlySignedInAccounts, signedInOnly.boolValue);
            self.capturedDelegate.completionBlock(response, nil);
            XCTAssertEqual(completions, 1u);
            XCTAssertEqual(request.requestParameters, self.parameters);
        }
    }
}

- (void)testExecute_whenOperationFails_forwardsOriginalErrorWithoutReturningAccounts
{
    self.operationResponse = [[MSIDBrokerOperationGetAccountsResponse alloc] initWithDeviceInfo:nil];
    self.operationResponse.success = NO;
    self.operationError = [NSError errorWithDomain:@"sso-operation-test" code:32 userInfo:nil];
    NSError *error = nil;
    MSIDSSOExtensionGetAccountsRequest *request =
    [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:self.parameters returnOnlySignedInAccounts:NO error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    __block NSUInteger completions = 0;
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> *accounts, BOOL brokerOnly, NSError *resultError)
    {
        completions++;
        XCTAssertNil(accounts);
        XCTAssertFalse(brokerOnly);
        XCTAssertEqual(resultError, self.operationError);
    }];
    XCTAssertEqual(completions, 1u);
    XCTAssertEqual(self.performCount, 1u);
}

- (void)testExecute_whenSuccessfulResponseHasWrongType_returnsExplicitInternalError
{
    self.operationResponse = [[MSIDBrokerNativeAppOperationResponse alloc] initWithDeviceInfo:nil];
    self.operationResponse.success = YES;
    NSError *error = nil;
    MSIDSSOExtensionGetAccountsRequest *request =
    [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:self.parameters returnOnlySignedInAccounts:NO error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    __block NSUInteger completions = 0;
    [request executeRequestWithCompletion:^(NSArray<MSIDAccount *> *accounts, BOOL brokerOnly, NSError *resultError)
    {
        completions++;
        XCTAssertNil(accounts);
        XCTAssertFalse(brokerOnly);
        XCTAssertEqualObjects(resultError.domain, MSIDErrorDomain);
        XCTAssertEqual(resultError.code, MSIDErrorInternal);
    }];
    XCTAssertEqual(completions, 1u);
    XCTAssertEqual(self.performCount, 1u);
}

@end
#endif
