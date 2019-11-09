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
#if !MSID_EXCLUDE_SYSTEMWV

#import "MSIDSystemWebviewController.h"
#import "MSIDSafariViewController.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDOauth2Factory.h"
#import "MSIDNotifications.h"
#import "MSIDURLResponseHandling.h"
#import "MSIDSystemWebViewControllerFactory.h"
#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDSystemWebviewController ()

@property (nonatomic, copy) MSIDWebUICompletionHandler completionHandler;
@property (nonatomic) NSString *telemetryRequestId;
@property (nonatomic) MSIDTelemetryUIEvent *telemetryEvent;
@property (nonatomic) id<MSIDWebviewInteracting> session;
@property (nonatomic) id<MSIDRequestContext> context;

@property (nonatomic) BOOL useAuthenticationSession;
@property (nonatomic) BOOL allowSafariViewController;
@property (nonatomic) BOOL prefersEphemeralWebBrowserSession;

@end

@implementation MSIDSystemWebviewController

- (instancetype)initWithStartURL:(NSURL *)startURL
                     redirectURI:(NSString *)redirectURI
                parentController:(MSIDViewController *)parentController
        useAuthenticationSession:(BOOL)useAuthenticationSession
       allowSafariViewController:(BOOL)allowSafariViewController
      ephemeralWebBrowserSession:(BOOL)prefersEphemeralWebBrowserSession
                         context:(id<MSIDRequestContext>)context
{
    if (!startURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Attemped to start with nil URL");
        return nil;
    }
    
    NSURL *redirectURL = [NSURL URLWithString:redirectURI];
    if (!redirectURL || !redirectURL.scheme)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Attemped to start with invalid redirect uri");
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _context = context;
        _redirectURL = redirectURL;
        _parentController = parentController;
        _allowSafariViewController = allowSafariViewController;
        _useAuthenticationSession = useAuthenticationSession;
        _prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession;
    }
    return self;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,self.context, @"CompletionHandler cannot be nil for interactive session.");
        return;
    }
    
    self.completionHandler = completionHandler;
    
    NSError *error = nil;
    
    self.session = [self sessionWithAuthSessionAllowed:self.useAuthenticationSession safariAllowed:self.allowSafariViewController];
    
    if (!self.session)
    {
        if (!error)
        {
            error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Didn't find supported system webview on a particular platform and OS version", nil, nil, nil, self.context.correlationId, nil, YES);
        }
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
        completionHandler(nil, error);
        return;
    }
    
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
    
    self.telemetryRequestId = [self.context telemetryRequestId];
    [[MSIDTelemetry sharedInstance] startEvent:self.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
    self.telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                             context:self.context];
        
    void (^authCompletion)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *authError)
    {
        if (authError && authError.code == MSIDErrorUserCancel)
        {
            [self.telemetryEvent setIsCancelled:YES];
        }
        
        [[MSIDTelemetry sharedInstance] stopEvent:self.telemetryRequestId event:self.telemetryEvent];
        
        [self notifyEndWebAuthWithURL:callbackURL error:authError];
        self.completionHandler(callbackURL, authError);
    };

    [MSIDNotifications notifyWebAuthDidStartLoad:self.startURL userInfo:nil];
    
    [self.session startWithCompletionHandler:authCompletion];
}

- (void)cancel
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Authorization session was cancelled programatically");
    [self.telemetryEvent setIsCancelled:YES];
    [[MSIDTelemetry sharedInstance] stopEvent:self.telemetryRequestId event:self.telemetryEvent];
    
    [self.session cancel];
    
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorSessionCanceledProgrammatically,
                                     @"Authorization session was cancelled programatically.", nil, nil, nil, self.context.correlationId, nil, YES);
    
    [self notifyEndWebAuthWithURL:nil error:error];
    self.completionHandler(nil, error);
}

- (BOOL)handleURLResponse:(NSURL *)url
{
    if (!self.session)
    {
        return NO;
    }
    
    if ([self.redirectURL.scheme caseInsensitiveCompare:url.scheme] != NSOrderedSame
        || [self.redirectURL.host caseInsensitiveCompare:url.host] != NSOrderedSame)
    {
        return NO;
    }
    
    [[MSIDTelemetry sharedInstance] stopEvent:self.telemetryRequestId event:self.telemetryEvent];
    
    [self.session dismiss];
    
    [self notifyEndWebAuthWithURL:url error:nil];
    if (self.completionHandler)self.completionHandler(url, nil);
    return YES;
}

- (void)dismiss
{
    [self.session dismiss];
}

#pragma mark - Helpers

- (id<MSIDWebviewInteracting>)sessionWithAuthSessionAllowed:(BOOL)authSessionAllowed
                                              safariAllowed:(BOOL)safariAllowed
{
    if (authSessionAllowed)
    {
        return [MSIDSystemWebViewControllerFactory authSessionWithParentController:self.parentController
                                                                          startURL:self.startURL
                                                                    callbackScheme:self.redirectURL.scheme
                                                                useEmpheralSession:self.prefersEphemeralWebBrowserSession
                                                                           context:self.context];
    }
        
#if TARGET_OS_IPHONE
        
    if (safariAllowed)
    {
        MSIDSafariViewController *safariController = [[MSIDSafariViewController alloc] initWithURL:self.startURL
                                                                                  parentController:self.parentController
                                                                                  presentationType:self.presentationType
                                                                                           context:self.context];
        
        safariController.appActivities = self.appActivities;
        return safariController;
    }
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Couldn't create session on macOS. Safari allowed flag %d", safariAllowed);
#endif
    
    return nil;
}

- (void)notifyEndWebAuthWithURL:(NSURL *)url
                          error:(NSError *)error
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
    
    if (error)
    {
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
    }
    else
    {
        [MSIDNotifications notifyWebAuthDidCompleteWithURL:url];
    }
}

#pragma mark - Dealloc

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
}

@end
#endif
