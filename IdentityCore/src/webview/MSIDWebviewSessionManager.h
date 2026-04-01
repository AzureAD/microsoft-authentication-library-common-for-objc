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

NS_ASSUME_NONNULL_BEGIN

@class MSIDBRTAttemptTracker;
@class MSIDResponseHeaderStore;
@class MSIDWebviewAction;
@protocol MSIDRequestContext;

/**
 Handler block for custom URL actions. Invoked when a custom-scheme URL is encountered.
 The handler should determine the appropriate action and invoke the completion handler.
 
 @param url The custom-scheme URL that was encountered
 @param completionHandler Completion handler to invoke with the determined action
 */
typedef void (^MSIDCustomURLActionHandler)(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action));

/**
 Protocol that defines the minimum requirements for a controller to use MSIDWebviewSessionManager.
 This allows the manager to access necessary context from any controller (local or broker).
 */
@protocol MSIDWebviewSessionControlling <NSObject>

@required
/**
 Request context for logging and correlation.
 */
@property (nonatomic, readonly, nullable) id<MSIDRequestContext> requestParameters;

@end

/**
 MSIDWebviewSessionManager manages webview session state and provides generic response
 handling and custom URL action support for interactive authentication flows.
 
 This manager can be used by any controller (MSIDLocalInteractiveController,
 MSIDBrokerInteractiveController, etc.) via composition, enabling code reuse across
 broker and non-broker contexts.
 
 Key responsibilities:
 - Response header capture from HTTP redirects
 - Custom URL scheme handling with pluggable action handlers
 - BRT (Broker Refresh Token) attempt tracking
 - Session-level state management
 */
@interface MSIDWebviewSessionManager : NSObject

/**
 The controller that owns this manager. Used for logging context.
 */
@property (nonatomic, weak, nullable) id<MSIDWebviewSessionControlling> controller;

/**
 BRT attempt tracker for this session. Tracks BRT acquisition attempts
 to enforce attempt limits per session.
 */
@property (nonatomic, readonly) MSIDBRTAttemptTracker *brtAttemptTracker;

/**
 Response header store for this session. Captures headers from HTTP responses
 for use in subsequent requests or actions.
 */
@property (nonatomic, readonly) MSIDResponseHeaderStore *responseHeaderStore;

/**
 Set of header keys to capture from HTTP responses. If nil, common headers
 (x-ms-clitelem, x-install-url, authorization) are captured by default.
 Set to an empty set to disable header capture.
 
 Configure this property to capture custom headers specific to your enrollment
 or registration flow. For example:
 ```objc
 manager.capturedHeaderKeys = [NSSet setWithArray:@[
     @"x-custom-auth-token",
     @"x-enrollment-url",
     @"x-device-id"
 ]];
 ```
 */
@property (nonatomic, copy, nullable) NSSet<NSString *> *capturedHeaderKeys;

/**
 Custom URL action handler. If set, this block is invoked for custom-scheme URLs
 (e.g., msauth://, browser://) to determine the appropriate action.
 If nil, default behavior is used (complete with the URL).
 */
@property (nonatomic, copy, nullable) MSIDCustomURLActionHandler customURLActionHandler;

/**
 Initialize a new webview session manager.
 
 @param controller The controller that will use this manager (for logging context)
 @return A new manager instance
 */
- (instancetype)initWithController:(nullable id<MSIDWebviewSessionControlling>)controller;

/**
 Configure webview with response event and action decision callbacks.
 This should be called after the webview controller is created but before it is started.
 
 @param webviewController The webview controller to configure
 */
- (void)configureWebview:(id)webviewController;

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
