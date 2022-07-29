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
#import "MSIDLogger+Internal.h"
#import "MSIDAutomationTestRequest.h"
#import <WebKit/WebKit.h>

@interface MSIDAutomationMainViewController ()

@property (nonatomic, strong) IBOutlet UIStackView *actionsView;
@property (atomic, class) NSMutableString *resultLogs;

@end

#define MSID_SHOW_RESULT_SEGUE @"showResult"
#define MSID_SHOW_REQUEST_SEGUE @"showRequest"
#define MSID_SHOW_PASSED_IN_WEBVIEW_SEGUE @"showPassedInWebview"
#define MSID_WEBVIEW_SEGUE_KEY @"webview"
#define MSID_RESULT_INFO_SEGUE_KEY @"resultInfo"
#define MSID_RESULT_LOGS_SEGUE_KEY @"resultLogs"
#define MSID_COMPLETION_BLOCK_SEGUE_KEY @"completionHandler"

@implementation MSIDAutomationMainViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:MSID_SHOW_RESULT_SEGUE])
    {
        MSIDAutomationResultViewController *resultVC = segue.destinationViewController;
        resultVC.resultInfoString = sender[MSID_RESULT_INFO_SEGUE_KEY];
        resultVC.resultLogsString = sender[MSID_RESULT_LOGS_SEGUE_KEY];
    }
    
    if ([segue.identifier isEqualToString:MSID_SHOW_REQUEST_SEGUE])
    {
        MSIDAutomationRequestViewController *requestVC = segue.destinationViewController;
        requestVC.requestInfo.text = nil;
        requestVC.completionBlock = sender[MSID_COMPLETION_BLOCK_SEGUE_KEY];
    }
    
    if ([segue.identifier isEqualToString:MSID_SHOW_PASSED_IN_WEBVIEW_SEGUE])
    {
        MSIDAutomationPassedInWebViewController *requestVC = segue.destinationViewController;
        requestVC.passedInWebview = sender[MSID_WEBVIEW_SEGUE_KEY];
    }
}


- (void)showRequestDataViewWithCompletionHandler:(MSIDAutoParamBlock)completionHandler
{
    [self performSegueWithIdentifier:MSID_SHOW_REQUEST_SEGUE
                              sender:@{MSID_COMPLETION_BLOCK_SEGUE_KEY:completionHandler}];
}


- (void)showResultViewWithResult:(NSDictionary *)resultJson logs:(NSString *)resultLogs
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:resultJson options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    if (self.presentedViewController)
    {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [self presentResults:jsonString logs:resultLogs];
        }];
    }
    else
    {
        [self presentResults:jsonString logs:resultLogs];
    }
}

- (void)presentResults:(NSString *)resultJson logs:(NSString *)resultLogs
{
    [self performSegueWithIdentifier:MSID_SHOW_RESULT_SEGUE sender:@{MSID_RESULT_INFO_SEGUE_KEY:resultJson ? resultJson : @"",
                                                                     MSID_RESULT_LOGS_SEGUE_KEY:resultLogs ? resultLogs : @""}];
}

- (void)showPassedInWebViewControllerWithContext:(NSDictionary *)context
{
    NSMutableDictionary *sender = [@{MSID_WEBVIEW_SEGUE_KEY: self.webView} mutableCopy];

    if (context)
    {
        [sender addEntriesFromDictionary:context];
    }

    [self.webView loadHTMLString:@"<html><head></head><body>Loading...</body></html>" baseURL:nil];

    if (self.presentedViewController)
    {
        [self dismissViewControllerAnimated:NO completion:^{
            [self performSegueWithIdentifier:MSID_SHOW_PASSED_IN_WEBVIEW_SEGUE sender:sender];
        }];
    }
    else
    {
        [self performSegueWithIdentifier:MSID_SHOW_PASSED_IN_WEBVIEW_SEGUE sender:sender];
    }
}

- (WKWebView *)passedinWebView
{
    return self.webView;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.webView = [[WKWebView alloc] init];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        [button setTitle:testAction forState:UIControlStateNormal];
        [button setAccessibilityIdentifier:testAction];
        [button addTarget:self action:@selector(performAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.actionsView addArrangedSubview:button];
    }

    self.actionsView.distribution = UIStackViewDistributionFillEqually;
}

- (void)performAction:(UIButton *)sender
{
    self.class.resultLogs = [NSMutableString new];

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

    MSIDAutoParamBlock completionBlock = ^void (MSIDAutomationTestRequest *requestParams)
    {
        if (!requestParams)
        {
            MSIDAutomationTestResult *result = [[MSIDAutomationTestResult alloc] initWithAction:action.actionIdentifier success:NO additionalInfo:nil];
            [self showResultViewWithResult:result.jsonDictionary logs:self.class.resultLogs];
            return;
        }

        [self performAction:action parameters:requestParams];
    };

    [self performSegueWithIdentifier:MSID_SHOW_REQUEST_SEGUE sender:@{MSID_COMPLETION_BLOCK_SEGUE_KEY : completionBlock}];
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
