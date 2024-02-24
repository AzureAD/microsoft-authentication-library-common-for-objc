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


#import "MSIDBaseUITest.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationErrorResult.h"
#import "MSIDAutomationSuccessResult.h"
#import "MSIDAutomationAccountsResult.h"
#import "MSIDIdTokenClaims.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "XCUIElement+CrossPlat.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDTestAutomationAccount.h"
#import "MSIDAutomationOperationResponseHandler.h"
#import "MSIDTestAutomationApplication.h"

static MSIDTestConfigurationProvider *s_confProvider;

@implementation MSIDBaseUITest

+ (MSIDTestConfigurationProvider *)confProvider
{
    return s_confProvider;
}

+ (void)setConfProvider:(MSIDTestConfigurationProvider *)accountsProvider
{
    s_confProvider = accountsProvider;
}

#pragma mark - Pipelines

- (void)cleanPipelines
{
#if TARGET_OS_SIMULATOR
    static NSArray *pipelinesPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pipelinesPaths = @[
            [MSIDAutomationActionConstants requestPipelinePath],
            [MSIDAutomationActionConstants resultPipelinePath],
            [MSIDAutomationActionConstants logsPipelinePath]
        ];

    });
    
    for (NSString *path in pipelinesPaths)
    {
        if (![NSFileManager.defaultManager fileExistsAtPath:path]) continue;;
        
        // Delete file.
        NSError *error;
        BOOL fileRemoved = [NSFileManager.defaultManager removeItemAtPath:path error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(fileRemoved);
    }
#endif
}

