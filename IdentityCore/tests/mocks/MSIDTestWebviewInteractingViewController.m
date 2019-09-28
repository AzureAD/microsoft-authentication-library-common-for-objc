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

#import "MSIDTestWebviewInteractingViewController.h"
#import "MSIDWebviewAuthorization.h"

#if TARGET_OS_IPHONE
#import "MSIDSystemWebviewController.h"
#endif

@implementation MSIDTestWebviewInteractingViewController

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (self.successAfterInterval == 0)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Interactive web session failed to start.", nil, nil, nil, nil, nil);
        completionHandler(nil, error);
    }
    else
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.successAfterInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            completionHandler([NSURL URLWithString:@"https://contoso.microsoft.com?code=SOMECODE&cloud_instance_host_name=SOME_HOST_NAME"], nil);
        });
    }
}

- (void)cancel
{
    
}


- (BOOL)isKindOfClass:(Class)aClass
{
#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV
    if (self.actAsSafariViewController || self.actAsAuthenticationSession)
    {
        return (aClass == MSIDSystemWebviewController.class);
    }
#endif
    return NO;
}

- (BOOL)handleURLResponse:(NSURL *)url
{
    return self.actAsSafariViewController || self.actAsAuthenticationSession;
}

@end

