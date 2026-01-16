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

@class MSIDWebviewAction;
@class MSIDInteractiveWebviewState;

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDSpecialURLViewActionResolver maps special URLs (msauth:// and browser://)
 to MSIDWebviewAction instances.
 
 This resolver implements placeholder semantics for the following URL patterns:
 
 - msauth://enroll?cpurl=... → LoadRequestInWebview (construct request from cpurl)
 - msauth://compliance?cpurl=... → LoadRequestInWebview (construct request from cpurl)
 - msauth://installProfile?url=...&requireASWebAuthenticationSession=true → OpenASWebAuthenticationSession with purpose InstallProfile
 - msauth://profileComplete → CompleteWithURL
 - browser://... → CompleteWithURL
 
 TODO: Future enhancements needed:
 - Add extra headers and query parameters for enroll/compliance requests
 - Parse and include telemetry headers from URL parameters
 - Enforce ephemeral ASWebAuthenticationSession behavior by purpose in system webview handoff handler
 */
@interface MSIDSpecialURLViewActionResolver : NSObject

/*!
 Resolves a special URL to a webview action based on the URL pattern and state.
 
 @param url The special URL to resolve (msauth:// or browser://)
 @param state Current webview state (may influence resolution decisions)
 @return The resolved webview action, or nil if the URL pattern is not recognized.
 */
+ (MSIDWebviewAction * _Nullable)resolveActionForURL:(NSURL *)url
                                                state:(MSIDInteractiveWebviewState * _Nullable)state;

@end

NS_ASSUME_NONNULL_END
