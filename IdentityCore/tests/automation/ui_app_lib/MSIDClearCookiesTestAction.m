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

#import "MSIDClearCookiesTestAction.h"
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"

@implementation MSIDClearCookiesTestAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSIDClearCookiesTestAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_CLEAR_COOKIES_ACTION_IDENTIFIER;
}

- (BOOL)needsRequestParameters
{
    return NO;
}

- (void)performActionWithParameters:(__unused NSDictionary *)parameters
                containerController:(__unused MSIDAutoViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSHTTPCookieStorage *cookieStore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    __block int count = 0;
    for (NSHTTPCookie *cookie in cookieStore.cookies)
    {
        [cookieStore deleteCookie:cookie];
        count++;
    }
    
    WKWebsiteDataStore *wkWebsiteStorage = [WKWebsiteDataStore defaultDataStore];
    WKHTTPCookieStore *wkStorage = wkWebsiteStorage.httpCookieStore;
        
    [wkStorage getAllCookies:^void (NSArray<NSHTTPCookie *> *wkCookies)
    {
        for (NSHTTPCookie *wkCookie in wkCookies)
        {
            count++;
            [wkStorage deleteCookie:wkCookie completionHandler:nil];
        }
    }];
        
    NSSet *allTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allTypes
                                               modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
                                           completionHandler:^{}];
    
    NSHTTPCookieStorage *separatedStorage = [NSHTTPCookieStorage sharedCookieStorageForGroupContainerIdentifier:@"group.com.microsoft.azureauthenticator.sso"];
    
    for (NSHTTPCookie *cookie in separatedStorage.cookies)
    {
        [separatedStorage deleteCookie:cookie];
        count++;
    }
    
    MSIDAutomationTestResult *testResult = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier
                                                                                    success:YES
                                                                             additionalInfo:@{@"cleared_items_count":@(count)}];
    if (completionBlock)
    {
        completionBlock(testResult);
    }
}

@end
