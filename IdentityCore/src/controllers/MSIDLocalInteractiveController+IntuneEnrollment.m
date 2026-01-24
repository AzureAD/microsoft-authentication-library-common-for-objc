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

#import "MSIDLocalInteractiveController+IntuneEnrollment.h"
#import "MSIDBRTAttemptTracker.h"
#import "MSIDResponseHeaderStore.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewResponseEvent.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDSystemWebViewControllerFactory.h"
#import "NSURL+MSIDExtensions.h"
#import <objc/runtime.h>

@implementation MSIDLocalInteractiveController (IntuneEnrollment)

#pragma mark - Associated Objects

static const void *kBRTAttemptTrackerKey = &kBRTAttemptTrackerKey;
static const void *kResponseHeaderStoreKey = &kResponseHeaderStoreKey;

- (MSIDBRTAttemptTracker *)brtAttemptTracker
{
    MSIDBRTAttemptTracker *tracker = objc_getAssociatedObject(self, kBRTAttemptTrackerKey);
    if (!tracker)
    {
        tracker = [[MSIDBRTAttemptTracker alloc] init];
        objc_setAssociatedObject(self, kBRTAttemptTrackerKey, tracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return tracker;
}

- (MSIDResponseHeaderStore *)responseHeaderStore
{
    MSIDResponseHeaderStore *store = objc_getAssociatedObject(self, kResponseHeaderStoreKey);
    if (!store)
    {
        store = [[MSIDResponseHeaderStore alloc] init];
        objc_setAssociatedObject(self, kResponseHeaderStoreKey, store, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return store;
}

#pragma mark - Configuration

- (void)configureWebviewForIntuneEnrollment:(id)webviewController
{
    if (![webviewController isKindOfClass:[MSIDOAuth2EmbeddedWebviewController class]])
    {
        // Not an embedded webview controller, skip configuration
        return;
    }
    
    MSIDOAuth2EmbeddedWebviewController *controller = (MSIDOAuth2EmbeddedWebviewController *)webviewController;
    
    // Set response event block to capture headers
    __weak typeof(self) weakSelf = self;
    controller.webviewResponseEventBlock = ^(MSIDWebviewResponseEvent *event) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Capture Intune-related headers (case-insensitive)
        NSDictionary *headers = event.httpHeaders;
        for (NSString *key in headers)
        {
            NSString *lowerKey = [key lowercaseString];
            if ([lowerKey isEqualToString:@"x-intune-authtoken"])
            {
                [strongSelf.responseHeaderStore setHeader:headers[key] forKey:@"X-Intune-AuthToken"];
            }
            else if ([lowerKey isEqualToString:@"x-install-url"])
            {
                [strongSelf.responseHeaderStore setHeader:headers[key] forKey:@"X-Install-Url"];
            }
            else if ([lowerKey isEqualToString:@"x-ms-clitelem"])
            {
                [strongSelf.responseHeaderStore setHeader:headers[key] forKey:@"x-ms-clitelem"];
            }
        }
        
        // TODO: Update telemetry with captured headers
    };
    
    // Set action decision block for msauth:// and browser:// URLs
    controller.webviewActionDecisionBlock = ^(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action)) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf)
        {
            completionHandler([MSIDWebviewAction continueAction]);
            return;
        }
        
        NSString *host = [url.host lowercaseString];
        
        if ([host isEqualToString:@"enroll"])
        {
            [strongSelf handleEnrollAction:url completion:completionHandler];
        }
        else if ([host isEqualToString:@"installprofile"])
        {
            [strongSelf handleInstallProfileAction:url completion:completionHandler];
        }
        else if ([host isEqualToString:@"profileinstalled"])
        {
            [strongSelf handleProfileInstalledAction:url completion:completionHandler];
        }
        else
        {
            // Default behavior: complete with the URL
            completionHandler([MSIDWebviewAction completeAction:url]);
        }
    };
}

#pragma mark - Action Handlers

- (void)handleEnrollAction:(NSURL *)url
                completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    // Extract cpurl parameter
    NSDictionary *params = [url msidQueryParameters];
    NSString *cpurl = params[@"cpurl"];
    
    if (!cpurl)
    {
        // No cpurl, cannot proceed
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"msauth://enroll missing cpurl parameter");
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    // Attempt BRT acquisition if allowed (best-effort, non-blocking)
    if (self.brtAttemptTracker.canAttemptBRT)
    {
        [self.brtAttemptTracker recordAttempt];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                         @"Attempting BRT acquisition (attempt %ld)", (long)self.brtAttemptTracker.attemptCount);
        
        // TODO: Implement actual BRT acquisition logic
        // This should be async and non-blocking. For now, we just log and continue.
        // In production, this would:
        // 1. Check if broker is available
        // 2. Attempt to acquire BRT
        // 3. Store result in telemetry
        // 4. Continue regardless of success/failure
    }
    
    // Create request to load cpurl
    NSURL *cpurlURL = [NSURL URLWithString:cpurl];
    if (!cpurlURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Invalid cpurl: %@", cpurl);
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:cpurlURL];
    completionHandler([MSIDWebviewAction loadRequestAction:request]);
}

- (void)handleInstallProfileAction:(NSURL *)url
                        completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    // Retrieve stored headers
    NSString *installUrl = [self.responseHeaderStore headerForKey:@"X-Install-Url"];
    NSString *intuneAuthToken = [self.responseHeaderStore headerForKey:@"X-Intune-AuthToken"];
    
    if (!installUrl)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"msauth://installProfile called but X-Install-Url not found in header store");
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Opening ASWebAuthenticationSession for profile installation");
    
    NSURL *installURL = [NSURL URLWithString:installUrl];
    if (!installURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Invalid X-Install-Url: %@", installUrl);
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    // Create additional headers if token is available
    NSDictionary<NSString *, NSString *> *additionalHeaders = nil;
    if (intuneAuthToken)
    {
        additionalHeaders = @{@"X-Intune-AuthToken": intuneAuthToken};
    }
    
    // Create ASWebAuthenticationSession with headers
    // In production, this would be handled by creating a new system webview controller
    // TODO: Implement actual ASWebAuthenticationSession creation
    // For reference implementation, we log and cancel the embedded webview
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Would open ASWebAuthenticationSession with URL: %@ and headers: %@",
                     installURL, additionalHeaders);
    
    // Return cancel action since embedded webview flow is done
    completionHandler([MSIDWebviewAction cancelAction]);
}

- (void)handleProfileInstalledAction:(NSURL *)url
                          completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Profile installation completed, determining next action");
    
    // Check if broker context is available
    // In production, this would check broker availability and context
    BOOL hasBrokerContext = NO; // TODO: Implement actual broker context check
    
    if (hasBrokerContext)
    {
        // Continue broker flow with profileInstalled indication
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                         @"Continuing broker flow after profile installation");
        completionHandler([MSIDWebviewAction completeAction:url]);
    }
    else
    {
        // Retry entire token request in broker context
        // This is handled by existing architecture - the error will trigger broker retry
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                         @"Retrying token request in broker context after profile installation");
        
        // TODO: In production, this would set up state to retry in broker context
        // For now, complete with the URL and let existing logic handle it
        completionHandler([MSIDWebviewAction completeAction:url]);
    }
}

@end
