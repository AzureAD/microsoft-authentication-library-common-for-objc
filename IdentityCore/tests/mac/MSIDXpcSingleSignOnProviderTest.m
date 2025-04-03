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
#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDXpcProviderCacheMock.h"
#import "MSIDTestSwizzle.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"

@interface MSIDXpcSingleSignOnProviderTest : XCTestCase

@end

@implementation MSIDXpcSingleSignOnProviderTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [MSIDTestSwizzle reset];
}

- (void)testNoXpcComponentInstalledOnDevice_canPerformRequest_returnsFalse
{
    MSIDXpcProviderCacheMock *xpcProviderCacheMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:NO                                isXpcValidated:NO shouldReturnCachedXpcStatus:NO];
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCacheMock]);
}

- (void)testXpcComponentInstalledOnDevice_ssoExtentionDisabled_hasValidCachedXpcConfiguration_canPerformRequest_returnsCachedStatus
{
    
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedFalseMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES                                isXpcValidated:YES shouldReturnCachedXpcStatus:YES];
    xpcProviderCachedFalseMock.cachedXpcStatus = NO;
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedFalseMock]);
    
    MSIDXpcProviderCacheMock *xpcProviderCachedTrueMock = [[MSIDXpcProviderCacheMock alloc] initWithXpcInstallationStatus:YES                                isXpcValidated:YES shouldReturnCachedXpcStatus:YES];
    xpcProviderCachedTrueMock.cachedXpcStatus = YES;
    XCTAssertTrue([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedTrueMock]);
}

- (void)testXpcComponentInstalledOnDevice_ssoExtentionDisabled_hasInvalidCachedXpcConfiguration_andValidXpcValidation_canPerformRequest_shouldCallRemoteXpcService
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Remote Xpc service will be called for canPerformRequest"];
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    SEL selectorForMSIDXpcSingleSignOnProvider = NSSelectorFromString(@"getXpcService:withContinueBlock:");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDXpcSingleSignOnProvider
                              class:[MSIDXpcSingleSignOnProvider class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:YES
                                                       shouldReturnCachedXpcStatus:NO];
    [MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testXpcComponentInstalledOnDevice_ssoExtentionDisabled_hasInvalidCachedXpcStatus_cannotValidateXpc_canPerformRequest_returnsFalse
{
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO
                                                       shouldReturnCachedXpcStatus:NO];
    
    XCTAssertFalse([MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock]);
}

- (void)testNoXpcComponentInstalledOnDevice_ssoExtentionEnabled_hasInvalidCachedXpcStatus_canPerformRequest_ssoExtensionShouldTrigger
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"SsoExtension will be triggered for to get device info"];

    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDSSOExtensionGetDeviceInfoRequest_request = NSSelectorFromString(@"executeRequestWithCompletion:");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDSSOExtensionGetDeviceInfoRequest_request
                              class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    MSIDXpcProviderCacheMock *xpcProviderCachedMock = [[MSIDXpcProviderCacheMock alloc]
                                                       initWithXpcInstallationStatus:YES
                                                       isXpcValidated:NO
                                                       shouldReturnCachedXpcStatus:NO];
    [MSIDXpcSingleSignOnProvider canPerformRequest:xpcProviderCachedMock];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

@end
