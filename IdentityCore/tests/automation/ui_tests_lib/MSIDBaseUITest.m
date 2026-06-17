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
#import "MSIDKeyVaultAccountProvider.h"
#import "MSIDKeyVaultAppConfigProvider.h"
#import "MSIDKeyVaultCredentialProvider.h"
#import "MSIDTestAutomationAccountConfigurationRequest.h"
#import "MSIDTestAutomationAppConfigurationRequest.h"

static MSIDTestConfigurationProvider *s_confProvider;
static MSIDKeyVaultAccountProvider *s_keyVaultAccountProvider;
static MSIDKeyVaultAppConfigProvider *s_keyVaultAppConfigProvider;

static NSTimeInterval const MSIDPasswordEntryPollingTimeout = 45.0;
static NSTimeInterval const MSIDPasswordEntryPollingInterval = 1;

@implementation MSIDBaseUITest

+ (MSIDTestConfigurationProvider *)confProvider
{
    return s_confProvider;
}

+ (void)setConfProvider:(MSIDTestConfigurationProvider *)accountsProvider
{
    s_confProvider = accountsProvider;
}

+ (MSIDKeyVaultAccountProvider *)keyVaultAccountProvider
{
    return s_keyVaultAccountProvider;
}

+ (void)setKeyVaultAccountProvider:(MSIDKeyVaultAccountProvider *)provider
{
    s_keyVaultAccountProvider = provider;
}

+ (MSIDKeyVaultAppConfigProvider *)keyVaultAppConfigProvider
{
    return s_keyVaultAppConfigProvider;
}

+ (void)setKeyVaultAppConfigProvider:(MSIDKeyVaultAppConfigProvider *)provider
{
    s_keyVaultAppConfigProvider = provider;
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
    [self closeResultPipeline:application waitInMs:10];
}

- (void)closeResultPipeline:(XCUIApplication *)application waitInMs:(int)count
{
#if TARGET_OS_SIMULATOR
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
    if (![self tapPasswordSelectionButtonIfPresentInApp:application])
    {
        // Same rationale as tapPasswordSelectionButtonIfPresentInApp: stay
        // inside the web view so an identically-labeled QuickType / AutoFill
        // suggestion never wins the first-match query. The polling loop in
        // enterPassword: handles the "not present yet" case.
        XCUIElement *useYourPasswordElement = application.webViews.staticTexts[@"Use your password"];
        if ([self waitForElementsAndContinueIfNotAppear:useYourPasswordElement timeout:1.0f] == XCTWaiterResultCompleted)
        {
            [useYourPasswordElement msidTap];
        }
    }

    [self enterPassword:self.primaryAccount.password app:application];
    // New Password reset API requires to force providing a new password after logging in with original password.
    [self setupPassword:self.primaryAccount.password app:application];
}

- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application
{
    [self enterPassword:password app:application isMainApp:YES];
}

- (void)setupPassword:(NSString *)password app:(XCUIApplication *)application
{
    [self setupPassword:password app:application isMainApp:YES];
}

- (void)setupPassword:(NSString *)password app:(XCUIApplication *)application isMainApp:(BOOL)isMainApp
{
    sleep(1);
    if (application.secureTextFields.count > 1)
    {
        // New password flow
        //Current password
        NSPredicate *passwordFieldPredicate = [NSPredicate predicateWithFormat:@"placeholderValue CONTAINS[c] %@", @"Current password"];
        XCUIElement *currentPasswordSecureTextField = [[application.secureTextFields matchingPredicate:passwordFieldPredicate] elementBoundByIndex:0];
        [self tapElementAndWaitForKeyboardToAppear:currentPasswordSecureTextField app:application];
        NSString *passwordString = [NSString stringWithFormat:@"%@\n", password];
        [self enterText:currentPasswordSecureTextField isMainApp:isMainApp text:passwordString];
        
        passwordFieldPredicate = [NSPredicate predicateWithFormat:@"placeholderValue CONTAINS[c] %@", @"New password"];
        XCUIElement *newPasswordSecureTextField = [[application.secureTextFields matchingPredicate:passwordFieldPredicate] elementBoundByIndex:0];
        [self tapElementAndWaitForKeyboardToAppear:newPasswordSecureTextField app:application];
        passwordString = [NSString stringWithFormat:@"%@apple\n", password];
        [self enterText:newPasswordSecureTextField isMainApp:isMainApp text:passwordString];
        
        passwordFieldPredicate = [NSPredicate predicateWithFormat:@"placeholderValue CONTAINS[c] %@", @"Confirm password"];
        XCUIElement *confirmPasswordSecureTextField = [[application.secureTextFields matchingPredicate:passwordFieldPredicate] elementBoundByIndex:0];
        [self tapElementAndWaitForKeyboardToAppear:confirmPasswordSecureTextField app:application];
        passwordString = [NSString stringWithFormat:@"%@apple\n", password];
        [self enterText:confirmPasswordSecureTextField isMainApp:isMainApp text:passwordString];
    }
}

