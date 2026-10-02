//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import "MSIDWebCPScriptMessageHandler.h"
#import "MSIDWebCPOnboardingReadinessContract.h"
#import "MSIDOnboardingReadinessProvider.h"
#import "MSIDWebviewConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import <objc/runtime.h>

NSString * const MSIDWebCPScriptMessageHandlerName = @"msidWebCP";
static char MSIDWebCPHandlerKey;

@interface MSIDWebCPScriptMessageHandler ()

@property (nonatomic, weak) WKUserContentController *contentController;
@property (nonatomic) NSHashTable<WKWebView *> *webViews;
@property (nonatomic) MSIDOnboardingReadinessProvider *readinessProvider;

@end

@implementation MSIDWebCPScriptMessageHandler

+ (instancetype)attachToWebView:(WKWebView *)webView
               readinessProvider:(MSIDOnboardingReadinessProvider *)provider
{
    NSAssert([NSThread isMainThread], @"WebKit handler registration must run on the main thread.");
    WKUserContentController *contentController = webView.configuration.userContentController;
    if (!contentController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"WebCP WebView has no user content controller.");
        return nil;
    }

    MSIDWebCPScriptMessageHandler *handler =
        objc_getAssociatedObject(contentController, &MSIDWebCPHandlerKey);
    if (!handler)
    {
        handler = [MSIDWebCPScriptMessageHandler new];
        handler.contentController = contentController;
        handler.webViews = [NSHashTable weakObjectsHashTable];
        handler.readinessProvider = provider ?: [MSIDOnboardingReadinessProvider new];
        @try
        {
            [contentController addScriptMessageHandlerWithReply:handler
                                                   contentWorld:WKContentWorld.pageWorld
                                                           name:MSIDWebCPScriptMessageHandlerName];
        }
        @catch (NSException *exception)
        {
            if (![exception.name isEqualToString:NSInvalidArgumentException])
            {
                @throw;
            }
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"WebCP script handler name is already in use.");
            return nil;
        }
        objc_setAssociatedObject(contentController, &MSIDWebCPHandlerKey,
                                 handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [handler.webViews addObject:webView];
    return handler;
}

- (void)detachFromWebView:(WKWebView *)webView
{
    NSAssert([NSThread isMainThread], @"WebKit handler removal must run on the main thread.");
    WKUserContentController *contentController = self.contentController;
    if (!contentController
        || objc_getAssociatedObject(contentController, &MSIDWebCPHandlerKey) != self)
    {
        return;
    }
    [self.webViews removeObject:webView];
    if (self.webViews.count == 0)
    {
        [contentController removeScriptMessageHandlerForName:MSIDWebCPScriptMessageHandlerName
                                                contentWorld:WKContentWorld.pageWorld];
        objc_setAssociatedObject(contentController, &MSIDWebCPHandlerKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
                 replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler
{
    [self handleBody:message.body
          sourceURL:message.frameInfo.request.URL
      fromMainFrame:message.frameInfo.isMainFrame
           webView:message.webView
 contentController:userContentController
       messageName:message.name
      replyHandler:replyHandler];
}

- (void)handleBody:(id)body
         sourceURL:(NSURL *)sourceURL
     fromMainFrame:(BOOL)fromMainFrame
          webView:(WKWebView *)webView
contentController:(WKUserContentController *)contentController
      messageName:(NSString *)messageName
     replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler
{
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    NSString *host = sourceURL.host.lowercaseString;
    if (bundlePath.length == 0 || [bundlePath.pathExtension.lowercaseString isEqualToString:@"appex"]
        || contentController != self.contentController
        || ![self.webViews containsObject:webView]
        || ![messageName isEqualToString:MSIDWebCPScriptMessageHandlerName]
        || !fromMainFrame
        || ![sourceURL.scheme.lowercaseString isEqualToString:@"https"]
        || (sourceURL.port && sourceURL.port.integerValue != 443)
        || ![MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains containsObject:host]
        || ![sourceURL.path hasPrefix:@"/enrollment/webenrollment/"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Rejected WebCP message from an unauthorized context.");
        replyHandler(nil, @"WebCP bridge is not available in this context.");
        return;
    }

    NSString *correlationID = [MSIDWebCPOnboardingReadinessContract correlationIDForRequest:body generated:NULL];
    MSIDWebCPOnboardingReadinessRequestValidation validation =
        [MSIDWebCPOnboardingReadinessContract validateRequest:body];
    if (validation != MSIDWebCPOnboardingReadinessRequestValidationValid)
    {
        MSIDWebCPOnboardingReadinessResponseStatus status =
            validation == MSIDWebCPOnboardingReadinessRequestValidationNotSupported
            ? MSIDWebCPOnboardingReadinessResponseStatusNotSupported
            : MSIDWebCPOnboardingReadinessResponseStatusFailed;
        replyHandler([MSIDWebCPOnboardingReadinessContract responseWithStatus:status
                                                                correlationID:correlationID
                                                                    readiness:nil], nil);
        return;
    }

    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_DISABLE_WEBCP_ONBOARDING_READINESS])
    {
        replyHandler([MSIDWebCPOnboardingReadinessContract
                      responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusNotSupported
                      correlationID:correlationID
                      readiness:nil], nil);
        return;
    }

    MSIDOnboardingReadiness *readiness = [self.readinessProvider readiness];
    MSIDWebCPOnboardingReadinessResponseStatus status = readiness
        ? MSIDWebCPOnboardingReadinessResponseStatusSuccess : MSIDWebCPOnboardingReadinessResponseStatusFailed;
    replyHandler([MSIDWebCPOnboardingReadinessContract responseWithStatus:status
                                                            correlationID:correlationID
                                                                readiness:readiness], nil);
}

@end
