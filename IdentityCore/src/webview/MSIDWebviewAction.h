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

typedef NS_ENUM(NSInteger, MSIDWebviewActionType) {
    MSIDWebviewActionTypeCancel = 0,
    MSIDWebviewActionTypeContinue = 1,
    MSIDWebviewActionTypeLoadRequest = 2,
    MSIDWebviewActionTypeComplete = 3
};

/**
 MSIDWebviewAction represents an action to be taken by the webview controller
 in response to a navigation event (e.g., msauth:// or browser:// URL).
 This allows the InteractiveController to decide asynchronously how to handle
 special URL schemes.
 */
@interface MSIDWebviewAction : NSObject

@property (nonatomic, readonly) MSIDWebviewActionType actionType;
@property (nonatomic, readonly, nullable) NSURLRequest *request;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;
@property (nonatomic, readonly, nullable) NSURL *completeURL;

+ (instancetype)cancelAction;
+ (instancetype)continueAction;
+ (instancetype)loadRequestAction:(NSURLRequest *)request;
+ (instancetype)loadRequestAction:(NSURLRequest *)request additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders;
+ (instancetype)completeAction:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
