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

NS_ASSUME_NONNULL_BEGIN

/*!
 Policy to apply when BRT acquisition fails during special URL handling.
 */
typedef NS_ENUM(NSInteger, MSIDInteractiveWebviewBRTFailurePolicy)
{
    /*! Continue the webview flow despite BRT failure */
    MSIDInteractiveWebviewBRTFailurePolicyContinue = 0,
    
    /*! Fail the entire webview flow when BRT acquisition fails */
    MSIDInteractiveWebviewBRTFailurePolicyFail
};

/*!
 MSIDInteractiveWebviewState maintains session state for the interactive webview controller
 during special URL processing (msauth:// and browser:// schemes).
 
 This state tracks:
 - BRT (Broker Refresh Token) acquisition status and policies
 - Current URL being processed and its parameters
 - Whether the flow has been transferred to broker context
 - Contextual flags for policy decisions
 
 The state is updated by controller actions and used to determine the next action
 in the state machine.
 */
@interface MSIDInteractiveWebviewState : NSObject

#pragma mark - BRT Session Flags

/*! Whether a special URL requiring BRT has been encountered */
@property (nonatomic, assign) BOOL brtGateEncountered;

/*! Whether BRT acquisition has been attempted (prevents retry loops) */
@property (nonatomic, assign) BOOL brtAttempted;

/*! Whether BRT was successfully acquired */
@property (nonatomic, assign) BOOL brtAcquired;

/*! Policy to apply if BRT acquisition fails */
@property (nonatomic, assign) MSIDInteractiveWebviewBRTFailurePolicy brtFailurePolicy;

#pragma mark - Current Intercept Context

/*! The special URL currently being processed */
@property (nonatomic, strong, nullable) NSURL *pendingURL;

/*! Query parameters extracted from the pending URL */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *queryParams;

/*! Whether the pending URL uses a special scheme (msauth:// or browser://) */
@property (nonatomic, assign) BOOL isGateScheme;

/*! Whether the current flow is running in broker context */
@property (nonatomic, assign) BOOL isRunningInBrokerContext;

#pragma mark - Flow Transition

/*! Whether the flow has been transferred to broker for completion */
@property (nonatomic, assign) BOOL transferredToBroker;

@end

NS_ASSUME_NONNULL_END
