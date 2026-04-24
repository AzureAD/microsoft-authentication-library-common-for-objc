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

#import "MSIDWebviewInteracting.h"
#import "MSIDWebviewNavigationAction.h"
@class MSIDAADOAuthEmbeddedWebviewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for handling special redirect schemes in webview navigation.
 * Allows controllers to intercept and process msauth:// and browser:// redirects.
 */
@protocol MSIDWebviewNavigationDelegate <NSObject>

@optional

/**
 * Called when webview encounters a special redirect scheme (msauth://, browser://)
 *
 * @param url The redirect URL (e.g., msauth://enroll?url=...)
 * @param completion Completion block - MUST be called exactly once
 */
- (void)handleSpecialRedirectUrl:(NSURL * _Nonnull)url
                      completion:(void (^_Nonnull)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion;


- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *_Nullable)headers;

@end

NS_ASSUME_NONNULL_END
