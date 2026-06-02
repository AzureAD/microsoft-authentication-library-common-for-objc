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

@class WKWebView;
@class MSIDAuthority;
@class MSIDAccountMetadataCacheAccessor;
@class MSIDOauth2Factory;
@protocol MSIDCacheAccessor;

NS_ASSUME_NONNULL_BEGIN

/**
 Passive, read-only snapshot handed to a host's @c externalRedirectURLAction
 block when the parent embedded WKWebView is about to follow a redirect that
 signals "user needs external action" (e.g. @c browser:// or @c msauth://).

 IdentityCore is a passive notifier: it observes the redirect, packages the
 artifacts the host needs to mount its own secondary flow against the parent
 webview's authenticated WKWebView session, and hands them over. IdentityCore
 does not execute any silent token request itself — that responsibility lives
 entirely with the host (e.g. OneAuth).

 Hosts must treat the contained references as @b read-only:
   - @c parentWebView's configuration (processPool / websiteDataStore) is
     shared so a hidden WKWebView can reuse the session cookies.
   - @c tokenCache / @c accountMetadataCache may be used to persist results
     under a host-owned client id distinct from the parent's.

 Instances are created and owned by IdentityCore. Hosts may capture this
 object for the duration of their asynchronous secondary flow.
 */
@interface MSIDExternalRedirectContext : NSObject

#pragma mark - Redirect metadata

/// The redirect URL the parent webview was about to follow (e.g. @c browser://...).
@property (nonatomic, readonly) NSURL *redirectURL;

/// Correlation id of the parent interactive request (for log stitching).
@property (nonatomic, readonly) NSUUID *correlationId;

/// Login hint configured on the parent interactive request, if any.
@property (nonatomic, readonly, nullable) NSString *loginHint;

/// Authority the parent request is targeting.
@property (nonatomic, readonly) MSIDAuthority *parentAuthority;

/// Extra @c /authorize query parameters configured on the parent request.
/// Hosts may forward selected entries (e.g. @c slice, @c dc) onto their own
/// secondary @c /authorize call to land on the same ESTS slice.
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *parentExtraURLQueryParameters;

#pragma mark - Raw artifacts

/// The parent webview. Hosts MUST share its
/// @c configuration.processPool and @c configuration.websiteDataStore on any
/// hidden WKWebView they spin up so the session cookies are reused.
@property (nonatomic, readonly) WKWebView *parentWebView;

/// Shared SSO token cache (typically writes to @c com.microsoft.adalcache).
@property (nonatomic, readonly) id<MSIDCacheAccessor> tokenCache;

/// Account metadata cache (may be @c nil for ADAL-style legacy paths).
@property (nonatomic, readonly, nullable) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

/// OAuth2 factory used to build the parent request; hosts can reuse it to
/// build their own grant / response-serializer with consistent semantics.
@property (nonatomic, readonly) MSIDOauth2Factory *oauthFactory;

#pragma mark - Designated initializer

- (instancetype)initWithRedirectURL:(NSURL *)redirectURL
                      correlationId:(NSUUID *)correlationId
                          loginHint:(nullable NSString *)loginHint
                    parentAuthority:(MSIDAuthority *)parentAuthority
      parentExtraURLQueryParameters:(nullable NSDictionary<NSString *, NSString *> *)parentExtraURLQueryParameters
                      parentWebView:(WKWebView *)parentWebView
                         tokenCache:(id<MSIDCacheAccessor>)tokenCache
               accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       oauthFactory:(MSIDOauth2Factory *)oauthFactory NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
