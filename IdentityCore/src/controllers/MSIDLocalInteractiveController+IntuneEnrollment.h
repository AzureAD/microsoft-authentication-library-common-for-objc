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
#import "MSIDLocalInteractiveController.h"

NS_ASSUME_NONNULL_BEGIN

@class MSIDBRTAttemptTracker;
@class MSIDResponseHeaderStore;

/**
 This category demonstrates how to wire the Intune enrollment flow callbacks
 into MSIDLocalInteractiveController. This is a reference implementation showing
 the integration pattern.
 
 In production, these methods would be integrated into the main implementation
 or overridden by subclasses that need Intune enrollment support.
 */
@interface MSIDLocalInteractiveController (IntuneEnrollment)

/**
 BRT attempt tracker for this session. Tracks BRT acquisition attempts
 to enforce the 2-attempt-per-session limit.
 */
@property (nonatomic, readonly, nullable) MSIDBRTAttemptTracker *brtAttemptTracker;

/**
 Response header store for this session. Captures headers from HTTP responses
 (particularly X-Intune-AuthToken, X-Install-Url, x-ms-clitelem from 302s).
 */
@property (nonatomic, readonly, nullable) MSIDResponseHeaderStore *responseHeaderStore;

/**
 Configure webview with Intune enrollment callbacks.
 This should be called after the webview controller is created but before
 it is started.
 
 @param webviewController The webview controller to configure
 */
- (void)configureWebviewForIntuneEnrollment:(id)webviewController;

/**
 Handle msauth://enroll action. Extracts cpurl parameter, attempts BRT
 acquisition if allowed, and returns appropriate action.
 
 @param url The msauth://enroll URL
 @param completionHandler Completion handler that receives the action to execute
 */
- (void)handleEnrollAction:(NSURL *)url
                completion:(void(^)(MSIDWebviewAction *action))completionHandler;

/**
 Handle msauth://installProfile action. Opens ASWebAuthenticationSession
 with stored X-Install-Url and X-Intune-AuthToken headers.
 
 @param url The msauth://installProfile URL
 @param completionHandler Completion handler that receives the action to execute
 */
- (void)handleInstallProfileAction:(NSURL *)url
                        completion:(void(^)(MSIDWebviewAction *action))completionHandler;

/**
 Handle msauth://profileInstalled action. Continues flow in broker context
 if available, otherwise retries in broker context.
 
 @param url The msauth://profileInstalled URL
 @param completionHandler Completion handler that receives the action to execute
 */
- (void)handleProfileInstalledAction:(NSURL *)url
                          completion:(void(^)(MSIDWebviewAction *action))completionHandler;

@end

NS_ASSUME_NONNULL_END
