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

#import "MSIDSystemWebviewController.h"
#import "MSIDSFAuthenticationSession.h"
#import "MSIDSafariViewController.h"
#import "MSIDWebviewAuthorization.h"

@implementation MSIDSystemWebviewController
{
    id<MSIDRequestContext> _context;
    MSIDWebUICompletionHandler _completionHandler;

    MSIDSFAuthenticationSession *_authSession;

    MSIDSafariViewController *_safariViewController;

}

@synthesize parentViewController;

- (instancetype)initWithStartURL:(NSURL *)startURL
               callbackURLScheme:(NSString *)callbackURLScheme
                         context:(id<MSIDRequestContext>)context
               completionHandler:(MSIDWebUICompletionHandler)completionHandler;
{
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _context = context;
        _callbackURLScheme = callbackURLScheme;
        _completionHandler = completionHandler;
    }
    
    return self;
}

- (BOOL)start
{
    if (!_startURL)
    {
        MSID_LOG_ERROR(_context, @"Attemped to start with nil URL");
        return NO;
    }
    
    if (@available(iOS 11.0, *))
    {
        _authSession = [[MSIDSFAuthenticationSession alloc] initWithURL:_startURL
                                                      callbackURLScheme:_callbackURLScheme
                                                                context:_context];
        _authSession.webviewDelegate = self;
        if (!_authSession)
        {
            MSID_LOG_ERROR(_context, @"Failed to create an auth session");
            return NO;
        }
        
        return [_authSession start];
    }

    _safariViewController = [[MSIDSafariViewController alloc] initWithURL:_startURL
                                                                  context:_context];
    if (!_safariViewController)
    {
        MSID_LOG_ERROR(_context, @"Failed to create an auth session");
        return NO;
    }
    
    return [_safariViewController start];
}

- (void)cancel
{
    if (@available(iOS 11.0, *))
        [_authSession cancel];
    else
        [_safariViewController cancel];
}

- (BOOL)handleURLResponseForSafariViewController:(NSURL *)url
{
    if (!url)
    {
        MSID_LOG_ERROR(_context, @"nil passed into the MSID Web handle response.");
        return NO;
    }
    
    if (@available(iOS 11.0, *)) { return NO; }
    
    if (!_safariViewController)
    {
        MSID_LOG_ERROR(_context, @"Received MSID web response without a current session running.");
        return NO;
    }
    return [_safariViewController handleURLResponse:url];
}

- (void)handleAuthResponse:(NSURL *)url
                     error:(NSError *)error
{
    NSError *authError = nil;
    MSIDWebOAuth2Response *response = [MSIDWebviewAuthorization responseWithURL:url
                                                                   requestState:self.requestState
                                                                  stateVerifier:self.stateVerifier
                                                                        context:_context
                                                                          error:&authError];
    
    _completionHandler(response, error);
}
@end
