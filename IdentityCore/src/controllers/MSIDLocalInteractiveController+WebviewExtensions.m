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
#import "MSIDWebviewResponseEvent.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDSystemWebViewControllerFactory.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"
#import <objc/runtime.h>

@implementation MSIDLocalInteractiveController (WebviewExtensions)

#pragma mark - Associated Objects

static const void *kBRTAttemptTrackerKey = &kBRTAttemptTrackerKey;
static const void *kResponseHeaderStoreKey = &kResponseHeaderStoreKey;
static const void *kCapturedHeaderKeysKey = &kCapturedHeaderKeysKey;
static const void *kCustomURLActionHandlerKey = &kCustomURLActionHandlerKey;

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

- (NSSet<NSString *> *)capturedHeaderKeys
{
    return objc_getAssociatedObject(self, kCapturedHeaderKeysKey);
}

- (void)setCapturedHeaderKeys:(NSSet<NSString *> *)capturedHeaderKeys
{
    objc_setAssociatedObject(self, kCapturedHeaderKeysKey, capturedHeaderKeys, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (MSIDCustomURLActionHandler)customURLActionHandler
{
    return objc_getAssociatedObject(self, kCustomURLActionHandlerKey);
}

- (void)setCustomURLActionHandler:(MSIDCustomURLActionHandler)customURLActionHandler
{
    objc_setAssociatedObject(self, kCustomURLActionHandlerKey, customURLActionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - Configuration

- (void)configureWebviewWithResponseHandling:(id)webviewController
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
        
        [strongSelf captureHeadersFromResponseEvent:event];
    };
    
    // Set action decision block for custom URL handling
    controller.webviewActionDecisionBlock = ^(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action)) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf)
        {
            completionHandler([MSIDWebviewAction continueAction]);
            return;
        }
        
        // Use custom handler if provided, otherwise use default
        if (strongSelf.customURLActionHandler)
        {
            strongSelf.customURLActionHandler(url, completionHandler);
        }
        else
        {
            [strongSelf handleCustomURLAction:url completion:completionHandler];
        }
    };
}

#pragma mark - Header Capture

- (void)captureHeadersFromResponseEvent:(MSIDWebviewResponseEvent *)event
{
    NSDictionary *headers = event.httpHeaders;
    if (!headers || headers.count == 0) return;
    
    // Determine which headers to capture
    NSSet<NSString *> *headerKeys = self.capturedHeaderKeys;
    
    // If not configured, use default common headers for backwards compatibility
    // These represent typical headers used in enrollment/registration flows
    if (headerKeys == nil)
    {
        headerKeys = [NSSet setWithArray:@[@"x-ms-clitelem", @"x-install-url", @"authorization"]];
    }
    
    // Empty set means no capture
    if (headerKeys.count == 0) return;
    
    // Capture headers (case-insensitive matching)
    for (NSString *key in headers)
    {
        NSString *lowerKey = [key lowercaseString];
        for (NSString *captureKey in headerKeys)
        {
            if ([lowerKey isEqualToString:[captureKey lowercaseString]])
            {
                [self.responseHeaderStore setHeader:headers[key] forKey:captureKey];
                break;
            }
        }
    }
}

#pragma mark - Custom URL Action Handling

- (void)handleCustomURLAction:(NSURL *)url
                   completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    if (!url || !completionHandler)
    {
        if (completionHandler) completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    NSString *host = [url.host lowercaseString];
    
    // Handle common enrollment/registration patterns
    if ([host isEqualToString:@"enroll"])
    {
        [self handleEnrollURLAction:url completion:completionHandler];
    }
    else if ([host isEqualToString:@"installprofile"])
    {
        [self handleInstallProfileURLAction:url completion:completionHandler];
    }
    else if ([host isEqualToString:@"profileinstalled"])
    {
        [self handleProfileInstalledURLAction:url completion:completionHandler];
    }
    else
    {
        // Default: complete with the URL
        completionHandler([MSIDWebviewAction completeAction:url]);
    }
}

#pragma mark - Specific URL Handlers

- (void)handleEnrollURLAction:(NSURL *)url
                    completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    // Extract continuation URL parameter (typically "cpurl")
    NSDictionary *params = [url msidQueryParameters];
    NSString *continuationURL = params[@"cpurl"];
    
    if (!continuationURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Enroll URL missing continuation parameter (cpurl)");
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
    
    // Create request to load continuation URL
    NSURL *cpurlURL = [NSURL URLWithString:continuationURL];
    if (!cpurlURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Invalid continuation URL: %@", continuationURL);
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:cpurlURL];
    completionHandler([MSIDWebviewAction loadRequestAction:request]);
}

- (void)handleInstallProfileURLAction:(NSURL *)url
                           completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    // Retrieve stored headers (using generic header store)
    // Common header names: x-install-url for the installation URL
    // authorization or similar header for authentication
    NSString *installURL = [self.responseHeaderStore headerForKey:@"x-install-url"];
    
    // Try common auth header names (authorization is standard, but could be custom)
    NSString *authToken = [self.responseHeaderStore headerForKey:@"authorization"];
    if (!authToken) {
        // Fall back to checking all stored headers for any auth-related header
        NSDictionary *allHeaders = [self.responseHeaderStore allHeaders];
        for (NSString *key in allHeaders) {
            if ([[key lowercaseString] containsString:@"auth"] || 
                [[key lowercaseString] containsString:@"token"]) {
                authToken = allHeaders[key];
                break;
            }
        }
    }
    
    if (!installURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Install profile action called but install URL not found in header store");
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Opening system webview for profile installation");
    
    NSURL *profileInstallURL = [NSURL URLWithString:installURL];
    if (!profileInstallURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                         @"Invalid install URL: %@", installURL);
        completionHandler([MSIDWebviewAction cancelAction]);
        return;
    }
    
    // Create additional headers if auth token is available
    NSDictionary<NSString *, NSString *> *additionalHeaders = nil;
    if (authToken)
    {
        // Use Authorization header (standard) or the original key if found
        additionalHeaders = @{@"Authorization": authToken};
    }
    
    // In production, this would create and start an ASWebAuthenticationSession
    // For reference implementation, we log and cancel the embedded webview
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Would open system webview with URL: %@ and headers: %@",
                     profileInstallURL, additionalHeaders);
    
    // Return cancel action since embedded webview flow is done
    completionHandler([MSIDWebviewAction cancelAction]);
}

- (void)handleProfileInstalledURLAction:(NSURL *)url
                             completion:(void(^)(MSIDWebviewAction *action))completionHandler
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Profile installation completed, determining next action");
    
    // Check if broker context is available
    // In production, this would check broker availability and context
    BOOL hasBrokerContext = NO; // TODO: Implement actual broker context check
    
    if (hasBrokerContext)
    {
        // Continue broker flow with profile installed indication
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
