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

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class MSIDWebviewAction;
@class MSIDInteractiveWebviewState;
@protocol MSIDInteractiveWebviewHandler;

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDInteractiveWebviewStateMachine orchestrates the handling of special URLs
 (msauth:// and browser://) in embedded webviews.
 
 This state machine implements a controller-action pattern where:
 - Controller actions (e.g., AcquireBRTOnce, RetryInBroker) are async operations
   that update state and execute via a "run until stable" loop
 - View actions (MSIDWebviewAction) are returned to the webview controller for execution
 
 The state machine flow:
 1. handleSpecialURL:navigationAction:completion: is called when a special URL is intercepted
 2. The state machine runs controller actions until reaching a stable state
 3. A view action is resolved via the handler and returned to the caller
 
 Intended usage:
 
 // In MSIDOAuth2EmbeddedWebviewController (or similar):
 // When decidePolicyForNavigationAction is called for msauth:// or browser://
 
 MSIDInteractiveWebviewStateMachine *stateMachine = [[MSIDInteractiveWebviewStateMachine alloc] initWithHandler:self];
 
 [stateMachine handleSpecialURL:url
                 navigationAction:navigationAction
                       completion:^(MSIDWebviewAction *action, NSError *error) {
     if (error) {
         // Handle error
         return;
     }
     
     // Execute the returned view action
     switch (action.type) {
         case MSIDWebviewActionTypeLoadRequestInWebview:
             [self loadRequest:action.request];
             break;
         case MSIDWebviewActionTypeOpenASWebAuthenticationSession:
             [self openASWebAuthSession:action.url purpose:action.purpose];
             break;
         // ... handle other action types
     }
 }];
 
 Note: This is a placeholder implementation. Default behavior returns CompleteWithURL
 or delegates to handler's viewActionForSpecialURL:state: for safe integration.
 */
@interface MSIDInteractiveWebviewStateMachine : NSObject

/*! The handler that provides policy decisions and action implementations */
@property (nonatomic, weak, readonly) id<MSIDInteractiveWebviewHandler> handler;

/*! Current state of the webview flow */
@property (nonatomic, strong, readonly) MSIDInteractiveWebviewState *state;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/*!
 Initializes the state machine with a handler.
 @param handler The handler that provides policy decisions and action implementations.
 @return An initialized state machine.
 */
- (instancetype)initWithHandler:(id<MSIDInteractiveWebviewHandler>)handler;

/*!
 Handles a special URL intercepted during webview navigation.
 
 This method:
 1. Updates state with the URL and context
 2. Runs controller actions until reaching a stable state (runUntilStable)
 3. Resolves and returns a view action for the webview controller to execute
 
 @param url The special URL (msauth:// or browser://) being processed
 @param navigationAction The WKNavigationAction that triggered this call (optional)
 @param completion Completion block called with the view action to execute, or error if processing failed.
 */
- (void)handleSpecialURL:(NSURL *)url
        navigationAction:(WKNavigationAction * _Nullable)navigationAction
              completion:(void (^)(MSIDWebviewAction * _Nullable action, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
