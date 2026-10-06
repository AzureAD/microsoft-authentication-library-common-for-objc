//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class MSIDAuthenticationAvailabilityProvider;
@class MSIDWebCPOnboardingReadinessContract;

NS_ASSUME_NONNULL_BEGIN

/// Stable WebKit endpoint; the request action identifies the supported operation.
FOUNDATION_EXPORT NSString * const MSIDWebCPScriptMessageHandlerName;

@interface MSIDWebCPScriptMessageHandler : NSObject <WKScriptMessageHandlerWithReply>

+ (nullable instancetype)attachToWebView:(WKWebView *)webView
                       readinessProvider:(nullable MSIDAuthenticationAvailabilityProvider *)provider
                       readinessContract:(MSIDWebCPOnboardingReadinessContract *)contract;
- (void)detachFromWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
