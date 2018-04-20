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

#import "MSIDOAuth2WebviewController.h"
#import "MSIDEmbeddedWebviewRequest.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDWebviewUIController.h"
#import "MSIDError.h"
#import "MSIDWebOAuth2Response.h"

@implementation MSIDOAuth2WebviewController
{
    MSIDEmbeddedWebviewRequest *_webviewRequest;
    MSIDWebviewUIController *_webviewUIController;
    NSLock *_completionLock;
    void (^_completionHandler)(MSIDWebOAuth2Response *response, NSError *error);
}

- (id)init
{
    //Ensure that the appropriate init function is called. This will cause the runtime to throw.
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithRequest:(MSIDEmbeddedWebviewRequest *)request
{
    self = [super init];
    
    if (self)
    {
        _webviewRequest = request;
        _completionLock = [[NSLock alloc] init];
    }
    
    return self;
}

- (void)startRequestWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    // If we're not on the main thread when trying to kick up the UI then
    // dispatch over to the main thread.
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startRequestWithCompletionHandler:completionHandler];
        });
        return;
    }
    
    // Save the completion block
    _completionHandler = [completionHandler copy];
    
    _webviewUIController = [MSIDWebviewUIController new];
    [_webviewUIController loadView:nil];
    [_webviewUIController startRequest:[[NSMutableURLRequest alloc] initWithURL:_webviewRequest.startURL]];
}

- (BOOL)endWebAuthenticationWithError:(NSError *) error
                                orURL:(NSURL*)endURL
{
    if (!_webviewUIController)
    {
        return NO;
    }
    
    [_webviewUIController stop:^{[self dispatchCompletionBlock:error URL:endURL];}];
    _webviewUIController = nil;
    
    return YES;
}

- (void)dispatchCompletionBlock:(NSError *)error URL:(NSURL *)url
{
    // NOTE: It is possible that competition between a successful completion
    //       and the user cancelling the authentication dialog can
    //       occur causing this method to be called twice. The competition
    //       cannot be blocked at its root, and so this method must
    //       be resilient to this condition and should not generate
    //       two callbacks.
    [_completionLock lock];
    
    if ( _completionHandler )
    {
        void (^completionHandler)(MSIDWebOAuth2Response *response, NSError *error) = _completionHandler;
        _completionHandler = nil;
        
        //TODO: think about how to generate different type of response from URL
        MSIDWebOAuth2Response *response = [MSIDWebOAuth2Response new];
        dispatch_async( dispatch_get_main_queue(), ^{
            completionHandler(response, error);
        });
    }
    
    [_completionLock unlock];
}

#pragma mark - MSIDWebviewDelegate

- (void)webAuthDidStartLoad:(NSURL*)url
{
}

- (void)webAuthDidFinishLoad:(NSURL*)url
{
}

- (BOOL)webAuthShouldStartLoadRequest:(NSURLRequest *)request
{
    NSString *requestURL = [request.URL absoluteString];
    
    // Stop at the end URL.
    if ([[requestURL lowercaseString] hasPrefix:[_webviewRequest.endURL.absoluteString lowercaseString]])
    {
        NSURL* url = request.URL;
        [self webAuthDidCompleteWithURL:url];
        
        // Tell the web view that this URL should not be loaded.
        return NO;
    }
    
    return YES;
}

// The user cancelled authentication
- (void)webAuthDidCancel
{
    // Dispatch the completion block
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"The user has cancelled the authorization.", nil, nil, nil, nil, nil);
    [self endWebAuthenticationWithError:error orURL:nil];
}

// Authentication completed at the end URL
- (void)webAuthDidCompleteWithURL:(NSURL *)endURL
{
    [self endWebAuthenticationWithError:nil orURL:endURL];
}

// Authentication failed somewhere
- (void)webAuthDidFailWithError:(NSError *)error
{
    // Ignore WebKitError 102 for OAuth 2.0 flow.
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)
    {
        return;
    }
    
    // Prior to iOS 10 the WebView trapped out this error code and didn't pass it along to us
    // now we have to trap it out ourselves.
    if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError)
    {
        return;
    }
    
    // If we failed on an invalid URL check to see if it matches our end URL
    if ([error.domain isEqualToString:@"NSURLErrorDomain"] && (error.code == -1002 || error.code == -1003))
    {
        NSURL* url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        NSString* urlString = [url absoluteString];
        if ([[urlString lowercaseString] hasPrefix:_webviewRequest.endURL.absoluteString.lowercaseString])
        {
            [self webAuthDidCompleteWithURL:url];
            return;
        }
        
    }
    
    if (NSURLErrorCancelled == error.code)
    {
        //This is a common error that webview generates and could be ignored.
        //See this thread for details: https://discussions.apple.com/thread/1727260
        return;
    }
    
    if([error.domain isEqual:@"WebKitErrorDomain"])
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{ [self endWebAuthenticationWithError:error orURL:nil]; });
}

@end
