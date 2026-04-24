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

#import "MSIDSystemWebviewManager.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDMainThreadUtil.h"

@interface MSIDSystemWebviewManager()

// Strong reference to keep the session alive until completion.
@property (nonatomic) MSIDSystemWebviewController *webviewController;

// Atomic flag - safe to read from any thread.
@property (atomic) BOOL isSessionInProgress;

@end

@implementation MSIDSystemWebviewManager

#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static MSIDSystemWebviewManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#if (TARGET_OS_IPHONE || TARGET_OS_OSX) && !MSID_EXCLUDE_SYSTEMWV

#pragma mark - Launch

- (void)launchSystemWebviewWithURL:(NSURL *)URL
                       redirectURI:(NSString *)redirectURL
                  parentController:(MSIDViewController *)parentController
          useAuthenticationSession:(BOOL)useAuthenticationSession
         allowSafariViewController:(BOOL)allowSafariViewController
               useEphemeralSession:(BOOL)useEphemeralSession
                 additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                           context:(id<MSIDRequestContext>)context
                   completionBlock:(MSIDWebUICompletionHandler)completionBlock
{
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewManager] Cannot launch session with nil completionBlock");
        return;
    }

    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        
        if (self.isSessionInProgress)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"[MSIDSystemWebviewManager] Session already in progress, ignoring new request");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning,
                                             @"System webview session already in progress",
                                             nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }
        
        if (!URL)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewManager] Cannot launch session with nil URL");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                             @"System webview session called with no url",
                                             nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"[MSIDSystemWebviewManager] Launching session with URL: %@, useAuthSession: %d, allowSafari: %d",
                              MSID_PII_LOG_MASKABLE(URL), useAuthenticationSession, allowSafariViewController);
        
        if (additionalHeaders.count > 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"[MSIDSystemWebviewManager] Additional headers provided: %lu", (unsigned long)additionalHeaders.count);
        }

        // Mark session as in progress before creating the controller so the guard blocks any concurrent launches.
        self.isSessionInProgress = YES;

        self.webviewController = [[MSIDSystemWebviewController alloc] initWithStartURL:URL
                                                                           redirectURI:redirectURL
                                                                      parentController:parentController
                                                              useAuthenticationSession:useAuthenticationSession
                                                             allowSafariViewController:allowSafariViewController
                                                            ephemeralWebBrowserSession:useEphemeralSession
                                                                     additionalHeaders:additionalHeaders
                                                                               context:context];
        if (!self.webviewController)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewManager] Failed to create system webview controller");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                             @"Failed to create system webview controller",
                                             nil, nil, nil, context.correlationId, nil, YES);
            self.isSessionInProgress = NO;
            completionBlock(nil, error);
            return;
        }
        
        [self.webviewController startWithCompletionHandler:^(NSURL *callbackURL, NSError *error)
         {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"[MSIDSystemWebviewManager] Session completed with callback: %@, error: %@",
                                  MSID_PII_LOG_MASKABLE(callbackURL), error);
            
            // Nil out to release session and mark isSessionInProgress as NO
            self.webviewController = nil;
            self.isSessionInProgress = NO;
            
            if (completionBlock) completionBlock(callbackURL, error);
        }];
    }];
}

#endif

@end
