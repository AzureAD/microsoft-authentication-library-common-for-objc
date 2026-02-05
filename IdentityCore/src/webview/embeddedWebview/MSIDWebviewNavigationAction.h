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
 Defines the type of action the embedded webview controller should execute.
 These actions are returned by the state machine after processing special URLs.
 */
typedef NS_ENUM(NSInteger, MSIDWebviewNavigationActionType)
{
    /*! Continue with default webview behavior
     * Allows delegate to opt-out of handling
     */
    MSIDWebviewNavigationActionTypeContinueDefault = 0,
    
    /*! Load the specified request in the embedded webview */
    MSIDWebviewNavigationActionTypeLoadRequestInWebview,
    
    /*! Open the URL in ASWebAuthenticationSession */
    MSIDWebviewNavigationActionTypeOpenInASWebAuthenticationSession,
    
    /*! Open the URL in an external browser */
    MSIDWebviewNavigationActionTypeOpenInExternalBrowser,
    
    /*! Cancel navigation and complete web auth flow with the URL
     * Webview will call completeWebAuthWithURL
     */
    MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL,
    
    /*!  Cancel navigation and end web auth with error
     * Webview will call endWebAuthWithURL:error: */
    MSIDWebviewNavigationActionTypeFailWithError

};

/*!
 Defines the purpose for opening a system webview (ASWebAuthenticationSession or external browser).
 The purpose determines behavioral policies such as ephemeral session enforcement.
 
 Note: Ephemeral ASWebAuthenticationSession behavior is implied by purpose.
 For example, MSIDSystemWebviewPurposeInstallProfile requires ephemeral sessions
 and will be enforced by the system webview handoff handler.
 */
typedef NS_ENUM(NSInteger, MSIDSystemWebviewPurpose)
{
    /*! Unknown or unspecified purpose - default behavior */
    MSIDSystemWebviewPurposeUnknown = 0,
    
    /*! Installing a device management profile - requires ephemeral ASWebAuthenticationSession */
    MSIDSystemWebviewPurposeInstallProfile
};

/*!
 MSIDWebviewAction represents a view-level action that the embedded webview controller
 should execute in response to intercepting special URLs (msauth:// or browser://).
 
 */
@interface MSIDWebviewNavigationAction : NSObject

/*! The type of action to execute */
@property (nonatomic, readonly) MSIDWebviewNavigationActionType type;

/*! The NSURLRequest to load (for LoadRequestInWebview type) */
@property (nonatomic, readonly, nullable) NSURLRequest *request;

/*! The URL to open or complete with (for OpenASWebAuthenticationSession, OpenExternalBrowser, CompleteWithURL types) */
@property (nonatomic, readonly, nullable) NSURL *url;

/*! The purpose for opening a system webview (for OpenASWebAuthenticationSession type) */
@property (nonatomic, readonly) MSIDSystemWebviewPurpose purpose;

/*! The error to fail with (for FailWithError type) */
@property (nonatomic, readonly, nullable) NSError *error;

/*!
 Additional HTTP headers to include when executing the action.
 
 For OpenASWebAuthenticationSession actions, these headers (e.g., X-Intune-AuthToken)
 should be made available to the system webview handler for inclusion in subsequent
 requests or for other processing needs.
 
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;


- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/*!
 Creates a no-op action.
 @return A continueDefaultAction that indicates the webview should continue normal processing.
 */
+ (instancetype)continueDefaultAction;

/*!
 Creates an action to load a request in the embedded webview.
 @param request The request to load
 @return An action that will load the request in the webview.
 */
+ (instancetype)loadRequestAction:(NSURLRequest *)request;


/*!
 Creates an action to open a URL in ASWebAuthenticationSession with additional headers.
 @param url The URL to open
 @param purpose The purpose for opening the session (determines ephemeral behavior)
 @param headers Additional HTTP headers (e.g., X-Intune-AuthToken) to pass to the handler
 @return An action that will open the URL in ASWebAuthenticationSession with appropriate settings.
 */
+ (instancetype)openInASWebAuthSessionAction:(NSURL *)url
                                     purpose:(MSIDSystemWebviewPurpose)purpose
                           additionalHeaders:(NSDictionary<NSString *, NSString *> * _Nullable)headers;

/*!
 Creates an action to open a URL in an external browser.
 @param url The URL to open
 @return An action that will open the URL in the default external browser.
 */
+ (instancetype)openInExternalBrowserAction:(NSURL *)url;

/*!
 Creates an action to complete the webview flow with a URL.
 @param url The URL to complete with
 @return An action that will complete the webview authentication flow.
 */
+ (instancetype)completeWebAuthWithURLAction:(NSURL *)url;

/*!
 Creates an action to fail the webview flow with an error.
 @param error The error to fail with
 @return An action that will fail the webview authentication flow.
 */
+ (instancetype)failWebAuthWithErrorAction:(NSError *)error;


@end

NS_ASSUME_NONNULL_END
