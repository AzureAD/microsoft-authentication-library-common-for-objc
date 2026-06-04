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

#if TARGET_OS_IPHONE
#import <WebKit/WebKit.h>
#endif

@class MSIDAuthority;
@class MSIDAccountMetadataCacheAccessor;
@class MSIDOauth2Factory;
@protocol MSIDCacheAccessor;

NS_ASSUME_NONNULL_BEGIN

/**
 * Immutable snapshot of state captured when a special redirect URL (e.g.
 * msauth://enroll) is intercepted during an interactive sign-in flow.
 *
 * CommonCore builds this DTO inside @c MSIDLocalInteractiveController and
 * passes it to the @c brtAcquisitionBlock so that the higher-level SDK
 * (e.g. OneAuth) can spin up a silent BRT acquisition without reaching back
 * into the controller.
 */
@interface MSIDExternalRedirectContext : NSObject

/// The special redirect URL that triggered this context (e.g. msauth://enroll?url=…)
@property (nonatomic, readonly) NSURL *redirectURL;

#if TARGET_OS_IPHONE
/// The WKWebView that hosted the parent interactive sign-in.
/// Consumers share its websiteDataStore (and optionally processPool) to
/// reuse the authenticated session cookie.
/// Strong reference — the consumer must extract configuration synchronously
/// and release the context promptly after starting its async work.
@property (nonatomic, readonly) WKWebView *parentWebView;
#endif

/// Authority of the parent sign-in request.
@property (nonatomic, readonly) MSIDAuthority *parentAuthority;

/// Correlation ID of the parent flow, carried through for telemetry.
@property (nonatomic, readonly, nullable) NSUUID *correlationId;

/// Login hint (UPN) from the parent request parameters.
@property (nonatomic, readonly, nullable) NSString *loginHint;

/// Token cache accessor — used by the consumer to persist the acquired BRT.
@property (nonatomic, readonly) id<MSIDCacheAccessor> tokenCache;

/// Account metadata cache accessor.
@property (nonatomic, readonly) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

/// OAuth2 factory for creating token responses.
@property (nonatomic, readonly) MSIDOauth2Factory *oauthFactory;

/// Extra URL query parameters from the parent request (e.g. instance_aware).
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *parentExtraURLQueryParameters;

#if TARGET_OS_IPHONE
- (instancetype)initWithRedirectURL:(NSURL *)redirectURL
                      parentWebView:(WKWebView *)parentWebView
                    parentAuthority:(MSIDAuthority *)parentAuthority
                      correlationId:(nullable NSUUID *)correlationId
                          loginHint:(nullable NSString *)loginHint
                         tokenCache:(id<MSIDCacheAccessor>)tokenCache
               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       oauthFactory:(MSIDOauth2Factory *)oauthFactory
       parentExtraURLQueryParameters:(nullable NSDictionary<NSString *, NSString *> *)parentExtraURLQueryParameters
    NS_DESIGNATED_INITIALIZER;
#endif

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
