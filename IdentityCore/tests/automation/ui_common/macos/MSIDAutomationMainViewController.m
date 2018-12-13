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

@interface MSIDAutomationMainViewController ()

@property (nonatomic, strong) IBOutlet NSStackView *actionsView;

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

- (void)showResultViewWithResult:(NSString *)resultJson logs:(NSString *)resultLogs
{
    [self selectTabViewAtIndex:2];
    MSIDAutomationResultViewController *resultController = (MSIDAutomationResultViewController *) [self viewControllerAtIndex:2];
    resultController.resultInfoString = resultJson;
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupActions];
}

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
        [self.actionsView addArrangedSubview:button];
    }
}

- (void)performAction:(UIButton *)sender
{
    id<MSIDAutomationTestAction> action = [[MSIDAutomationActionManager sharedInstance] actionForIdentifier:sender.titleLabel.text];

    if (!action)
    {
        NSLog(@"Couldn't find action for identifier %@", sender.titleLabel.text);
        return;
    }

    if (!action.needsRequestParameters)
    {
        [self performAction:action parameters:nil];
        return;
    }

    MSIDAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        [self performAction:action parameters:parameters];
    };

    [self performSegueWithIdentifier:MSID_SHOW_REQUEST_SEGUE sender:@{MSID_COMPLETION_BLOCK_SEGUE_KEY : completionBlock}];
}

- (void)performAction:(id<MSIDAutomationTestAction>)action parameters:(NSDictionary *)parameters
{
    [action performActionWithParameters:parameters
                    containerController:self
                        completionBlock:^(NSDictionary *result, NSString *logOutput) {

                            NSData *jsonResult = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
                            NSString *jsonResultString = [[NSString alloc] initWithData:jsonResult encoding:NSUTF8StringEncoding];

                            [self showResultViewWithResult:jsonResultString logs:logOutput];

                        }];
}

@end
