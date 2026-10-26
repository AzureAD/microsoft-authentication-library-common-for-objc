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

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebCPScriptMessageHandler.h"
#import "MSIDWebCPOnboardingReadinessContract.h"
#import "MSIDAuthenticationAvailabilityProvider.h"
#import "MSIDWebviewConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"

NSString * const MSIDWebCPScriptMessageHandlerName = @"msidWebCP";
static NSString * const MSIDWebCPJavaScriptAPI =
    @"(function() {"
    @"if (window.msidWebCP) { return; }"
    @"window.msidWebCP = { postMessage: function(message) {"
    @"return window.webkit.messageHandlers.msidWebCP.postMessage(message);"
    @"} };"
    @"})();";

@interface MSIDWebCPScriptMessageHandler ()

@property (nonatomic, weak) WKUserContentController *contentController;
@property (nonatomic) NSHashTable<WKWebView *> *webViews;
@property (nonatomic) MSIDAuthenticationAvailabilityProvider *availabilityProvider;
@property (nonatomic) MSIDWebCPOnboardingReadinessContract *readinessContract;

+ (NSMapTable<WKUserContentController *, MSIDWebCPScriptMessageHandler *> *)handlersByContentController;

- (BOOL)isAuthorizedMessageFromURL:(NSURL *)sourceURL
                     fromMainFrame:(BOOL)fromMainFrame
                          webView:(WKWebView *)webView
                 contentController:(WKUserContentController *)contentController
                      messageName:(NSString *)messageName;

@end

@implementation MSIDWebCPScriptMessageHandler

+ (NSMapTable<WKUserContentController *, MSIDWebCPScriptMessageHandler *> *)handlersByContentController
{
    static NSMapTable<WKUserContentController *, MSIDWebCPScriptMessageHandler *> *handlers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handlers = [NSMapTable weakToStrongObjectsMapTable];
    });
    return handlers;
}

+ (instancetype)attachToWebView:(WKWebView *)webView
               readinessProvider:(MSIDAuthenticationAvailabilityProvider *)provider
               readinessContract:(MSIDWebCPOnboardingReadinessContract *)contract
{
    NSAssert([NSThread isMainThread], @"WebKit handler registration must run on the main thread.");
    WKUserContentController *contentController = webView.configuration.userContentController;
    if (!contentController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"WebCP WebView has no user content controller.");
        return nil;
    }
    if (!contract)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"WebCP script handler requires a readiness contract.");
        return nil;
    }

    NSMapTable<WKUserContentController *, MSIDWebCPScriptMessageHandler *> *handlers =
        [self handlersByContentController];
    MSIDWebCPScriptMessageHandler *handler = [handlers objectForKey:contentController];
    if (!handler)
    {
        handler = [MSIDWebCPScriptMessageHandler new];
        handler.contentController = contentController;
        handler.webViews = [NSHashTable weakObjectsHashTable];
        handler.availabilityProvider = provider ?: [MSIDAuthenticationAvailabilityProvider new];
        handler.readinessContract = contract;
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
        [handlers setObject:handler forKey:contentController];
    }

    BOOL hasWebCPScript = NO;
    for (WKUserScript *script in contentController.userScripts)
    {
        if ([script.source isEqualToString:MSIDWebCPJavaScriptAPI])
        {
            hasWebCPScript = YES;
            break;
        }
    }
    if (!hasWebCPScript)
    {
        WKUserScript *script = [[WKUserScript alloc] initWithSource:MSIDWebCPJavaScriptAPI
                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                  forMainFrameOnly:YES];
        [contentController addUserScript:script];
    }

    [handler.webViews addObject:webView];
    return handler;
}

- (void)detachFromWebView:(WKWebView *)webView
{
    NSAssert([NSThread isMainThread], @"WebKit handler removal must run on the main thread.");
    WKUserContentController *contentController = self.contentController;
    NSMapTable<WKUserContentController *, MSIDWebCPScriptMessageHandler *> *handlers =
        [MSIDWebCPScriptMessageHandler handlersByContentController];
    if (!contentController || [handlers objectForKey:contentController] != self)
    {
        return;
    }
    [self.webViews removeObject:webView];
    if (self.webViews.count == 0)
    {
        [contentController removeScriptMessageHandlerForName:MSIDWebCPScriptMessageHandlerName
                                                contentWorld:WKContentWorld.pageWorld];
        [handlers removeObjectForKey:contentController];
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
    if (![self isAuthorizedMessageFromURL:sourceURL
                            fromMainFrame:fromMainFrame
                                 webView:webView
                        contentController:contentController
                             messageName:messageName])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Rejected WebCP message from an unauthorized context.");
        replyHandler(nil, @"WebCP bridge is not available in this context.");
        return;
    }

    NSString *correlationID = [self.readinessContract correlationIDForRequest:body generated:NULL];
    MSIDWebCPOnboardingReadinessRequestValidation validation =
        [self.readinessContract validateRequest:body];
    if (validation != MSIDWebCPOnboardingReadinessRequestValidationValid)
    {
        MSIDWebCPOnboardingReadinessResponseStatus status =
            validation == MSIDWebCPOnboardingReadinessRequestValidationNotSupported
            ? MSIDWebCPOnboardingReadinessResponseStatusNotSupported
            : MSIDWebCPOnboardingReadinessResponseStatusFailed;
        replyHandler([self.readinessContract responseWithStatus:status
                                                  correlationID:correlationID
                                                   availability:nil], nil);
        return;
    }

    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_DISABLE_WEBCP_ONBOARDING_READINESS])
    {
        replyHandler([self.readinessContract
                      responseWithStatus:MSIDWebCPOnboardingReadinessResponseStatusNotSupported
                           correlationID:correlationID
                            availability:nil], nil);
        return;
    }

    MSIDAuthenticationAvailabilityStatus *availability = [self.availabilityProvider availabilityStatus];
    MSIDWebCPOnboardingReadinessResponseStatus status = availability
        ? MSIDWebCPOnboardingReadinessResponseStatusSuccess : MSIDWebCPOnboardingReadinessResponseStatusFailed;
    replyHandler([self.readinessContract responseWithStatus:status
                                              correlationID:correlationID
                                               availability:availability], nil);
}

- (BOOL)isAuthorizedMessageFromURL:(NSURL *)sourceURL
                     fromMainFrame:(BOOL)fromMainFrame
                          webView:(WKWebView *)webView
                 contentController:(WKUserContentController *)contentController
                      messageName:(NSString *)messageName
{
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    if (bundlePath.length == 0 || [bundlePath.pathExtension.lowercaseString isEqualToString:@"appex"])
    {
        return NO;
    }

    if (contentController != self.contentController
        || ![self.webViews containsObject:webView]
        || ![messageName isEqualToString:MSIDWebCPScriptMessageHandlerName]
        || !fromMainFrame)
    {
        return NO;
    }

    if (![sourceURL.scheme.lowercaseString isEqualToString:@"https"]
        || (sourceURL.port && sourceURL.port.integerValue != 443))
    {
        return NO;
    }

    NSString *host = sourceURL.host.lowercaseString;
    return [MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains containsObject:host]
        && [sourceURL.path hasPrefix:@"/enrollment/webenrollment/"];
}

@end

#endif // !MSID_EXCLUDE_WEBKIT
