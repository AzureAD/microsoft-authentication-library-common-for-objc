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
@class MSIDWebviewAction;

/**
 Handler block for custom URL actions. Invoked when a custom-scheme URL is encountered.
 The handler should determine the appropriate action and invoke the completion handler.
 
 @param url The custom-scheme URL that was encountered
 @param completionHandler Completion handler to invoke with the determined action
 */
typedef void (^MSIDCustomURLActionHandler)(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action));

/**
 This category provides generic webview response handling and custom URL action support
 for MSIDLocalInteractiveController. It enables:
 
 - Response header capture from HTTP redirects
 - Custom URL scheme handling with pluggable action handlers
 - BRT (Broker Refresh Token) attempt tracking
 - Session-level state management
 
 This is a reference implementation showing the integration pattern for enrollment flows,
 device registration, or any scenario requiring custom URL handling and header capture.
 */
@interface MSIDLocalInteractiveController (WebviewExtensions)

/**
 BRT attempt tracker for this session. Tracks BRT acquisition attempts
 to enforce attempt limits per session.
 */
@property (nonatomic, readonly, nullable) MSIDBRTAttemptTracker *brtAttemptTracker;

/**
 Response header store for this session. Captures headers from HTTP responses
 for use in subsequent requests or actions.
 */
@property (nonatomic, readonly, nullable) MSIDResponseHeaderStore *responseHeaderStore;

/**
 Set of header keys to capture from HTTP responses. If nil, common headers
 (X-Intune-AuthToken, X-Install-Url, x-ms-clitelem) are captured by default.
 Set to an empty set to disable header capture.
 */
@property (nonatomic, copy, nullable) NSSet<NSString *> *capturedHeaderKeys;

/**
 Custom URL action handler. If set, this block is invoked for custom-scheme URLs
 (e.g., msauth://, browser://) to determine the appropriate action.
 If nil, default behavior is used (complete with the URL).
 */
@property (nonatomic, copy, nullable) MSIDCustomURLActionHandler customURLActionHandler;

/**
 Configure webview with response event and action decision callbacks.
 This should be called after the webview controller is created but before it is started.
 
 @param webviewController The webview controller to configure
 */
- (void)configureWebviewWithResponseHandling:(id)webviewController;

/**
 Generic handler for custom URL actions. This is a helper method that can be used
 as the customURLActionHandler or called from a custom handler implementation.
 
 It handles common patterns:
 - URLs with "enroll" host: Extracts cpurl parameter, attempts BRT if allowed
 - URLs with "installProfile" host: Opens system webview with stored headers
 - URLs with "profileInstalled" host: Continues flow in broker context
 - Other URLs: Completes with the URL
 
 @param url The custom URL to handle
 @param completionHandler Completion handler to invoke with the determined action
 */
- (void)handleCustomURLAction:(NSURL *)url
                   completion:(void(^)(MSIDWebviewAction *action))completionHandler;

@end

NS_ASSUME_NONNULL_END
