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
#import "MSIDBaseBrokerOperationRequest.h"
#import "MSIDBrowserRequestValidating.h"

NS_ASSUME_NONNULL_BEGIN

@class MSIDAADAuthority;
@class MSIDExternalSSOContext;

@interface MSIDBrokerOperationBrowserTokenRequest : MSIDBaseBrokerOperationRequest

@property (nonatomic, readonly) NSURL *requestURL;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) MSIDAADAuthority *authority;
@property (nonatomic, readonly) NSDictionary *headers;
@property (nonatomic, readonly) NSData *httpBody;
@property (nonatomic, readonly) BOOL useSSOCookieFallback;
@property (nonatomic, readonly) MSIDExternalSSOContext *ssoContext;

- (instancetype)initWithRequest:(NSURL *)requestURL
                        headers:(NSDictionary *)headers
                           body:(nullable NSData *)httpBody
               bundleIdentifier:(NSString *)bundleIdentifier
               requestValidator:(id<MSIDBrowserRequestValidating>)requestValidator
           useSSOCookieFallback:(BOOL)useSSOCookieFallback
                     ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                          error:(NSError *__autoreleasing*)error;

@end

NS_ASSUME_NONNULL_END
