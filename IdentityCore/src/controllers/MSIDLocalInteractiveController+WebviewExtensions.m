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

#import "MSIDLocalInteractiveController+WebviewExtensions.h"
#import "MSIDBRTAttemptTracker.h"
#import "MSIDResponseHeaderStore.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewSessionManager.h"
#import <objc/runtime.h>

@implementation MSIDLocalInteractiveController (WebviewExtensions)

#pragma mark - Associated Objects

static const void *kWebviewSessionManagerKey = &kWebviewSessionManagerKey;

- (MSIDWebviewSessionManager *)webviewSessionManager
{
    MSIDWebviewSessionManager *manager = objc_getAssociatedObject(self, kWebviewSessionManagerKey);
    if (!manager)
    {
        manager = [[MSIDWebviewSessionManager alloc] initWithController:self];
        objc_setAssociatedObject(self, kWebviewSessionManagerKey, manager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return manager;
}

#pragma mark - Convenience Accessors (Delegate to Manager)

- (MSIDBRTAttemptTracker *)brtAttemptTracker
{
    return self.webviewSessionManager.brtAttemptTracker;
}

- (MSIDResponseHeaderStore *)responseHeaderStore
{
    return self.webviewSessionManager.responseHeaderStore;
}

- (NSSet<NSString *> *)capturedHeaderKeys
{
    return self.webviewSessionManager.capturedHeaderKeys;
}

- (void)setCapturedHeaderKeys:(NSSet<NSString *> *)capturedHeaderKeys
{
    self.webviewSessionManager.capturedHeaderKeys = capturedHeaderKeys;
}

- (MSIDCustomURLActionHandler)customURLActionHandler
{
    return self.webviewSessionManager.customURLActionHandler;
}

- (void)setCustomURLActionHandler:(MSIDCustomURLActionHandler)customURLActionHandler
{
    self.webviewSessionManager.customURLActionHandler = customURLActionHandler;
}

#pragma mark - Configuration (Delegate to Manager)

- (void)configureWebviewWithResponseHandling:(id)webviewController
{
    [self.webviewSessionManager configureWebview:webviewController];
}

- (void)handleCustomURLAction:(NSURL *)url
                   completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    [self.webviewSessionManager handleCustomURLAction:url completion:completionHandler];
}

@end
