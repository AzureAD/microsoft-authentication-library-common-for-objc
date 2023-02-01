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
#import "MSIDInteractiveTokenRequestParameters.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDTestTokenRequestProvider.h"
#import "MSIDSilentController.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDSSOExtensionSilentTokenRequestController.h"
#import "MSIDTestSwizzle.h"
#import "MSIDRequestParameters+Broker.h"

@interface MSIDRequestControllerFactoryTests : XCTestCase

@end

@implementation MSIDRequestControllerFactoryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testWhenForceToSkipLocalRt_isSet_shouldSkip_whenFallBackController_isValid API_AVAILABLE(macos(10.15))
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDRequestParameters = NSSelectorFromString(@"shouldUseBroker");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDRequestParameters
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
        return YES;
    }];

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testWhenForceToSkipLocalRt_isSet_shouldSkip_whenFallBackController_isNotSet
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testWhenForceToUseLocalRt_isSet_shouldSkip_whenFallBackController_isValid API_AVAILABLE(macos(10.15))
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDRequestParameters = NSSelectorFromString(@"shouldUseBroker");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDRequestParameters
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
        return YES;
    }];

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceUsingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertFalse([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testWhenForceToUseLocalRt_isSet_shouldSkip_whenFallBackController_isNotSet
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceUsingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertFalse([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testWhenUseLocalRt_isUnDefined_shouldSkip_whenFallBackController_isValid API_AVAILABLE(macos(10.15))
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDRequestParameters = NSSelectorFromString(@"shouldUseBroker");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDRequestParameters
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
        return YES;
    }];

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerUndefinedLocalRtUsage
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testWhenUseLocalRt_isUnDefined_shouldNotSkip_whenFallBackController_isNotValid
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];

    NSError *error;

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceUsingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);
    XCTAssertFalse([(MSIDSilentController *)controller skipLocalRt]);
}

- (void)testInteractiveController_whenNestedAuth_parametersAreReversed
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.nestedAuthBrokerClientId = @"other_client_id";
    parameters.nestedAuthBrokerRedirectUri = @"brk-other_redirect_uri";

    NSError *error;

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters
                                                                                        tokenRequestProvider:provider
                                                                                                       error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDLocalInteractiveController.class]);

    MSIDRequestParameters *requestParameters = [(MSIDLocalInteractiveController *)controller requestParameters];
    XCTAssertEqualObjects(requestParameters.clientId, @"other_client_id");
    XCTAssertEqualObjects(requestParameters.redirectUri, @"brk-other_redirect_uri");
    XCTAssertEqualObjects(requestParameters.nestedAuthBrokerClientId, @"my_client_id");
    XCTAssertEqualObjects(requestParameters.nestedAuthBrokerRedirectUri, @"my_redirect_uri");
}

- (void)testSilentController_whenNestedAuth_parametersAreReversed
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.nestedAuthBrokerClientId = @"other_client_id";
    parameters.nestedAuthBrokerRedirectUri = @"brk-other_redirect_uri";

    NSError *error;

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory silentControllerForParameters:parameters
                                                                                           forceRefresh:YES
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];

    XCTAssertTrue([controller isKindOfClass:MSIDSilentController.class]);

    MSIDRequestParameters *requestParameters = [(MSIDSilentController *)controller requestParameters];

    XCTAssertEqualObjects(requestParameters.clientId, @"other_client_id");
    XCTAssertEqualObjects(requestParameters.redirectUri, @"brk-other_redirect_uri");
    XCTAssertEqualObjects(requestParameters.nestedAuthBrokerClientId, @"my_client_id");
    XCTAssertEqualObjects(requestParameters.nestedAuthBrokerRedirectUri, @"my_redirect_uri");
}

- (MSIDInteractiveTokenRequestParameters *)requestParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"user.read tasks.read";
    parameters.oidcScope = @"openid profile offline_access";
    parameters.redirectUri = @"my_redirect_uri";
    parameters.correlationId = [NSUUID new];
    parameters.extendedLifetimeEnabled = YES;
    parameters.telemetryRequestId = [[NSUUID new] UUIDString];
    return parameters;
}

@end
