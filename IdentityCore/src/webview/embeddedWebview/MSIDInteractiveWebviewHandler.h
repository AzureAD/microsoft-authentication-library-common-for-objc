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

#import <Foundation/Foundation.h>
#import "MSIDInteractiveWebviewState.h"

@class MSIDWebviewAction;
@class MSIDWebviewResponse;

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDInteractiveWebviewHandler protocol defines the interface for handling
 special URL interception in embedded webviews.
 
 Implementers provide:
 - Policy decisions (should acquire BRT, failure policy, retry in broker)
 - Action implementations (acquire BRT, retry in broker, dismiss webview)
 - View action resolution (map special URLs to webview actions)
 - Telemetry handling
 
 This protocol is used by MSIDInteractiveWebviewStateMachine to delegate
 policy and action decisions during special URL processing.
 */
@protocol MSIDInteractiveWebviewHandler <NSObject>

#pragma mark - Context Checking

/*!
 Determines if the current flow is running in broker context.
 @return YES if running in broker, NO otherwise.
 */
- (BOOL)isRunningInBrokerContext;

#pragma mark - Policy Hooks

/*!
 Determines whether BRT should be acquired for the given special URL.
 @param url The special URL being processed
 @param state Current webview state
 @return YES if BRT should be acquired, NO otherwise.
 */
- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;

/*!
 Determines the policy to apply if BRT acquisition fails.
 @param url The special URL being processed
 @param state Current webview state
 @return The failure policy (Continue or Fail).
 */
- (MSIDInteractiveWebviewBRTFailurePolicy)brtFailurePolicyForSpecialURL:(NSURL *)url
                                                                   state:(MSIDInteractiveWebviewState *)state;

/*!
 Determines whether the flow should be retried in broker context.
 @param url The special URL being processed
 @param state Current webview state
 @return YES if should retry in broker, NO otherwise.
 */
- (BOOL)shouldRetryInBrokerForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;

#pragma mark - Action Implementations

/*!
 Attempts to acquire a Broker Refresh Token (BRT).
 @param completion Completion block called with success/failure and optional error.
 */
- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/*!
 Returns a generic error for BRT acquisition failures.
 @return An NSError indicating BRT acquisition failure.
 */
- (NSError *)genericBrtError;

/*!
 Retries the interactive request in broker context.
 @param url The URL that triggered the retry
 @param completion Completion block called with success/failure and optional error.
 */
- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url
                                          completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/*!
 Dismisses the embedded webview if it is currently presented.
 This is typically called after transferring the flow to broker context.
 */
- (void)dismissEmbeddedWebviewIfPresent;

#pragma mark - View Action Resolution

/*!
 Maps a special URL to a webview action based on current state.
 This is the primary resolver that determines what the webview should do
 (load request, open external browser, complete flow, etc.).
 
 @param url The special URL being processed
 @param state Current webview state
 @return The webview action to execute, or nil to use default handling.
 */
- (MSIDWebviewAction * _Nullable)viewActionForSpecialURL:(NSURL *)url
                                                    state:(MSIDInteractiveWebviewState *)state;

#pragma mark - Telemetry

/*!
 Handles webview response for telemetry purposes.
 @param response The webview response to record.
 */
- (void)handleWebviewResponseForTelemetry:(MSIDWebviewResponse *)response;

@end

NS_ASSUME_NONNULL_END
