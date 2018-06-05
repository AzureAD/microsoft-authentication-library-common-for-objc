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
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPKeyAuthHandler.h"

#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#endif

@implementation MSIDAADOAuthEmbeddedWebviewController

- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         configuration:(MSIDWebviewConfiguration *)configuration
               context:(id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    // Currently Apple has a bug in iOS about WKWebview handling NSURLAuthenticationMethodClientCertificate.
    // It swallows the challenge response rather than sending it to server.
    // Therefore we work around the bug by using PKeyAuth for WPJ challenge in iOS
    NSMutableDictionary *headers;
    if (configuration.customHeaders)
    {
        headers = [[NSMutableDictionary alloc] initWithDictionary:configuration.customHeaders];
    }
    else
    {
        headers = [NSMutableDictionary new];
    }
    [headers setValue:kMSIDPKeyAuthHeaderVersion forKey:kMSIDPKeyAuthHeader];
    
    configuration.customHeaders = headers;
#endif
    
    return [super initWithStartURL:startURL endURL:endURL webview:webview configuration:configuration context:context];
}

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    NSString *requestURLString = [requestURL.absoluteString lowercaseString];
    
    // Stop at broker
    if ([requestURL.scheme.lowercaseString isEqualToString:@"msauth"])
    {
        self.complete = YES;
        
        NSURL *url = navigationAction.request.URL;
        [self completeWebAuthWithURL:url];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([requestURL.scheme.lowercaseString isEqualToString:@"browser"])
    {
        self.complete = YES;
        requestURLString = [requestURLString stringByReplacingOccurrencesOfString:@"browser://" withString:@"https://"];
        
#if TARGET_OS_IPHONE
        if (![MSIDAppExtensionUtil isExecutingInAppExtension])
        {
            [self cancel];
            [MSIDAppExtensionUtil sharedApplicationOpenURL:[[NSURL alloc] initWithString:requestURLString]];
        }
        else
        {
            MSID_LOG_INFO(self.context, @"unable to redirect to browser from extension");
        }
#else
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:requestURLString]];
#endif
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
#if TARGET_OS_IPHONE
    // check for pkeyauth challenge.
    if ([requestURLString hasPrefix:[kMSIDPKeyAuthUrn lowercaseString]])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        [MSIDPKeyAuthHandler handleChallenge:requestURL.absoluteString
                                     context:self.context
                           completionHandler:^(NSURLRequest *challengeResponse, NSError *error) {
                               if (!challengeResponse)
                               {
                                   [self endWebAuthWithURL:nil error:error];
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
