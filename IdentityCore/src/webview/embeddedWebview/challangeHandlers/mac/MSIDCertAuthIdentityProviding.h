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

#ifndef MSIDCertAuthIdentityProviding_h
#define MSIDCertAuthIdentityProviding_h

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <WebKit/WebKit.h>

@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 Narrow seam protocol covering the non-deterministic macOS certificate-based
 authentication operations that @c MSIDCertAuthHandler routes through
 @c MSIDDIContainer: the Keychain preferred-identity lookup / persistence, the
 date-range identity validation, and the interactive certificate picker.

 Tests install a fake class conforming to this protocol via
 @c -[MSIDDIContainer registerProtocol:lifetime:factory:] instead of swizzling,
 which lets them drive every branch of @c handleChallenge: without touching the
 Keychain or presenting UI.

 Production default conformer: @c MSIDCertAuthHandler. Resolve via
 @c +[MSIDCertAuthHandler resolvedIdentityProvider].
 */
@protocol MSIDCertAuthIdentityProviding <NSObject>

/**
 Returns the preferred Keychain identity stored for @c host (matching the
 supplied issuer @c distinguishedNames), or @c NULL when none exists.

 The returned identity is owned by the caller (+1 retain, matching
 @c SecIdentityCopyPreferred).
 */
+ (nullable SecIdentityRef)copyPreferredIdentityForHost:(nullable NSString *)host
                                     distinguishedNames:(nullable NSArray<NSData *> *)distinguishedNames CF_RETURNS_RETAINED;

/**
 Validates that @c identity is non-NULL and its certificate is currently within
 its validity date range.
 */
+ (BOOL)isIdentityValid:(nullable SecIdentityRef)identity
                context:(nullable id<MSIDRequestContext>)context;

/**
 Persists @c identity as the preferred Keychain identity for @c host using the
 supplied key-usage attributes. Returns the @c SecIdentitySetPreferred status.
 */
+ (OSStatus)setPreferredIdentity:(SecIdentityRef)identity
                         forHost:(NSString *)host
                     keyUsageRef:(nullable CFArrayRef)keyUsage;

/**
 Presents the interactive certificate picker for @c host. Invokes
 @c completionHandler with the user-selected identity, or @c NULL when no
 matching certificate is found or the user makes no selection. The identity
 passed to @c completionHandler is autoreleased (not pre-retained).
 */
+ (void)promptUserForIdentity:(nullable NSArray *)issuers
                         host:(nullable NSString *)host
                      webview:(nullable WKWebView *)webview
                correlationId:(nullable NSUUID *)correlationId
            completionHandler:(void (^)(SecIdentityRef _Nullable identity))completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* MSIDCertAuthIdentityProviding_h */
