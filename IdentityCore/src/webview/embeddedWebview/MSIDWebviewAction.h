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

/*!
 Defines the type of action the embedded webview controller should execute.
 These actions are returned by the state machine after processing special URLs.
 */
typedef NS_ENUM(NSInteger, MSIDWebviewActionType)
{
    /*! No operation - continue normal webview flow */
    MSIDWebviewActionTypeNoop = 0,
    
    /*! Load the specified request in the embedded webview */
    MSIDWebviewActionTypeLoadRequestInWebview,
    
    /*! Open the URL in ASWebAuthenticationSession */
    MSIDWebviewActionTypeOpenASWebAuthenticationSession,
    
    /*! Open the URL in an external browser */
    MSIDWebviewActionTypeOpenExternalBrowser,
    
    /*! Complete the webview flow with the given URL */
    MSIDWebviewActionTypeCompleteWithURL,
    
    /*! Fail the webview flow with the given error */
    MSIDWebviewActionTypeFailWithError
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
 
 This is part of a controller-action state machine architecture where:
 - Controller actions (async operations like AcquireBRTOnce) run in the background
 - View actions (MSIDWebviewAction) are returned to the webview controller for execution
 
 The state machine processes special URLs and determines the appropriate view action
 based on current state, policy decisions, and URL parameters.
 */
@interface MSIDWebviewAction : NSObject

/*! The type of action to execute */
@property (nonatomic, readonly) MSIDWebviewActionType type;

/*! The NSURLRequest to load (for LoadRequestInWebview type) */
@property (nonatomic, readonly, nullable) NSURLRequest *request;

/*! The URL to open or complete with (for OpenASWebAuthenticationSession, OpenExternalBrowser, CompleteWithURL types) */
@property (nonatomic, readonly, nullable) NSURL *url;

/*! The purpose for opening a system webview (for OpenASWebAuthenticationSession type) */
@property (nonatomic, readonly) MSIDSystemWebviewPurpose purpose;

/*! The error to fail with (for FailWithError type) */
@property (nonatomic, readonly, nullable) NSError *error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/*!
 Creates a no-op action.
 @return A noop action that indicates the webview should continue normal processing.
 */
+ (instancetype)noopAction;

/*!
 Creates an action to load a request in the embedded webview.
 @param request The request to load
 @return An action that will load the request in the webview.
 */
+ (instancetype)loadRequestAction:(NSURLRequest *)request;

/*!
 Creates an action to open a URL in ASWebAuthenticationSession.
 @param url The URL to open
 @param purpose The purpose for opening the session (determines ephemeral behavior)
 @return An action that will open the URL in ASWebAuthenticationSession with appropriate settings.
 */
+ (instancetype)openASWebAuthSessionAction:(NSURL *)url purpose:(MSIDSystemWebviewPurpose)purpose;

/*!
 Creates an action to open a URL in an external browser.
 @param url The URL to open
 @return An action that will open the URL in the default external browser.
 */
+ (instancetype)openExternalBrowserAction:(NSURL *)url;

/*!
 Creates an action to complete the webview flow with a URL.
 @param url The URL to complete with
 @return An action that will complete the webview authentication flow.
 */
+ (instancetype)completeWithURLAction:(NSURL *)url;

/*!
 Creates an action to fail the webview flow with an error.
 @param error The error to fail with
 @return An action that will fail the webview authentication flow.
 */
+ (instancetype)failWithErrorAction:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
