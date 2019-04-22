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

#import "MSIDAutomationMainViewController.h"
#import "MSIDAutomationRequestViewController.h"
#import "MSIDAutomationResultViewController.h"
#import "MSIDAutomation.h"
#import "MSIDAutomationPassedInWebViewController.h"
#import "MSIDAutomationActionManager.h"
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationTestRequest.h"

@interface MSIDAutomationMainViewController ()

@property (nonatomic, strong) IBOutlet NSStackView *actionsView;
@property (atomic, class) NSMutableString *resultLogs;

@end

@implementation MSIDAutomationMainViewController

- (void)showActionSelectionView
{
    [self selectTabViewAtIndex:0];
}

- (void)showRequestDataViewWithCompletionHandler:(MSIDAutoParamBlock)completionHandler
{
    [self selectTabViewAtIndex:1];
    MSIDAutomationRequestViewController *requestController = (MSIDAutomationRequestViewController *) [self viewControllerAtIndex:1];
    requestController.completionBlock = completionHandler;
    requestController.requestInfo.string = @"";
}

- (void)showResultViewWithResult:(NSDictionary *)resultJson logs:(NSString *)resultLogs
{
    [self selectTabViewAtIndex:2];
    MSIDAutomationResultViewController *resultController = (MSIDAutomationResultViewController *) [self viewControllerAtIndex:2];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:resultJson options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    resultController.resultInfoString = jsonString;
    resultController.resultLogsString = resultLogs;
}

- (void)selectTabViewAtIndex:(NSUInteger)index
{
    NSTabViewController *tabViewController = (NSTabViewController *) self.parentViewController;
    tabViewController.selectedTabViewItemIndex = index;
}

- (NSViewController *)viewControllerAtIndex:(NSUInteger)index
{
    NSTabViewController *tabViewController = (NSTabViewController *) self.parentViewController;
    return tabViewController.tabViewItems[index].viewController;
}

- (void)showPassedInWebViewControllerWithContext:(NSDictionary *)context
{
    [self selectTabViewAtIndex:3];
}

- (WKWebView *)passedinWebView
{
    MSIDAutomationPassedInWebViewController *webViewController = (MSIDAutomationPassedInWebViewController *) [self viewControllerAtIndex:3];
    return webViewController.passedInWebview;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupActions];
}

#pragma mark - Logger

static NSMutableString *s_resultLogs = nil;

+ (void)setResultLogs:(NSMutableString *)resultLogs
{
    @synchronized (self)
    {
        s_resultLogs = resultLogs;
    }
}

+ (NSMutableString *)resultLogs
{
    @synchronized (self)
    {
        return s_resultLogs;
    }
}

+ (void)forwardIdentitySDKLog:(NSString *)logLine
{
    if (!self.resultLogs)
    {
        return;
    }
    
    @synchronized (self)
    {
        [self.resultLogs appendString:logLine];
    }
}

#pragma mark - Actions

- (void)setupActions
{
    NSArray *testActions = [[MSIDAutomationActionManager sharedInstance] actionIdentifiers];
    for (NSString *testAction in testActions)
    {
        NSButton *button = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
        button.title = testAction;
        button.accessibilityLabel = testAction;
        button.target = self;
        button.action = @selector(performAction:);
        [self.actionsView addView:button inGravity:NSStackViewGravityBottom];
    }
}

- (void)performAction:(NSButton *)sender
{
    self.class.resultLogs = [NSMutableString new];

    id<MSIDAutomationTestAction> action = [[MSIDAutomationActionManager sharedInstance] actionForIdentifier:sender.title];

    if (!action)
    {
        NSLog(@"Couldn't find action for identifier %@", sender.title);
        return;
    }

    if (!action.needsRequestParameters)
    {
        [self performAction:action parameters:nil];
        return;
    }

    MSIDAutoParamBlock completionBlock = ^void (MSIDAutomationTestRequest * parameters)
    {
        if (!parameters)
        {
            MSIDAutomationTestResult *testResult = [[MSIDAutomationTestResult alloc] initWithAction:action.actionIdentifier success:NO additionalInfo:nil];
            [self showResultViewWithResult:testResult.jsonDictionary logs:self.class.resultLogs];
            return;
        }

        [self performAction:action parameters:parameters];
    };

    [self showRequestDataViewWithCompletionHandler:completionBlock];
}

- (void)performAction:(id<MSIDAutomationTestAction>)action parameters:(MSIDAutomationTestRequest *)parameters
{
    [action performActionWithParameters:parameters
                    containerController:self
                        completionBlock:^(MSIDAutomationTestResult *result) {
                            [self showResultViewWithResult:result.jsonDictionary logs:self.class.resultLogs];

                        }];
}

@end