- (BOOL)dismissKeyboardIfVerifyEmailPagePresentInApp:(XCUIApplication *)application
{
    // The MSA "Verify your email" interstitial (shown during B2C / MSA login
    // flows when the account needs proof-of-control) auto-focuses the email
    // text field, which raises the iOS keyboard. The keyboard + its accessory
    // bar cover the lower part of the page, including the "Use your password"
    // link we actually want. While covered, the link is in the view hierarchy
    // (so .exists is YES) but XCUI taps land on the keyboard's hit area and
    // get absorbed — the link never receives the tap and the page never
    // progresses.
    //
    // Tap the keyboard's "Done" accessory button to dismiss it. The page then
    // scrolls/redraws and the password link becomes tappable. The polling
    // loop in enterPassword: re-invokes tapPasswordSelectionButtonIfPresentInApp:
    // on the next tick, which then finds and taps the link.
    if (!application.webViews.staticTexts[@"Verify your email"].exists)
    {
        return NO;
    }

    // The Done button on the keyboard accessory bar lives under different
    // parents depending on iOS version and which app surfaces the keyboard
    // (SafariViewController vs WKWebView). Try the known-safe scopes in order:
    // 1. toolbars.buttons (iOS classic UIToolbar input accessory)
    // 2. keyboards.buttons (iOS 17/18 direct keyboard child)
    // 3. otherElements.buttons (some accessory views wrap Done in a generic Other)
    // We intentionally avoid the unscoped application.buttons[@"Done"] because
    // it can match unrelated "Done" buttons elsewhere in the test host.
    NSArray<XCUIElement *> *doneCandidates = @[
        application.toolbars.buttons[@"Done"],
        application.keyboards.buttons[@"Done"],
        application.keyboards.toolbars.buttons[@"Done"],
        application.otherElements[@"InputAssistantView"].buttons[@"Done"],
    ];

    for (XCUIElement *candidate in doneCandidates)
    {
        if (candidate.exists && candidate.isHittable)
        {
            [candidate msidTap];
            return YES;
        }
    }

    return NO;
}

- (BOOL)tapPasswordSelectionButtonIfPresentInApp:(XCUIApplication *)application
{
    // If we're on the MSA "Verify your email" interstitial with the keyboard
    // up, the "Use your password" link is covered by the keyboard. Dismiss
    // the keyboard first so the link is hittable on the next loop iteration.
    if ([self dismissKeyboardIfVerifyEmailPagePresentInApp:application])
    {
        return NO;
    }

    NSArray<NSString *> *passwordButtonTitles = @[
        @"Use my password",
        @"Use your password",
        @"Use your password instead",
        @"Other ways to sign in"
    ];

    // Password-selection buttons only ever appear inside the AAD/MSA/B2C web
    // page (rendered in a WKWebView / SFSafariViewController inside the test
    // host). Restrict the lookup to web views so we never match an iOS
    // QuickType bar / Passwords AutoFill accessory button that happens to
    // carry the same label — tapping those opens the empty system password
    // picker on CI sims with no saved credentials and the test loops forever.
    // The polling loop in enterPassword: retries every second, so returning NO
    // here when the web button hasn't rendered yet is the desired behavior.
    for (NSString *buttonTitle in passwordButtonTitles)
    {
        XCUIElement *button = application.webViews.buttons[buttonTitle];
        if (!button.exists || !button.isHittable)
        {
            continue;
        }

        [button msidTap];
        return YES;
    }

    return NO;
}

