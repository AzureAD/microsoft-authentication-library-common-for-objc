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
#import <SafariServices/SafariServices.h>

@implementation MSIDAuthenticationSession
{
    API_AVAILABLE(ios(11.0))
    SFAuthenticationSession *_authSession;
    
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
    }
    
    return self;
}


- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WARN(_context, @"CompletionHandler cannot be nil for interactive session.");
        return;
    }
    
    NSError *error = nil;
    
    if (@available(iOS 11.0, *))
    {
        _telemetryRequestId = [_context telemetryRequestId];
        [[MSIDTelemetry sharedInstance] startEvent:_telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
        _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                             context:_context];
        
        _completionHandler = [completionHandler copy];
        
        _authSession = [[SFAuthenticationSession alloc] initWithURL:_startURL
                                                  callbackURLScheme:_callbackURLScheme
                                                  completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
                                            {
                                                if (error)
                                                {
                                                    if (error.code == SFAuthenticationErrorCanceledLogin)
                                                    {
                                                        error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, _context.correlationId, nil);
                                                        [_telemetryEvent setIsCancelled:YES];
                                                    }
                                                }

                                                [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
                                                
                                                [self notifyEndWebAuthWithURL:callbackURL error:error];
                                                _completionHandler(callbackURL, error);
                                            }];
        
        [MSIDNotifications notifyWebAuthDidStartLoad:_startURL];
        
        if ([_authSession start]) return;
        
        error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Failed to start an interactive session", nil, nil, nil, _context.correlationId, nil);
    }
    else
    {
        error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"SFAuthenticationSession/ASWebAuthenticationSession is not available for iOS 10 and older.", nil, nil, nil, _context.correlationId, nil);
    }
    
    [self notifyEndWebAuthWithURL:nil error:error];
    completionHandler(nil, error);
}


- (void)cancel
{
    MSID_LOG_INFO(_context, @"Authorization session was cancelled programatically");
    [_telemetryEvent setIsCancelled:YES];
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    [_authSession cancel];
    
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorSessionCanceledProgrammatically,
                                     @"Authorization session was cancelled programatically.", nil, nil, nil, _context.correlationId, nil);
    
    [self notifyEndWebAuthWithURL:nil error:error];
    _completionHandler(nil, error);
}

- (void)notifyEndWebAuthWithURL:(NSURL *)url
                          error:(NSError *)error
{
    if (error)
    {
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
    }
    else
    {
        [MSIDNotifications notifyWebAuthDidCompleteWithURL:url];
    }
}

@end
#endif