- (void)closeResultPipeline:(XCUIApplication *)application
{
#if TARGET_OS_SIMULATOR
    int count = 10;
    double interval = 1;
    __auto_type resultPipelineExpectation = [[XCTestExpectation alloc] initWithDescription:@"Wait for result pipeline."];
    
    // Wait till file appears.
    int i = 0;
    while (i < count)
    {
        if ([NSFileManager.defaultManager fileExistsAtPath:[MSIDAutomationActionConstants resultPipelinePath]])
        {
            [resultPipelineExpectation fulfill];
            break;
        }
        
        [NSThread sleepForTimeInterval:0.5f];
        i++;
    }
    
    [self waitForExpectations:@[resultPipelineExpectation] timeout:count * interval];
    
    // Delete file.
    NSError *error;
    BOOL fileRemoved = [NSFileManager.defaultManager removeItemAtPath:[MSIDAutomationActionConstants resultPipelinePath] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(fileRemoved);
#else
    if ([application.buttons[@"Done"] exists])
    {
        [application.buttons[@"Done"] msidTap];
    }
#endif
}

- (NSDictionary *)automationResultDictionary:(XCUIApplication *)application
{
    NSDictionary *result;
#if TARGET_OS_SIMULATOR
    int timeout = 60;
    __auto_type resultPipelineExpectation = [[XCTestExpectation alloc] initWithDescription:@"Wait for result pipeline."];
    
    // Wait till file appears.
    int i = 0;
    while (i < timeout)
    {
        if ([NSFileManager.defaultManager fileExistsAtPath:[MSIDAutomationActionConstants resultPipelinePath]])
        {
            [resultPipelineExpectation fulfill];
            break;
        }
        
        sleep(1);
        i++;
    }
    
    [self waitForExpectations:@[resultPipelineExpectation] timeout:timeout];

    // Read json from file.
    NSString *jsonString = [NSString stringWithContentsOfFile:[MSIDAutomationActionConstants resultPipelinePath] encoding:NSUTF8StringEncoding error:nil];

    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
#else
    XCUIElement *resultTextView = application.textViews[@"resultInfo"];
    [self waitForElement:resultTextView];
    
    NSError *error = nil;
    NSData *data = [resultTextView.value dataUsingEncoding:NSUTF8StringEncoding];
    result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
#endif
    
    return result;
}

- (MSIDAutomationErrorResult *)automationErrorResult:(XCUIApplication *)application
{
    MSIDAutomationErrorResult *result = [[MSIDAutomationErrorResult alloc] initWithJSONDictionary:[self automationResultDictionary:application] error:nil];
    XCTAssertNotNil(result);
    XCTAssertFalse(result.success);
    return result;
}

- (MSIDAutomationSuccessResult *)automationSuccessResult:(XCUIApplication *)application
{
    MSIDAutomationSuccessResult *result = [[MSIDAutomationSuccessResult alloc] initWithJSONDictionary:[self automationResultDictionary:application] error:nil];
    XCTAssertNotNil(result);
    if (!result.success)
    {
        // Print dictionary to debug the reason of failure.
        XCTAssertEqualObjects(@{}, [result jsonDictionary]);
    }
    XCTAssertTrue(result.success);
    return result;
}

- (MSIDAutomationAccountsResult *)automationAccountsResult:(XCUIApplication *)application
{
    MSIDAutomationAccountsResult *result = [[MSIDAutomationAccountsResult alloc] initWithJSONDictionary:[self automationResultDictionary:application] error:nil];
    XCTAssertNotNil(result);
    XCTAssertTrue(result.success);
    return result;
}

#pragma mark - Actions

- (void)clearCache:(XCUIApplication *)application
{
    [self performAction:MSID_AUTO_CLEAR_CACHE_ACTION_IDENTIFIER config:nil application:application];
    sleep(3);
    [self closeResultPipeline:application];
}

- (void)clearCookies:(XCUIApplication *)application
{
    [self performAction:MSID_AUTO_CLEAR_COOKIES_ACTION_IDENTIFIER config:nil application:application];
    sleep(5);
    [self closeResultPipeline:application];
}

- (void)performAction:(NSString *)action
               config:(NSDictionary *)config
          application:(XCUIApplication *)application
{
    NSString *jsonString = [config msidJSONSerializeWithContext:nil];
#if TARGET_OS_SIMULATOR
    if (jsonString)
    {
        [jsonString writeToFile:[MSIDAutomationActionConstants requestPipelinePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    sleep(1);
    [application.buttons[action] msidTap];
#else
    [application.buttons[action] msidTap];
    
    if (jsonString)
    {
        [application.textViews[@"requestInfo"] msidTap];
        [application.textViews[@"requestInfo"] msidPasteText:jsonString application:application];
        sleep(1);
        [application.buttons[@"Go"] msidTap];
    }
#endif
}

- (void)assertAccessTokenNotNil:(XCUIApplication *)application
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult:application];
    
    XCTAssertTrue([result.accessToken length] > 0);
    XCTAssertTrue(result.success);
}

#pragma mark - Enter Email

- (void)aadEnterEmail:(XCUIApplication *)application
{
    [self enterEmail:[NSString stringWithFormat:@"%@\n", self.primaryAccount.upn] app:application];
}

- (void)enterEmail:(NSString *)email app:(XCUIApplication *)application
{
    [self enterEmail:email app:application isMainApp:YES];
}

- (void)enterEmail:(NSString *)email app:(XCUIApplication *)application isMainApp:(BOOL)isMainApp
{
    XCUIElement *emailTextField = [application.textFields elementBoundByIndex:0];
    [self waitForElement:emailTextField];
    if ([email isEqualToString:emailTextField.value])
    {
        return;
    }
    
    [self tapElementAndWaitForKeyboardToAppear:emailTextField app:application];
    [emailTextField selectTextWithApp:application];
    NSString *emailString = [NSString stringWithFormat:@"%@\n", email];
    [self enterText:emailTextField isMainApp:isMainApp text:emailString];
}

#pragma mark - Enter Password

- (void)aadEnterPassword:(XCUIApplication *)application
{
    [self enterPassword:self.primaryAccount.password app:application];
}

- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application
{
    [self enterPassword:password app:application isMainApp:YES];
}

- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application isMainApp:(BOOL)isMainApp
{
    // Enter password
    XCUIElement *passwordSecureTextField = [application.secureTextFields elementBoundByIndex:0];
    // This is explicitly to check the new screen where to ask user to signin with the following 2 options. This caused several automation failures
    // 1. Use my password
    // 2. Sign in to an orgnization
    XCUIElement *useMyPasswordButton = application.buttons[@"Use my password"];
    XCUIElement *currentElement = [self waitForEitherElements:passwordSecureTextField and:useMyPasswordButton];
    if (currentElement.elementType == XCUIElementTypeButton)
    {
        [currentElement tap];
        [self enterPassword:password
                        app:application
                  isMainApp:isMainApp];
        return;
    }
    
    [self tapElementAndWaitForKeyboardToAppear:passwordSecureTextField app:application];
    NSString *passwordString = [NSString stringWithFormat:@"%@\n", password];
    [self enterText:passwordSecureTextField isMainApp:isMainApp text:passwordString];
}

- (void)adfsEnterPassword:(XCUIApplication *)application
{
    [self adfsEnterPassword:self.primaryAccount.password app:application];
}

- (void)adfsEnterPassword:(NSString *)password app:(XCUIApplication *)application
{
    XCUIElement *passwordTextField = application.secureTextFields[@"Password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField app:application];
    [passwordTextField typeText:password];
}

#pragma mark - Lab APIs

- (void)loadTestApp:(MSIDTestAutomationAppConfigurationRequest *)appRequest
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get configuration"];
    
    MSIDAutomationOperationResponseHandler *responseHandler = [[MSIDAutomationOperationResponseHandler alloc] initWithClass:MSIDTestAutomationApplication.class];
    
    [self.class.confProvider.operationAPIRequestHandler executeAPIRequest:appRequest
                                                          responseHandler:responseHandler
                                                        completionHandler:^(id result, __unused NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertTrue([result isKindOfClass:[NSArray class]]);
        
        NSArray *results = (NSArray *)result;
        XCTAssertTrue(results.count >= 1);
        self.testApplication = results[0];
        self.testApplications = result;
        
        for (MSIDTestAutomationApplication *application in self.testApplications)
        {
            application.redirectUriPrefix = self.redirectUriPrefix;
        }
        
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)loadTestAccount:(MSIDTestAutomationAccountConfigurationRequest *)accountRequest
{
    NSArray *accounts = [self loadTestAccountRequest:accountRequest];
    self.primaryAccount = accounts[0];
    self.testAccounts = accounts;
}

- (void)loadTestAccounts:(NSArray<MSIDTestAutomationAccountConfigurationRequest *> *)accountRequests
{
    NSMutableArray *allAccounts = [NSMutableArray new];
    
    for (MSIDTestAutomationAccountConfigurationRequest *request in accountRequests)
    {
        NSArray *accounts = [self loadTestAccountRequest:request];
        if (accounts)
        {
            [allAccounts addObjectsFromArray:accounts];
        }
    }
    
    XCTAssertTrue(allAccounts.count >= 1);
    
    self.primaryAccount = allAccounts[0];
    self.testAccounts = allAccounts;
}

- (NSArray *)loadTestAccountRequest:(MSIDAutomationBaseApiRequest *)accountRequest
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get account"];
    
    MSIDAutomationOperationResponseHandler *responseHandler = [[MSIDAutomationOperationResponseHandler alloc] initWithClass:MSIDTestAutomationAccount.class];
    
    __block NSArray *results = nil;
    
    [self.class.confProvider.operationAPIRequestHandler executeAPIRequest:accountRequest
                                                          responseHandler:responseHandler
                                                        completionHandler:^(id result, __unused NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertTrue([result isKindOfClass:[NSArray class]]);
        
        results = (NSArray *)result;
        
        if (!results.count) 
        {
            // Try again because Lab API is sometimes flaky
            [self.class.confProvider.operationAPIRequestHandler executeAPIRequest:accountRequest
                                                                  responseHandler:responseHandler
                                                                completionHandler:^(id secondResult, __unused NSError *secondError)
            {
                XCTAssertNotNil(secondResult);
                XCTAssertTrue([secondResult isKindOfClass:[NSArray class]]);
                results = (NSArray *)secondResult;
                XCTAssertTrue(results.count >= 1);
            }];
        }
        
        XCTAssertTrue(results.count >= 1);
        
        XCTestExpectation *passwordLoadExpecation = [self expectationWithDescription:@"Get password"];
        passwordLoadExpecation.expectedFulfillmentCount = results.count;
        
        for (MSIDTestAutomationAccount *account in results)
        {
            [self.class.confProvider.passwordRequestHandler loadPasswordForTestAccount:account
                                                                     completionHandler:^(NSString *password, __unused NSError *err)
            {
                XCTAssertNotNil(password);
                [passwordLoadExpecation fulfill];
            }];
        }
        
        [self waitForExpectations:@[passwordLoadExpecation] timeout:60];
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:120];
    return results;
}

#pragma mark -

- (NSDictionary *)resultIDTokenClaims:(XCUIApplication *)application
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult:application];
    
    NSString *idToken = result.idToken;
    XCTAssertTrue([idToken length] > 0);
    
    MSIDIdTokenClaims *idTokenClaims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:nil];
    return [idTokenClaims jsonDictionary];
}

- (void)waitForElement:(id)object
{
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"exists == 1"];
    [self expectationForPredicate:existsPredicate evaluatedWithObject:object handler:nil];
    [self waitForExpectationsWithTimeout:30.0f handler:nil];
}

