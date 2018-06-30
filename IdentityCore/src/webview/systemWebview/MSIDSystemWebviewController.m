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
#import "MSIDSFAuthenticationSession.h"
#import "MSIDSafariViewController.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDOauth2Factory.h"
#import "MSIDNetworkConfiguration.h"
#import "MSIDNotifications.h"

@implementation MSIDSystemWebviewController
{
    id<MSIDRequestContext> _context;
    NSObject<MSIDWebviewInteracting> *_session;
    
    UIViewController *_parentController;
}

- (instancetype)initWithStartURL:(NSURL *)startURL
               callbackURLScheme:(NSString *)callbackURLScheme
                parentController:(UIViewController *)parentController
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
    }
    return self;
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (@available(iOS 11.0, *))
    {
        _session = [[MSIDSFAuthenticationSession alloc] initWithURL:self.startURL
                                                  callbackURLScheme:self.callbackURLScheme
                                                            context:_context];

    }
    else
    {
        _session = [[MSIDSafariViewController alloc] initWithURL:_startURL
                                                parentController:_parentController
                                                         context:_context];
    }
    
    if (_session)
    {
        [MSIDNotifications notifyWebAuthDidStartLoad:_startURL];
        [_session startWithCompletionHandler:completionHandler];
        return;
    }
    
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Failed to create an auth session", nil, nil, nil, _context.correlationId, nil);
    
    [MSIDNotifications notifyWebAuthDidFailWithError:error];
    completionHandler(nil, error);
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
