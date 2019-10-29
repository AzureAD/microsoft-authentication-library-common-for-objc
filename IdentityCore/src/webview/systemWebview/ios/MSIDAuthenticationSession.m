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

#import "MSIDAuthenticationSession.h"

#import "MSIDWebviewAuthorization.h"
#import "MSIDWebOAuth2Response.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDNotifications.h"
#import "MSIDBackgroundTaskManager.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDAuthSessionHandlerFactory.h"

@interface MSIDAuthenticationSession (ASWebAuth)

@property (nonatomic) id<MSIDAuthSessionHandling> authSession;

@end

@implementation MSIDAuthenticationSession
{
    NSURL *_startURL;
    NSString *_callbackURLScheme;

    id<MSIDRequestContext> _context;
    
    MSIDWebUICompletionHandler _completionHandler;
    
    NSString *_telemetryRequestId;
    MSIDTelemetryUIEvent *_telemetryEvent;
}

- (instancetype)initWithURL:(NSURL *)url
          callbackURLScheme:(NSString *)callbackURLScheme
                    context:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _startURL = url;
        _context = context;
        _callbackURLScheme = callbackURLScheme;
    }
    
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
          callbackURLScheme:(NSString *)callbackURLScheme
           parentController:(UIViewController *)parentController
 ephemeralWebBrowserSession:(BOOL)prefersEphemeralWebBrowserSession
                    context:(id<MSIDRequestContext>)context
{
    self = [self initWithURL:url callbackURLScheme:callbackURLScheme context:context];
    if (self)
    {
        _parentController = parentController;
        _prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession;
    }
    
    return self;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,_context, @"CompletionHandler cannot be nil for interactive session.");
        return;
    }
    
    self.authSession = [MSIDAuthSessionHandlerFactory authSessionWithParentController:self.parentController];
    
    if (!self.authSession)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"SFAuthenticationSession/ASWebAuthenticationSession is not available on this platform or OS version.", nil, nil, nil, _context.correlationId, nil, YES);
        [self notifyEndWebAuthWithURL:nil error:error];
        completionHandler(nil, error);
        return;
    }
    
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
    
    _telemetryRequestId = [_context telemetryRequestId];
    [[MSIDTelemetry sharedInstance] startEvent:_telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
    _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                         context:_context];
    
    _completionHandler = [completionHandler copy];
    
    void (^authCompletion)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *authError)
    {
        [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
        
        [self notifyEndWebAuthWithURL:callbackURL error:authError];
        _completionHandler(callbackURL, authError);
    };

    [MSIDNotifications notifyWebAuthDidStartLoad:_startURL userInfo:nil];
    
    [self.authSession startSessionWithWithURL:_startURL
                            callbackURLScheme:_callbackURLScheme
                   ephemeralWebBrowserSession:self.prefersEphemeralWebBrowserSession
                            completionHandler:authCompletion];
}

- (void)cancel
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, _context, @"Authorization session was cancelled programatically");
    [_telemetryEvent setIsCancelled:YES];
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    [self.authSession cancel];
    
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorSessionCanceledProgrammatically,
                                     @"Authorization session was cancelled programatically.", nil, nil, nil, _context.correlationId, nil, YES);
    
    [self notifyEndWebAuthWithURL:nil error:error];
    _completionHandler(nil, error);
}

- (void)notifyEndWebAuthWithURL:(NSURL *)url
                          error:(NSError *)error
{
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
    
    if (error)
    {
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
    }
    else
    {
        [MSIDNotifications notifyWebAuthDidCompleteWithURL:url];
    }
}

- (BOOL)handleURLResponse:(NSURL *)url
{
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    [self.authSession cancel];
    
    [self notifyEndWebAuthWithURL:url error:nil];
    _completionHandler(url, nil);
    return YES;
}

- (void)dealloc
{
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
}

@end
#endif
