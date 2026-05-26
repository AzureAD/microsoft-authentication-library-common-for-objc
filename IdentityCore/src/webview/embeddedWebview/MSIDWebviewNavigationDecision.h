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
 * Decision types returned by MSIDWebviewNavigationDelegate to instruct the
 * webview controller how to handle navigation events (msauth://, browser://, etc.)
 */
typedef NS_ENUM(NSInteger, MSIDWebviewNavigationDecisionType)
{
    /// Continue with default webview behavior (delegate did not handle)
    MSIDWebviewNavigationDecisionContinueDefault = 0,
    
    /// Load the specified request in the embedded webview
    MSIDWebviewNavigationDecisionLoadRequest,
    
    /// Complete authentication with the provided URL
    MSIDWebviewNavigationDecisionCompleteWithURL,
    
    /// Fail authentication with the provided error
    MSIDWebviewNavigationDecisionFailWithError
};

/**
 * Represents a decision returned by MSIDWebviewNavigationDelegate to instruct
 * the webview controller how to handle navigation events (e.g. redirect URLs
 * like msauth:// or browser://).
 *
 */
@interface MSIDWebviewNavigationDecision : NSObject

/// The type of decision returned
@property (nonatomic) MSIDWebviewNavigationDecisionType type;

/// The request to load (used with LoadRequest)
@property (nonatomic, nullable) NSURLRequest *request;

/// The URL to open or complete with (used with various decision types)
@property (nonatomic, nullable) NSURL *URL;

/// The error to fail with (used with FailWithError)
@property (nonatomic, nullable) NSError *error;

#pragma mark - Factory Methods

/**
 * Create a decision to load a request in the embedded webview.
 * Used for scenarios like enrollment, compliance flows.
 *
 * @param request The NSURLRequest to load with custom headers/params
 * @return Decision object with type LoadRequest
 */
+ (instancetype)loadRequest:(NSURLRequest *)request;

/**
 * Create a decision to complete webview authentication with a URL.
 * Used for completing webview authentication flow with callback URL.
 *
 * @param URL The URL to complete webview authentication with
 * @return Decision object with type CompleteWithURL
 */
+ (instancetype)completeWithURL:(NSURL *)URL;

/**
 * Create a decision to fail webview authentication with an error.
 * Used when validation fails or errors occur during handling.
 *
 * @param error The error describing why webview authentication failed
 * @return Decision object with type FailWithError
 */
+ (instancetype)failWithError:(NSError *)error;

/**
 * Create a decision to continue with default webview behavior.
 * Used when delegate inspects the URL but decides not to handle it specially.
 * This tells the webview controller to proceed with normal completion logic.
 *
 * @return Decision object with type ContinueDefault
 */
+ (instancetype)continueDefault;

#pragma mark - Validation

/**
 * Validates that the decision has all required properties for its type.
 *
 * Validation rules:
 * - LoadRequest: requires 'request' property
 * - CompleteWithURL: requires 'url' property
 * - FailWithError: requires 'error' property
 * - ContinueDefault: always valid
 *
 * @return YES if the decision is valid, NO otherwise
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
