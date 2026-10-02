//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class MSIDOnboardingReadinessProvider;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const MSIDWebCPOnboardingReadinessScriptMessageHandlerName;

@interface MSIDWebCPOnboardingReadinessScriptMessageHandler : NSObject <WKScriptMessageHandlerWithReply>

+ (nullable instancetype)attachToWebView:(WKWebView *)webView
                       readinessProvider:(nullable MSIDOnboardingReadinessProvider *)provider;
- (void)detachFromWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