- (XCUIElement *)waitForEitherElements:(XCUIElement *)object1 and:(XCUIElement *)object2
{
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"%@.exists == 1 OR %@.exists == 1" argumentArray:@[object1, object2]];
    [self expectationForPredicate:existsPredicate evaluatedWithObject:nil handler:nil];
    [self waitForExpectationsWithTimeout:60.0f handler:nil];
    return object1.exists ? object1 : object2;
}

- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element
{
    [self tapElementAndWaitForKeyboardToAppear:element app:[XCUIApplication new]];
}

- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element app:(XCUIApplication *)application
{
#if TARGET_OS_IPHONE
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 13.0f)
    {
        [element tap];
        return;
    }

    XCUIElement *keyboard = [[application keyboards] element];

    while (true)
    {
        [element pressForDuration:0.2f];

        if (keyboard.exists && keyboard.hittable)
        {
            sleep(0.2f);
            break;
        }

        sleep(0.2f);
    }
#endif
}

- (void)enterText:(XCUIElement *)textField isMainApp:(BOOL)isMainApp text:(NSString *)textToEnter
{
    // Xcode 11 + iOS 13 has a UI automation bug where text entry is slow and times out when entering not in the main automation target app
    // This works it around by entering letter by letter. It's slow, but doesn't timeout. Hopefully they will fix it in the next Xcode/iOS versions.
    if (isMainApp)
    {
        [textField typeText:textToEnter];
    }
    else
    {
        for (int i = 0; i < [textToEnter length]; i++)
        {
            [textField typeText:[textToEnter substringWithRange:NSMakeRange(i, 1)]];
        }
    }
}

@end
