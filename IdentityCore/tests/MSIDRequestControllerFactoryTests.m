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
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#if TARGET_OS_OSX
#import "MSIDXpcSilentTokenRequestController.h"
#import "MSIDSSOXpcInteractiveTokenRequestController.h"
#endif

@interface MSIDBaseRequestController (Testing)

@property (nonatomic, readwrite) id<MSIDRequestControlling> fallbackController;

@end

@interface MSIDRequestControllerFactoryTests : XCTestCase

@end

@implementation MSIDRequestControllerFactoryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [MSIDTestSwizzle reset];
}

- (void)testWhenForceToSkipLocalRt_isSet_shouldSkip_whenFallBackController_isValid
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

- (void)testWhenForceToUseLocalRt_isSet_shouldSkip_whenFallBackController_isValid
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

- (void)testWhenUseLocalRt_isUnDefined_shouldSkip_whenFallBackController_isValid
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


#if TARGET_OS_OSX
- (void)testWhenInteractiveXpcIsBackup_andSsoExtensionIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
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
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
}

- (void)testWhenInteractiveXpcIsBackup_andSsoExtensionIsEnabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
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
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDSSOExtensionInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDSSOXpcInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    XCTAssertNil(baseController.fallbackController);
}

- (void)testWhenInteractiveXpcIsDisabled_andSsoExtensionIsEnabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    SEL selectorForMSIDRequestParameters = NSSelectorFromString(@"shouldUseBroker");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDRequestParameters
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
        return YES;
    }];
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDSSOExtensionInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    if (![baseController isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    XCTAssertNil(baseController.fallbackController);
}

- (void)testWhenInteractiveXpcIsDisabled_andSsoExtensionIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    SEL selectorForMSIDRequestParameters = NSSelectorFromString(@"shouldUseBroker");
    [MSIDTestSwizzle instanceMethod:selectorForMSIDRequestParameters
                              class:[MSIDRequestParameters class]
                              block:(id)^(void)
    {
        return YES;
    }];
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
    
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    XCTAssertNil(baseController.fallbackController);
}

- (void)testWhenInteractiveXpcIsFull_andSsoExtensionIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeFull;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
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
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDSSOXpcInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    if (![baseController isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    XCTAssertNil(baseController.fallbackController);
}


- (void)testWhenInteractiveXpcIsFull_andSsoExtensionIsEnabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeFull;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionInteractiveTokenRequestController
                           class:[MSIDSSOExtensionInteractiveTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    
    SEL selectorForMSIDXpcInteractiveTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcInteractiveTokenRequestController
                           class:[MSIDSSOXpcInteractiveTokenRequestController class]
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
    
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:parameters tokenRequestProvider:provider error:&error];
    if (![controller isMemberOfClass:MSIDSSOExtensionInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDSSOXpcInteractiveTokenRequestController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDLocalInteractiveController.class])
    {
        XCTFail();
    }
    
    controller = baseController.fallbackController;
    baseController = (MSIDBaseRequestController *)controller;
    XCTAssertNil(baseController.fallbackController);
}


