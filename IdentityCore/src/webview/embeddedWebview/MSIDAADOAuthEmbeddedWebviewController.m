//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPKeyAuthHandler.h"

@implementation MSIDAADOAuthEmbeddedWebviewController

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestUrl = navigationAction.request.URL;
    NSString *requestUrlString = [requestUrl.absoluteString lowercaseString];
    
    // Stop at broker
    if ([[[requestUrl scheme] lowercaseString] isEqualToString:@"msauth"])
    {
        self.complete = YES;
        
        NSURL *url = navigationAction.request.URL;
        [self completeWebAuthWithURL:url];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([[[requestUrl scheme] lowercaseString] isEqualToString:@"browser"])
    {
        self.complete = YES;
        requestUrlString = [requestUrlString stringByReplacingOccurrencesOfString:@"browser://" withString:@"https://"];
        
#if TARGET_OS_IPHONE
        if (![MSIDAppExtensionUtil isExecutingInAppExtension])
        {
            [self cancel];
            [MSIDAppExtensionUtil sharedApplicationOpenURL:[[NSURL alloc] initWithString:requestUrlString]];
        }
        else
        {
            MSID_LOG_INFO(self.context, @"unable to redirect to browser from extension");
        }
#else
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:requestUrlString]];
#endif
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
#if TARGET_OS_IPHONE
    // check for pkeyauth challenge.
    if ([requestUrlString hasPrefix:[kMSIDPKeyAuthUrn lowercaseString]])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        [MSIDPKeyAuthHandler handleChallenge:requestUrl.absoluteString
                                     context:self.context
                           completionHandler:^(NSURLRequest *challengeResponse, NSError *error) {
                               if (!challengeResponse)
                               {
                                   [self endWebAuthWithError:error orURL:nil];
                                   return;
                               }
                               [self loadRequest:challengeResponse];
                           }];
        return;
    }
#endif
    
    [super decidePolicyForNavigationAction:navigationAction webview:webView decisionHandler:decisionHandler];
}

@end
