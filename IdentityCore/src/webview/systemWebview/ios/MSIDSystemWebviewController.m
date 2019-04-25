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
#import "MSIDAuthenticationSession.h"
#import "MSIDSafariViewController.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDOauth2Factory.h"
#import "MSIDNotifications.h"

@implementation MSIDSystemWebviewController
{
    id<MSIDRequestContext> _context;
    NSObject<MSIDWebviewInteracting> *_session;
    
    BOOL _allowSafariViewController;
    BOOL _useAuthenticationSession;
}

- (instancetype)initWithStartURL:(NSURL *)startURL
               callbackURLScheme:(NSString *)callbackURLScheme
                parentController:(UIViewController *)parentController
                presentationType:(UIModalPresentationStyle)presentationType
        useAuthenticationSession:(BOOL)useAuthenticationSession
       allowSafariViewController:(BOOL)allowSafariViewController
                         context:(id<MSIDRequestContext>)context
{
    if (!startURL)
    {
        MSID_LOG_WARN(context, @"Attemped to start with nil URL");
        return nil;
    }
    
    if (!callbackURLScheme)
    {
        MSID_LOG_WARN(context, @"Attemped to start with invalid redirect uri");
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _context = context;
        _callbackURLScheme = callbackURLScheme;
        _parentController = parentController;
        _presentationType = presentationType;
        _allowSafariViewController = allowSafariViewController;
        _useAuthenticationSession = useAuthenticationSession;
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
    
    if (_useAuthenticationSession)
    {
        if (@available(iOS 11.0, *))
        {
            _session = [[MSIDAuthenticationSession alloc] initWithURL:self.startURL
                                                    callbackURLScheme:self.callbackURLScheme
                                                              context:_context];
        }
        else
        {
             error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"SFAuthenticationSession/ASWebAuthenticationSession is not available for iOS 10 and older.", nil, nil, nil, _context.correlationId, nil);
        }
    }
    
    if (!_session && _allowSafariViewController)
    {
        _session = [[MSIDSafariViewController alloc] initWithURL:_startURL
                                                parentController:_parentController
                                                presentationType:_presentationType
                                                         context:_context];
    }
    
    if (!_session)
    {
        if (!error)
        {
            error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Failed to create an auth session", nil, nil, nil, _context.correlationId, nil);
        }
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
        completionHandler(nil, error);
        return;
    }
    
    [MSIDNotifications notifyWebAuthDidStartLoad:_startURL];
    [_session startWithCompletionHandler:completionHandler];
}


- (void)cancel
{
    [_session cancel];
}

- (BOOL)handleURLResponseForSafariViewController:(NSURL *)url
{
    if ([_session isKindOfClass:MSIDSafariViewController.class])
    {
        return [((MSIDSafariViewController *)_session) handleURLResponse:url];
    }
    
    return NO;
}

@end
#endif
