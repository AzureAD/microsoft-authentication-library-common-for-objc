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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Action types that can be performed by the webview controller
 * in response to navigation events (msauth://, browser://, etc.)
 */
typedef NS_ENUM(NSInteger, MSIDWebviewNavigationActionType)
{
    /// Continue with default webview behavior (delegate did not handle)
    MSIDWebviewNavigationActionTypeContinueDefault = 0,
    
    /// Load the specified request in the embedded webview
    MSIDWebviewNavigationActionTypeLoadRequestInWebview,

    /// Complete authentication with the provided URL
    MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL,
    
    /// Fail authentication with the provided error
    MSIDWebviewNavigationActionTypeFailWithError
};

/**
 * Represents an action to be performed by the webview controller
 * in response to a navigation event.
 *
 * This is returned by MSIDWebviewNavigationDelegate to instruct the webview
 * controller how to handle redirect URLs like msauth:// or browser://.
 */
@interface MSIDWebviewNavigationAction : NSObject

/// The type of action to perform
@property (nonatomic) MSIDWebviewNavigationActionType type;

/// The request to load (used with LoadRequestInWebview)
@property (nonatomic, nullable) NSURLRequest *request;

/// The URL to open or complete with (used with various action types)
@property (nonatomic, nullable) NSURL *url;

/// The error to fail with (used with FailWithError)
@property (nonatomic, nullable) NSError *error;

#pragma mark - Factory Methods

/**
 * Create an action to load a request in the embedded webview.
 * Used for scenarios like enrollment, compliance flows.
 *
 * @param request The NSURLRequest to load with custom headers/params
 * @return Action object with type LoadRequestInWebview
 */
+ (instancetype)loadRequestAction:(NSURLRequest *)request;

/**
 * Create an action to complete webview authentication with a URL.
 * Used for completing webview authentication flow with callback URL.
 *
 * @param url The URL to complete webview authentication with
 * @return Action object with type CompleteWithURL
 */
+ (instancetype)completeWebAuthWithURLAction:(NSURL *)url;

/**
 * Create an action to fail webview authentication with an error.
 * Used when validation fails or errors occur during handling.
 *
 * @param error The error describing why webview authentication failed
 * @return Action object with type FailWithError
 */
+ (instancetype)failWebAuthWithErrorAction:(NSError *)error;

/**
 * Create an action to continue with default webview behavior.
 * Used when delegate inspects the URL but decides not to handle it specially.
 * This tells the webview controller to proceed with normal completion logic.
 *
 * @return Action object with type ContinueDefault
 */
+ (instancetype)continueDefaultAction;

#pragma mark - Validation

/**
 * Validates that the action has all required properties for its type.
 *
 * Validation rules:
 * - LoadRequestInWebview: requires 'request' property
 * - CompleteWithURL: requires 'url' property
 * - FailWithError: requires 'error' property
 * - ContinueDefault: always valid
 *
 * @return YES if the action is valid, NO otherwise
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
