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
#import "MSIDWebviewConfiguration.h"
#import "MSIDOauth2Factory.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDWebviewSession.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDAADV2Oauth2Factory.h"

@class WKWebView;
@protocol MSIDWebviewInteracting;

typedef void (^MSIDWebviewAuthCompletionHandler)(MSIDWebviewResponse *response, NSError *error);

@interface MSIDWebviewAuthorization : NSObject

+ (void)startEmbeddedWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                    oauth2Factory:(MSIDOauth2Factory *)oauth2Factory
                                          context:(id<MSIDRequestContext>)context
                                completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler;

+ (void)startEmbeddedWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                    oauth2Factory:(MSIDOauth2Factory *)oauth2Factory
                                          webview:(WKWebView *)webview
                                          context:(id<MSIDRequestContext>)context
                                completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler;

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV
+ (void)startSystemWebviewWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                         oauth2Factory:(MSIDOauth2Factory *)oauth2Factory
                                               context:(id<MSIDRequestContext>)context
                                     completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler;
#endif


+ (BOOL)setCurrentSession:(MSIDWebviewSession *)session;
+ (void)cancelCurrentSession;

#if TARGET_OS_IPHONE && !MSID_EXCLUDE_SYSTEMWV
// This is for system webview auth session on iOS 10 - Thus, a SafariViewController
+ (BOOL)handleURLResponseForSystemWebviewController:(NSURL *)url;
#endif

// This can be utilized for having a custom webview controller, and for testing.
+ (void)startSession:(MSIDWebviewSession *)session
             context:(id<MSIDRequestContext>)context
   completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler;

@property (class, readonly) MSIDWebviewSession *currentSession;

@end



