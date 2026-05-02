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

#import "MSIDSystemWebviewTransitionManager.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDMainThreadUtil.h"
#import "MSIDCertAuthManager.h"

@interface MSIDSystemWebviewTransitionManager()

// Strong reference to keep the session alive until completion.
@property (nonatomic, strong, nullable) MSIDSystemWebviewController *activeController;

// Completion handler for current session, captured so that cancel can invoke it explicitly if needed.
@property (nonatomic, copy, nullable) MSIDWebUICompletionHandler activeCompletionBlock;

@end

@implementation MSIDSystemWebviewTransitionManager

#pragma mark - Singleton
+ (instancetype)sharedInstance
{
    static MSIDSystemWebviewTransitionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#if (TARGET_OS_IPHONE || TARGET_OS_OSX) && !MSID_EXCLUDE_SYSTEMWV

#pragma mark - Session state
- (BOOL)isSessionInProgress
{
    __block BOOL result = NO;
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        result = (self.activeController != nil);
    }];
    return result;
}

#pragma mark - Launch
- (void)transitionToSystemWebviewWithURL:(NSURL *)URL
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewTransitionManager] Cannot launch system web session with nil completionBlock");
        return;
    }

    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        if (self.activeController)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"[MSIDSystemWebviewTransitionManager] Session already in progress, ignoring new request");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning, @"System webview session already in progress", nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }

        // TODO: Route CertAuthManager ASWebAuthenticationSession flow through this manager to centralize session control. Once centralized, remove this cross-session guard.
        // Issue: SystemWebviewTransitionManager depends on CertAuthManager state. It creates hidden coupling between unrelated auth flows
        if (MSIDCertAuthManager.sharedInstance.isCertAuthInProgress)
        {
            // Prevent concurrent ASWebAuthenticationSession usage across CertAuth and system webview flows
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning, @"Another system web session is already in progress", nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }

        if (!URL)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewTransitionManager] Cannot start session with nil URL");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"System webview session called with no url", nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }

        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"[MSIDSystemWebviewTransitionManager] Starting system web session with URL: %@, useAuthSession: %d, allowSafari: %d", MSID_PII_LOG_MASKABLE(URL), useAuthenticationSession, allowSafariViewController);

        if (additionalHeaders.count > 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"[MSIDSystemWebviewTransitionManager] Additional HTTP headers count: %lu", (unsigned long)additionalHeaders.count);
        }

        MSIDSystemWebviewController *controller = [[MSIDSystemWebviewController alloc] initWithStartURL:URL
                                                                                            redirectURI:redirectURL
                                                                                       parentController:parentController
                                                                               useAuthenticationSession:useAuthenticationSession
                                                                              allowSafariViewController:allowSafariViewController
                                                                             ephemeralWebBrowserSession:useEphemeralSession
                                                                                      additionalHeaders:additionalHeaders
                                                                                                context:context];

        if (!controller)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[MSIDSystemWebviewTransitionManager] Failed to create system webview controller");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to create system webview controller", nil, nil, nil, context.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }

        self.activeController = controller;
        self.activeCompletionBlock = completionBlock;

        __weak typeof(self) weakSelf = self;
        [controller startWithCompletionHandler:^(NSURL *callbackURL, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            MSIDWebUICompletionHandler capturedBlock = strongSelf.activeCompletionBlock;
            [strongSelf clearSession];
            if (capturedBlock)
            {
                capturedBlock(callbackURL, error);
            }
        }];
    }];
}

#pragma mark - Cancel
- (void)cancel
{
    [MSIDMainThreadUtil executeOnMainThreadIfNeeded:^{
        if (!self.activeController)
        {
            return;
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[MSIDSystemWebviewTransitionManager] Cancelling active system web session");
        [self.activeController cancelProgrammatically];
    }];
}

#pragma mark - Cleanup
- (void)clearSession
{
    self.activeController = nil;
    self.activeCompletionBlock = nil;
}

#endif
@end