- (void)enterPassword:(NSString *)password app:(XCUIApplication *)application isMainApp:(BOOL)isMainApp
{
    XCUIElement *passwordSecureTextField = application.secureTextFields.firstMatch;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MSIDPasswordEntryPollingTimeout];

    while (deadline.timeIntervalSinceNow > 0)
    {
        // Require .isHittable in addition to .exists so we don't tap and type
        // into a stale SecureTextField that's still in the view hierarchy from
        // a previous sign-in step. Without this, a second acquireToken call
        // (e.g. prompt=force with a login_hint after a prior sign-in) can find
        // the previous step's password field, send keystrokes that go nowhere,
        // and leave the broker waiting on an empty password — the test then
        // times out in waitForRedirectToClientApp.
        if (passwordSecureTextField.exists && passwordSecureTextField.isHittable)
        {
            [self tapElementAndWaitForKeyboardToAppear:passwordSecureTextField app:application];
            NSString *passwordString = [NSString stringWithFormat:@"%@\n", password];
            [self enterText:passwordSecureTextField isMainApp:isMainApp text:passwordString];
            return;
        }

        [self tapPasswordSelectionButtonIfPresentInApp:application];

        [NSThread sleepForTimeInterval:MSIDPasswordEntryPollingInterval];
    }

    XCTFail(@"Timed out waiting for the password field or a password selection button to appear.");
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
    // Try Key Vault JSON first if available
    if (s_keyVaultAppConfigProvider && s_keyVaultAppConfigProvider.hasCachedAppConfigs)
    {
        NSString *appConfigKey = [MSIDTestAutomationAppConfigurationRequest keyForAppConfigurationRequest:appRequest];

        NSError *error = nil;
        MSIDTestAutomationApplication *app = [s_keyVaultAppConfigProvider appConfigForKey:appConfigKey error:&error];

        if (app)
        {
            NSLog(@"[MSIDBaseUITest] Loaded app config from Key Vault JSON with key: %@, appId: %@", appConfigKey, app.appId);
            app.redirectUriPrefix = self.redirectUriPrefix;
            self.testApplication = app;
            self.testApplications = @[app];
            return;
        }
        else
        {
            NSLog(@"[MSIDBaseUITest] App config key '%@' not found in Key Vault JSON, falling back to API. Error: %@", appConfigKey, error.localizedDescription);
        }
    }

    // Fall back to Lab API / in-memory cache
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

#pragma mark - Key Vault compound key

/// Build a compound lookup key from a configuration request.
/// Format: <accountType>[_<protectionPolicy>][_<mfa>][_<federationProvider>]
///                      [_<b2cProvider>][_<environment>][_<userRole>]
/// Only non-default values are appended.
+ (NSString *)keyForAccountConfigurationRequest:(MSIDTestAutomationAccountConfigurationRequest *)request
{
    NSMutableString *key = [NSMutableString stringWithString:request.accountType ?: @"unknown"];
    
    // Protection policy (default: "none")
    if (request.protectionPolicyType
        && ![request.protectionPolicyType isEqualToString:MSIDTestAccountProtectionPolicyTypeNone])
    {
        [key appendFormat:@"_%@", request.protectionPolicyType];
    }
    
    // MFA (default: "none")
    if (request.mfaType
        && ![request.mfaType isEqualToString:MSIDTestAccountMFATypeNone])
    {
        [key appendFormat:@"_%@", request.mfaType];
    }
    
    // Federation provider (default: "none")
    if (request.federationProviderType
        && ![request.federationProviderType isEqualToString:MSIDTestAccountFederationProviderTypeNone])
    {
        [key appendFormat:@"_%@", request.federationProviderType];
    }
    
    // B2C provider (default: "none")
    if (request.b2cProviderType
        && ![request.b2cProviderType isEqualToString:MSIDTestAccountB2CProviderTypeNone])
    {
        [key appendFormat:@"_%@", request.b2cProviderType];
    }
    
    // Environment (default: "azurecloud")
    if (request.environmentType
        && ![request.environmentType isEqualToString:MSIDTestAccountEnvironmentTypeWWCloud])
    {
        [key appendFormat:@"_%@", request.environmentType];
    }
    
    // User role (default: nil/empty)
    if (request.userRole.length > 0)
    {
        [key appendFormat:@"_%@", request.userRole.lowercaseString];
    }
    
    // Guest home azure environment from additional query params (disambiguates cross-cloud guest accounts)
    NSString *guestHomeEnv = request.additionalQueryParameters[@"guesthomeazureenvironment"];
    if (guestHomeEnv.length > 0)
    {
        [key appendFormat:@"_%@", guestHomeEnv];
    }
    
    return [key copy];
}

#pragma mark - Account loading

