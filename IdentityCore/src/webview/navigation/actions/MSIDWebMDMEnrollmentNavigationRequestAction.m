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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSIDWebMDMEnrollmentNavigationRequestAction.h"
#import "MSIDWebViewNavigationActionFactory.h"
#import "MSIDWebMDMEnrollmentNavigationRequest.h"

@implementation MSIDWebMDMEnrollmentNavigationRequestAction

+ (void)load
{
    [MSIDWebViewNavigationActionFactory registerNavigationAction:self forNavigationRequest:MSIDWebMDMEnrollmentNavigationRequest.class];
}

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    [self handleSpecialRedirectUrl:navigationAction];
}


- (void)handleSpecialRedirectUrl:(NSURL *)url
                      completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"MSIDLocalInteractiveController handling special redirect: %@", _PII_NULLIFY(url));
    
    // Create BRT evaluator block
    __weak typeof(self) weakSelf = self;
    BOOL (^brtEvaluator)(void) = ^BOOL {
        __strong typeof(self) strongSelf = weakSelf;
        return strongSelf ? [strongSelf shouldAcquireBRT] : NO;
    };
    
    // Create BRT handler block
    void (^brtHandler)(void(^)(BOOL success, NSError * _Nullable error)) = ^(void(^brtCompletion)(BOOL success, NSError * _Nullable error)) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            brtCompletion(NO, nil);
            return;
        }
        
        [strongSelf acquireBRTWithCompletion:^(BOOL success, NSError *error) {
            // Track BRT acquisition attempt and result
            strongSelf.brtAttempted = YES;
            
            if (error) {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.requestParameters,
                                 @"Failed to acquire BRT: %@", error);
            }
            
            if (success) {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, strongSelf.requestParameters,
                                 @"BRT acquired successfully");
                strongSelf.brtAcquired = YES;
            }
            
            // Call the completion from DelegateHelper
            brtCompletion(success, error);
        }];
    };
    
    // Delegate ALL logic to DelegateHelper
    // DelegateHelper will handle:
    // - Scheme checking (msauth://, browser://)
    // - BRT acquisition (if needed)
    // - Navigation action resolution
    // - Error handling
    [self.delegateHelper handleSpecialRedirectUrl:url
                                     brtEvaluator:brtEvaluator
                                       brtHandler:brtHandler
                                          appName:@"MSAL"
                                       appVersion:@"`1.0`"
                          externalNavigationBlock:self.currentRequest.externalDecidePolicyForBrowserAction
                                       completion:completion];
}

- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *_Nullable)headers
{
    [self.delegateHelper processResponseHeaders:headers];
}

#pragma mark - BRT Acquisition

/**
 * Acquires Broker Refresh Token (BRT)
 * This is the new logic that needs to be implemented
 */
- (void)acquireBRTWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Starting BRT acquisition.");
    
    // TODO: Implement BRT acquisition logic
    // This would involve:
    // 1. Creating BRT request with current parameters
    // 2. Executing BRT token request
    // 3. Storing BRT in cache
    // 4. Calling completion with success/failure
    
    // Placeholder implementation:
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Simulate BRT acquisition work
        // Replace with actual implementation
        BOOL success = YES; // Replace with actual logic
        NSError *error = nil;
        
        if (!success)
        {
            error = MSIDCreateError(MSIDErrorDomain,
                                   MSIDErrorInternal,
                                   @"Failed to acquire BRT",
                                   nil, nil, nil,
                                   self.requestParameters.correlationId,
                                   nil, NO);
        }

        // Call completion on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    });
}

#pragma mark - Policy Checks (Internal)

- (BOOL)shouldAcquireBRT
{
    id<MSIDRequestContext> context = self.requestParameters;
    
    // Check if already acquired successfully
    if (self.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Skipping BRT acquisition - already acquired");
        return NO;
    }
    
    // Simplified: Check if already attempted (only attempt once)
    if (self.brtAttempted)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Skipping BRT acquisition - already attempted once");
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"BRT acquisition needed for special redirect URL");
    return YES;
}
@end
