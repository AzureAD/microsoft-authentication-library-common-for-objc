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

#if !MSID_EXCLUDE_WEBKIT

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class MSIDAuthority;
@protocol MSIDCacheAccessor;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * POC: BRT (Broker Refresh Token) acquisition helper.
 *
 * Clones the existing WebView (inheriting session cookies), fires a silent
 * /authorize request using the Broker's client ID with prompt=none, and stores
 * the resulting refresh token (BRT) in the shared keychain.
 *
 * NOTE: For production, this logic moves to OneAuth layer. In the POC it lives
 * in CommonCore for validation convenience.
 */
@interface MSIDBRTAcquisitionHelper : NSObject

/**
 * Synchronous BRT acquisition. Blocks caller until BRT flow completes.
 *
 * @param webview   The original WKWebView with active session cookies (used for config cloning).
 * @param authority The authority used in the original sign-in request.
 * @param cache     Cache accessor to store the BRT (shared keychain).
 * @param context   Request context for logging/correlation.
 * @param completion Called when BRT acquisition finishes. didSucceed=YES if BRT was stored.
 */
+ (void)acquireBRTWithWebView:(WKWebView *)webview
                    authority:(MSIDAuthority *)authority
                        cache:(id<MSIDCacheAccessor>)cache
                      context:(nullable id<MSIDRequestContext>)context
                   completion:(nullable void (^)(BOOL didSucceed, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

#endif
