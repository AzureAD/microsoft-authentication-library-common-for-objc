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

@class MSIDInteractiveWebviewState;
@protocol MSIDInteractiveWebviewHandler;

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDWebviewControllerAction represents an asynchronous controller-level action
 that can be executed as part of the interactive webview state machine.
 
 Controller actions perform background operations (like acquiring BRT tokens or
 retrying flows in broker context) and update the state accordingly. They are
 executed by the state machine's "run until stable" loop.
 
 This is the base protocol that all controller actions must conform to.
 */
@protocol MSIDWebviewControllerAction <NSObject>

/*!
 Executes the controller action asynchronously.
 
 @param state The current webview state (will be updated by the action)
 @param handler The handler providing action implementations
 @param completion Completion block called when action finishes (success/failure).
 */
- (void)executeWithState:(MSIDInteractiveWebviewState *)state
                 handler:(id<MSIDInteractiveWebviewHandler>)handler
              completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