- (void)testWhenSsoExtensionIsEnabled_andXpcIsPartiallyEnabled_andSsoExtensionIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    SEL selectorForMSIDXpcSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcSilentTokenRequestController
                           class:[MSIDXpcSilentTokenRequestController class]
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
                                                                                           forceRefresh:NO
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];
    // 1. Start with local signin controller to read cached tokens
    if (![controller isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
    XCTAssertFalse([(MSIDSilentController *)controller forceRefresh]);

    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    
    // 2. When SsoExtension controller disabled, use local signin controller to refresh. XPC is ignore as it is in XPC backup mode
    if (![baseController.fallbackController isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    baseController = (MSIDSilentController *)baseController.fallbackController;
    XCTAssertTrue([(MSIDSilentController *)baseController forceRefresh]);
    XCTAssertTrue([(MSIDSilentController *)baseController isLocalFallbackMode]);
}

- (void)testWhenSsoExtensionIsEnabled_andXpcIsPartiallyEnabled_andSsoExtensionIsEnabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeBackup;
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return YES;
    }];
    
    SEL selectorForMSIDXpcSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcSilentTokenRequestController
                           class:[MSIDXpcSilentTokenRequestController class]
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
                                                                                           forceRefresh:NO
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];
    // 1. Start with local signin controller to read cached tokens
    if (![controller isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
    XCTAssertFalse([(MSIDSilentController *)controller forceRefresh]);

    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDSSOExtensionSilentTokenRequestController.class])
    {
        XCTFail();
    }
        
    // 2. When local signin controller failed, use SsoExtension controller
    baseController = (MSIDSSOExtensionSilentTokenRequestController *)baseController.fallbackController;
    if (![baseController.fallbackController isMemberOfClass:MSIDXpcSilentTokenRequestController.class])
    {
        XCTFail();
    }
    
    // 3. When SsoExtension controller failed, use Xpc Controller
    baseController = (MSIDXpcSilentTokenRequestController *)baseController.fallbackController;
    if (![baseController.fallbackController isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    // 4. When Xpc controller failed, use local signin controller to refresh
    baseController = (MSIDSilentController *)baseController.fallbackController;
    XCTAssertTrue([(MSIDSilentController *)baseController forceRefresh]);
    XCTAssertTrue([(MSIDSilentController *)baseController isLocalFallbackMode]);
}

- (void)testWhenSsoExtensionIsEnabled_andXpcIsFullyEnabled_andSsoExtensionIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.msidXpcMode = MSIDXpcModeFull;
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;
    
    NSError *error;
    SEL selectorForMSIDSSOExtensionSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDSSOExtensionSilentTokenRequestController
                           class:[MSIDSSOExtensionSilentTokenRequestController class]
                           block:(id)^(void)
    {
        return NO;
    }];
    
    SEL selectorForMSIDXpcSilentTokenRequestController = NSSelectorFromString(@"canPerformRequest");
    [MSIDTestSwizzle classMethod:selectorForMSIDXpcSilentTokenRequestController
                           class:[MSIDXpcSilentTokenRequestController class]
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
                                                                                           forceRefresh:NO
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];
    // 1. Start with local signin controller to read cached tokens
    if (![controller isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
    XCTAssertFalse([(MSIDSilentController *)controller forceRefresh]);

    // 2. When local signin controller failed, use SsoExtension controller
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDXpcSilentTokenRequestController.class])
    {
        XCTFail();
    }
    
    // 2. When SsoExtension controller failed, use Xpc Controller
    baseController = (MSIDXpcSilentTokenRequestController *)baseController.fallbackController;
    if (![baseController.fallbackController isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    // 3. When Xpc controller failed, use local signin controller to refresh
    baseController = (MSIDSilentController *)baseController.fallbackController;
    XCTAssertTrue([(MSIDSilentController *)baseController forceRefresh]);
    XCTAssertTrue([(MSIDSilentController *)baseController isLocalFallbackMode]);
}

#endif

- (void)testWhenSsoExtensionIsEnabled_andXpcIsDisabled_controllersOrder_areCorrect
{
    MSIDTestTokenRequestProvider *provider = [[MSIDTestTokenRequestProvider alloc] initWithTestResponse:nil
                                                                                              testError:nil
                                                                                  testWebMSAuthResponse:nil];
    MSIDRequestParameters *parameters = [self requestParameters];
    parameters.allowUsingLocalCachedRtWhenSsoExtFailed = YES;

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
                                                                                           forceRefresh:NO
                                                                                            skipLocalRt:MSIDSilentControllerForceSkippingLocalRt
                                                                                   tokenRequestProvider:provider
                                                                                                  error:&error];
    // 1. Start with local signin controller to read cached tokens
    if (![controller isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    XCTAssertTrue([(MSIDSilentController *)controller skipLocalRt]);
    XCTAssertFalse([(MSIDSilentController *)controller forceRefresh]);
    
    // 2. When local signin controller failed, use SsoExtension controller
    MSIDBaseRequestController *baseController = (MSIDBaseRequestController *)controller;
    if (![baseController.fallbackController isMemberOfClass:MSIDSSOExtensionSilentTokenRequestController.class])
    {
        XCTFail();
    }
    
    // 3. When SsoExtension controller failed, use local signin controller to refresh
    baseController = (MSIDSSOExtensionSilentTokenRequestController *)baseController.fallbackController;
    if (![baseController.fallbackController isMemberOfClass:MSIDSilentController.class])
    {
        XCTFail();
    }
    
    baseController = (MSIDSilentController *)baseController.fallbackController;
    XCTAssertTrue([(MSIDSilentController *)baseController forceRefresh]);
    XCTAssertTrue([(MSIDSilentController *)baseController isLocalFallbackMode]);
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
