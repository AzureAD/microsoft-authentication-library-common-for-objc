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

#import "MSIDSafariViewController.h"
#import "MSIDSystemWebviewController.h"
#import <SafariServices/SafariServices.h>
#import "MSIDWebOAuth2Response.h"

@interface MSIDSafariViewController() <SFSafariViewControllerDelegate>

@end

@implementation MSIDSafariViewController
{
    SFSafariViewController *_safariViewController;
    
    NSURL *_url;
    MSIDWebUICompletionHandler _completionHandler;
    
    id<MSIDRequestContext> _context;
}

- (id)initWithURL:(NSURL *)url
          context:(id<MSIDRequestContext>)context
completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    self = [super init];
    if (self)
    {
        _url = url;
        _completionHandler = completionHandler;
        _context = context;
        
        _safariViewController = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:NO];
        _safariViewController.delegate = self;
    }
    return self;
}

- (void)cancel
{
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceled, @"Authorization session was cancelled programatically", nil, nil, nil, _context.correlationId, nil);
    
    [self completeSessionWithResponse:nil context:_context error:error];
}

- (BOOL)start
{
    UIViewController *viewController; // TODO: Get current view controller
    if (!viewController)
    {
        return NO;
    }
    
    [viewController presentViewController:_safariViewController animated:YES completion:nil];

    return YES;
}


- (BOOL)handleURLResponse:(NSURL *)url
{
    if (!url || !_safariViewController)
    {
        return NO;
    }
    
    return [self completeSessionWithResponse:url context:nil error:nil];
}


- (BOOL)completeSessionWithResponse:(NSURL *)url
                            context:(id<MSIDRequestContext>)context
                              error:(NSError *)error
{
    if ([NSThread isMainThread])
    {
        [_safariViewController dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_safariViewController dismissViewControllerAnimated:YES completion:nil];
        });
    }
    
    MSIDWebUICompletionHandler completionHandler = nil;
    @synchronized (self)
    {
        completionHandler = _completionHandler;
        _completionHandler = nil;
    }
    
    _safariViewController = nil;
    
    if (!completionHandler)
    {
        // MSAL response received but no completion block saved
        return NO;
    }
    
    if (error)
    {
        completionHandler(nil, error);
        return YES;
    }
    
    NSError *otherError = nil;
    MSIDWebOAuth2Response *response = [MSIDWebOAuth2Response responseWithURL:url
                                                                     context:context
                                                                       error:&otherError];
    
    completionHandler(response, otherError);
    return YES;
}


#pragma mark - SFSafariViewControllerDelegate
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    // user cancel
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, _context.correlationId, nil);
    
    [self completeSessionWithResponse:nil
                              context:_context error:error];
}

@end
