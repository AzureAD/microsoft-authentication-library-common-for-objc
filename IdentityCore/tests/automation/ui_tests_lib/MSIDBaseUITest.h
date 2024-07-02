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
#import "MSIDTestConfigurationProvider.h"
#import "MSIDTestAutomationApplication.h"
#import "MSIDTestAutomationAccountConfigurationRequest.h"

NS_ASSUME_NONNULL_BEGIN

@class MSIDAutomationErrorResult;
@class MSIDAutomationSuccessResult;
@class MSIDAutomationAccountsResult;
@class MSIDIdTokenClaims;
@class MSIDTestAutomationAccount;

@interface MSIDBaseUITest : XCTestCase

@property (nonatomic) MSIDTestAutomationAccount *primaryAccount;
@property (nonatomic, class) MSIDTestConfigurationProvider *confProvider;
@property (nonatomic) NSArray *testAccounts;
@property (nonatomic) MSIDTestAutomationApplication *testApplication;
@property (nonatomic) NSArray *testApplications;
@property (nonatomic) NSString *redirectUriPrefix;

#pragma mark - Pipelines

- (void)cleanPipelines;
- (void)closeResultPipeline:(XCUIApplication *)application;
- (NSDictionary *)automationResultDictionary:(XCUIApplication *)application;
- (MSIDAutomationErrorResult *)automationErrorResult:(XCUIApplication *)application;
- (MSIDAutomationSuccessResult *)automationSuccessResult:(XCUIApplication *)application;
- (MSIDAutomationAccountsResult *)automationAccountsResult:(XCUIApplication *)application;

#pragma mark - Actions

- (void)clearCache:(XCUIApplication *)application;
- (void)clearCookies:(XCUIApplication *)application;
- (void)performAction:(NSString *)action
               config:(nullable NSDictionary *)config
          application:(XCUIApplication *)application;

#pragma mark - Assertions

- (void)assertAccessTokenNotNil:(XCUIApplication *)application;

#pragma mark - Enter Email

- (void)aadEnterEmail:(XCUIApplication *)application;
- (void)enterEmail:(NSString *)email app:(XCUIApplication *)application;
- (void)enterEmail:(NSString *)email app:(XCUIApplication *)application isMainApp:(BOOL)isMainApp;

#pragma mark - Enter Password

- (void)aadEnterPassword:(XCUIApplication *)application;
- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application;
- (void)enterPassword:(NSString *)password app:(XCUIApplication *)app isMainApp:(BOOL)isMainApp;

- (void)adfsEnterPassword:(XCUIApplication *)application;;
- (void)adfsEnterPassword:(NSString *)password app:(XCUIApplication *)application;

#pragma mark - Lab APIs

- (void)loadTestApp:(MSIDTestAutomationAppConfigurationRequest *)appRequest;
- (void)loadTestAccount:(MSIDTestAutomationAccountConfigurationRequest *)accountRequest;
- (void)loadTestAccounts:(NSArray<MSIDTestAutomationAccountConfigurationRequest *> *)accountRequests;
- (NSArray *)loadTestAccountRequest:(MSIDAutomationBaseApiRequest *)accountRequest;

#pragma mark -

- (NSDictionary *)resultIDTokenClaims:(XCUIApplication *)application;

- (void)waitForElement:(id)object;
- (XCUIElement *)waitForEitherElements:(XCUIElement *)object1 and:(XCUIElement *)object2;

- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element;
- (void)tapElementAndWaitForKeyboardToAppear:(XCUIElement *)element app:(XCUIApplication *)application;

@end

NS_ASSUME_NONNULL_END