- (NSArray *)loadTestAccountRequest:(MSIDAutomationBaseApiRequest *)accountRequest
{
    // Try Key Vault JSON first if available
    if (s_keyVaultAccountProvider && s_keyVaultAccountProvider.hasCachedAccounts)
    {
        // Check if this is an account configuration request we can use
        if ([accountRequest isKindOfClass:[MSIDTestAutomationAccountConfigurationRequest class]])
        {
            MSIDTestAutomationAccountConfigurationRequest *configRequest = (MSIDTestAutomationAccountConfigurationRequest *)accountRequest;
            
            // Build compound key from all request properties
            NSString *accountType = [self.class keyForAccountConfigurationRequest:configRequest];
            
            NSError *error = nil;
            NSArray<MSIDTestAutomationAccount *> *kvAccounts = [s_keyVaultAccountProvider accountsForType:accountType error:&error];
            if (kvAccounts.count > 0)
            {
                NSLog(@"[MSIDBaseUITest] Loaded %lu account(s) from Key Vault JSON with key: %@", (unsigned long)kvAccounts.count, accountType);
                
                // Load passwords for all accounts
                XCTestExpectation *passwordExpectation = [self expectationWithDescription:@"Get password from Key Vault"];
                passwordExpectation.expectedFulfillmentCount = kvAccounts.count;
                
                for (MSIDTestAutomationAccount *account in kvAccounts)
                {
                    [self.class.confProvider.passwordRequestHandler loadPasswordForTestAccount:account
                                                                             completionHandler:^(NSString *password, NSError *pwdError)
                     {
                        if (password)
                        {
                            NSLog(@"[MSIDBaseUITest] Password loaded successfully for Key Vault account: %@", account.upn);
                        }
                        else
                        {
                            NSLog(@"[MSIDBaseUITest] Failed to load password for Key Vault account %@: %@", account.upn, pwdError.localizedDescription);
                        }
                        [passwordExpectation fulfill];
                    }];
                }
                
                [self waitForExpectations:@[passwordExpectation] timeout:60];
                
                // Filter to accounts that have passwords
                NSMutableArray *accountsWithPasswords = [NSMutableArray array];
                for (MSIDTestAutomationAccount *account in kvAccounts)
                {
                    if (account.password)
                    {
                        [accountsWithPasswords addObject:account];
                    }
                }
                
                if (accountsWithPasswords.count > 0)
                {
                    return [accountsWithPasswords copy];
                }
                else
                {
                    NSLog(@"[MSIDBaseUITest] No Key Vault accounts have passwords, falling back to Lab API");
                }
            }
            else
            {
                NSLog(@"[MSIDBaseUITest] Account key '%@' not found in Key Vault JSON, falling back to Lab API. Error: %@", accountType, error.localizedDescription);
            }
        }
    }
    
    // Fall back to Lab API
    return [self loadTestAccountRequestFromLabAPI:accountRequest];
}

- (NSArray *)loadTestAccountRequestFromLabAPI:(MSIDAutomationBaseApiRequest *)accountRequest
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
        if (results && results.count > 0)
        {
            passwordLoadExpecation.expectedFulfillmentCount = results.count;
        }
        
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
    [self waitForExpectationsWithTimeout:60.0f handler:nil];
}

- (XCUIElement *)waitForEitherElements:(XCUIElement *)object1 and:(XCUIElement *)object2
{
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"%@.exists == 1 OR %@.exists == 1" argumentArray:@[object1, object2]];
    [self expectationForPredicate:existsPredicate evaluatedWithObject:nil handler:nil];
    [self waitForExpectationsWithTimeout:60.0f handler:nil];
    return object1.exists ? object1 : object2;
}

- (XCTWaiterResult)waitForElementsAndContinueIfNotAppear:(XCUIElement *)object
{
    return [self waitForElementsAndContinueIfNotAppear:object timeout:30.0f];
}

- (XCTWaiterResult)waitForElementsAndContinueIfNotAppear:(XCUIElement *)object timeout:(NSTimeInterval)timeout
{
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"%@.exists == 1" argumentArray:@[object]];

    XCTestExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:existsPredicate object:object];
    return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout enforceOrder:YES];
}

- (void)dismissCookieSharingDialogIfNecessary
{
    XCUIApplication *springBoardApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
    XCUIElement *allowButton = springBoardApp.alerts.buttons[@"Allow"];

    XCTWaiterResult waitResult = [self waitForElementsAndContinueIfNotAppear:allowButton timeout:5.0f];

    if (waitResult == XCTWaiterResultCompleted)
    {
        XCUIElement *alert = springBoardApp.alerts.element;
        BOOL isCookieAlert = [alert.label containsString:@"cookies"]
                             || [alert.label containsString:@"website data"];

        if (isCookieAlert)
        {
            [allowButton msidTap];
        }
    }
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
