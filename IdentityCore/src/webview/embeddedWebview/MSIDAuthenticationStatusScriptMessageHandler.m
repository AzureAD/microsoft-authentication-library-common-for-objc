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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDAuthenticationStatusScriptMessageHandler.h"
#import "MSIDAuthenticationAvailabilityStatus.h"
#import <objc/runtime.h>

static NSString * const MSIDAuthenticationStatusHandlerName = @"msidAuthenticationStatus";
static NSString * const MSIDAuthenticationStatusJavaScript =
    @"window.identity = window.identity || {};"
     "window.identity.getAuthenticationStatus = function() {"
     "return window.webkit.messageHandlers.msidAuthenticationStatus.postMessage({});"
     "};";
static void *MSIDAuthenticationStatusHandlerAssociationKey =
    &MSIDAuthenticationStatusHandlerAssociationKey;

@interface MSIDAuthenticationStatusScriptMessageHandler ()

@property (nonatomic, copy) MSIDAuthenticationAvailabilityStatus *(^statusProvider)(void);

- (instancetype)initWithStatusProvider:
    (MSIDAuthenticationAvailabilityStatus *(^)(void))statusProvider;

- (void)handleRequestFromURL:(NSURL *)requestURL
                 isMainFrame:(BOOL)isMainFrame
                replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler;

@end

@implementation MSIDAuthenticationStatusScriptMessageHandler

+ (void)installInUserContentController:(WKUserContentController *)userContentController
{
    if (!userContentController)
    {
        return;
    }

    id installedHandler = objc_getAssociatedObject(
        userContentController,
        MSIDAuthenticationStatusHandlerAssociationKey);
    if (installedHandler)
    {
        return;
    }

    MSIDAuthenticationStatusScriptMessageHandler *handler =
        [[MSIDAuthenticationStatusScriptMessageHandler alloc]
            initWithStatusProvider:^MSIDAuthenticationAvailabilityStatus *
            {
                return [MSIDAuthenticationAvailabilityStatus currentStatus];
            }];
    WKUserScript *script = [[WKUserScript alloc]
        initWithSource:MSIDAuthenticationStatusJavaScript
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];

    [userContentController addUserScript:script];
    [userContentController addScriptMessageHandlerWithReply:handler
                                               contentWorld:WKContentWorld.pageWorld
                                                       name:MSIDAuthenticationStatusHandlerName];
    objc_setAssociatedObject(
        userContentController,
        MSIDAuthenticationStatusHandlerAssociationKey,
        handler,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (instancetype)initWithStatusProvider:
    (MSIDAuthenticationAvailabilityStatus *(^)(void))statusProvider
{
    self = [super init];
    if (self)
    {
        _statusProvider = [statusProvider copy];
    }

    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
                 replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler
{
    (void)userContentController;
    NSURL *requestURL = message.frameInfo.request.URL;
    [self handleRequestFromURL:requestURL
                   isMainFrame:message.frameInfo.mainFrame
                  replyHandler:replyHandler];
}

- (void)handleRequestFromURL:(NSURL *)requestURL
                 isMainFrame:(BOOL)isMainFrame
                replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler
{
    if (!replyHandler)
    {
        return;
    }

    if (!isMainFrame)
    {
        replyHandler(nil, @"Authentication status is available only to the main frame.");
        return;
    }

    BOOL secureOrigin = [requestURL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame;
    if (!secureOrigin || requestURL.host.length == 0)
    {
        replyHandler(nil, @"Authentication status requires a secure web origin.");
        return;
    }

    MSIDAuthenticationAvailabilityStatus *status = self.statusProvider();
    replyHandler(status.statusDictionary, nil);
}

@end

#endif
