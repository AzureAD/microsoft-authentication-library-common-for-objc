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

#import "MSIDClearKeychainTestAction.h"
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"

@implementation MSIDClearKeychainTestAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSIDClearKeychainTestAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_CLEAR_CACHE_ACTION_IDENTIFIER;
}

- (BOOL)needsRequestParameters
{
    return NO;
}

- (void)performActionWithParameters:(NSDictionary *)parameters
                containerController:(UIViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];

    for (NSString *itemClass in secItemClasses)
    {
        NSDictionary *clearQuery = @{(id)kSecClass : (id)itemClass};
        SecItemDelete((CFDictionaryRef)clearQuery);
    }

    MSIDAutomationTestResult *testResult = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier
                                                                                    success:YES
                                                                             additionalInfo:nil];

    if (completionBlock)
    {
        completionBlock(testResult);
    }
}

@end
