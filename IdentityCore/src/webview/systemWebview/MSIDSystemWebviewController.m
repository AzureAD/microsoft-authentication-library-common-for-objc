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

@implementation MSIDSystemWebviewController
{
    id<MSIDRequestContext> _context;
    MSIDWebUICompletionHandler _completionHandler;

#if TARGET_OS_IPHONE
    MSIDSFAuthenticationSession *_authSession;
#else
    MSIDSafariViewController *_safariViewController;
#endif
    
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
    
#if TARGET_OS_IPHONE
    if (@available(iOS 11.0, *))
    {
        _authSession = [[MSIDSFAuthenticationSession alloc] initWithURL:_startURL
                                                      callbackURLScheme:_callbackURLScheme
                                                                context:_context];
        if (!_authSession)
        {
            MSID_LOG_ERROR(_context, @"Failed to create an auth session");
            return NO;
        }
        
        return [_authSession start];
    }
#else
    {
        _safariViewController = [[MSIDSafariViewController alloc] initWithURL:_startURL
                                                             context:_context];
        if (!_safariViewController)
        {
            MSID_LOG_ERROR(_context, @"Failed to create an auth session");
            return NO;
        }
        
        return [_safariViewController start];
    }
    #endif
    return NO;
}

- (void)cancel
{
#if TARGET_OS_IPHONE
    [_authSession cancel];
#else
    [_safariViewController cancel];
#endif
    
}

- (BOOL)handleURLResponseForSafariViewController:(NSURL *)url
{
    return NO;
}

- (void)handleAuthResponse:(NSURL *)url
                     error:(NSError *)error
{
    
}
@end
