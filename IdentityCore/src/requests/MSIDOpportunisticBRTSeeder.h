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
#import <WebKit/WebKit.h>

@class MSIDInteractiveTokenRequestParameters;
@class MSIDOauth2Factory;
@class MSIDTokenResponseValidator;
@class MSIDAccountMetadataCacheAccessor;
@protocol MSIDCacheAccessor;
@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 POC: Opportunistically seeds a Broker Refresh Token (BRT) into the shared SSO
 keychain group by reusing the live embedded webview's session cookies.

 Triggered from the navigation callback when the parent interactive request is
 about to follow a browser:// (or msauth://) redirect that signals "user needs
 broker / install Authenticator / continue in external browser".

 Fire-and-forget. Idempotent per correlationId. Does not block parent navigation.
 */
@interface MSIDOpportunisticBRTSeeder : NSObject

+ (void)seedWithParentParameters:(MSIDInteractiveTokenRequestParameters *)parentParameters
                         webView:(WKWebView *)webView
                      tokenCache:(id<MSIDCacheAccessor>)tokenCache
            accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                    oauthFactory:(MSIDOauth2Factory *)oauthFactory
          tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                         context:(nullable id<MSIDRequestContext>)context;

@end

NS_ASSUME_NONNULL_END
