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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDInteractiveWebviewStateMachine.h"
#import "MSIDInteractiveWebviewState.h"
#import "MSIDInteractiveWebviewHandler.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewControllerAction.h"
#import "MSIDAcquireBRTOnceControllerAction.h"
#import "MSIDRetryInBrokerControllerAction.h"
#import "NSURL+MSIDExtensions.h"

@interface MSIDInteractiveWebviewStateMachine ()

@property (nonatomic, weak, readwrite) id<MSIDInteractiveWebviewHandler> handler;
@property (nonatomic, strong, readwrite) MSIDInteractiveWebviewState *state;

@end

@implementation MSIDInteractiveWebviewStateMachine

- (instancetype)initWithHandler:(id<MSIDInteractiveWebviewHandler>)handler
{
    self = [super init];
    if (self)
    {
        _handler = handler;
        _state = [[MSIDInteractiveWebviewState alloc] init];
    }
    return self;
}

- (void)handleSpecialURL:(NSURL *)url
        navigationAction:(WKNavigationAction *)navigationAction
              completion:(void (^)(MSIDWebviewAction * _Nullable action, NSError * _Nullable error))completion
{
    if (!url)
    {
        completion(nil, [NSError errorWithDomain:@"MSIDErrorDomain"
                                            code:-1
                                        userInfo:@{NSLocalizedDescriptionKey: @"URL cannot be nil"}]);
        return;
    }
    
    // Update state with current URL context
    self.state.pendingURL = url;
    self.state.queryParams = [url msidQueryParameters];
    
    // Check if this is a special scheme (msauth:// or browser://)
    NSString *scheme = url.scheme.lowercaseString;
    self.state.isGateScheme = [scheme isEqualToString:@"msauth"] || [scheme isEqualToString:@"browser"];
    
    // Check if running in broker context
    self.state.isRunningInBrokerContext = [self.handler isRunningInBrokerContext];
    
    // Run controller actions until reaching a stable state
    [self runUntilStableWithCompletion:^(BOOL success, NSError * _Nullable error) {
        if (!success && error)
        {
            completion(nil, error);
            return;
        }
        
        // Resolve the view action to return
        MSIDWebviewAction *action = [self resolveViewActionForURL:url];
        completion(action, nil);
    }];
}

#pragma mark - Private Methods

/*!
 Runs controller actions until the state machine reaches a stable state.
 This implements a "run until stable" loop where controller actions can
 trigger state changes that lead to additional actions.
 
 Placeholder implementation: Currently just completes immediately.
 Future enhancement will run nextControllerActionForState: in a loop.
 */
- (void)runUntilStableWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // Placeholder: Determine next controller action based on state
    id<MSIDWebviewControllerAction> nextAction = [self nextControllerActionForState:self.state];
    
    if (!nextAction)
    {
        // No controller actions needed, state is stable
        completion(YES, nil);
        return;
    }
    
    // Execute the controller action
    [nextAction executeWithState:self.state
                         handler:self.handler
                      completion:^(BOOL success, NSError * _Nullable error) {
        if (!success)
        {
            // Handle failure based on policy
            if (self.state.brtFailurePolicy == MSIDInteractiveWebviewBRTFailurePolicyFail && error)
            {
                completion(NO, error);
                return;
            }
        }
        
        // Continue running until stable (recursive call)
        // In production, add loop detection to prevent infinite recursion
        [self runUntilStableWithCompletion:completion];
    }];
}

/*!
 Determines the next controller action to execute based on current state.
 
 Placeholder implementation with basic logic:
 - If BRT should be acquired and hasn't been attempted: return AcquireBRTOnce
 - If should retry in broker and not yet transferred: return RetryInBroker
 - Otherwise: return nil (state is stable)
 
 @param state Current webview state
 @return The next controller action to execute, or nil if state is stable.
 */
- (id<MSIDWebviewControllerAction> _Nullable)nextControllerActionForState:(MSIDInteractiveWebviewState *)state
{
    // Check if we should acquire BRT
    // Check if BRT needs to be acquired
    // Allow retry if: not yet acquired AND haven't tried twice yet (max 2 attempts)
    if (state.isGateScheme &&
        [self.handler shouldAcquireBRTForSpecialURL:state.pendingURL state:state] &&
        !state.brtAcquired &&
        state.brtAttemptCount < 2)
    {
        // Set the failure policy
        state.brtFailurePolicy = [self.handler brtFailurePolicyForSpecialURL:state.pendingURL state:state];
        return [[MSIDAcquireBRTOnceControllerAction alloc] init];
    }
    
    // Check if we should retry in broker
    if ([self.handler shouldRetryInBrokerForSpecialURL:state.pendingURL state:state] &&
        !state.transferredToBroker)
    {
        return [[MSIDRetryInBrokerControllerAction alloc] initWithURL:state.pendingURL];
    }
    
    // State is stable, no more actions needed
    return nil;
}

/*!
 Resolves the final view action to return to the webview controller.
 
 Placeholder implementation:
 1. First tries to get action from handler's viewActionForSpecialURL:state:
 2. If handler returns nil, returns CompleteWithURL as safe default
 
 @param url The URL being processed
 @return The view action to execute.
 */
- (MSIDWebviewAction *)resolveViewActionForURL:(NSURL *)url
{
    // Try handler's resolver first
    MSIDWebviewAction *action = [self.handler viewActionForSpecialURL:url state:self.state];
    
    if (action)
    {
        return action;
    }
    
    // Default safe behavior: complete with the URL
    // This ensures existing flows aren't broken
    return [MSIDWebviewAction completeWithURLAction:url];
}

@end
