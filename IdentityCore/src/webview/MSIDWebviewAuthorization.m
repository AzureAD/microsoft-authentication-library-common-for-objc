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

#import "MSIDWebviewAuthorization.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"

@implementation MSIDWebviewAuthorization



+ (id<MSIDWebviewInteracting>)embeddedWebviewControllerWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                     factory:(MSIDOauth2Factory *)factory;
{
    return nil;
}

+ (id<MSIDWebviewInteracting>)embeddedWebviewControllerWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                     webview:(WKWebView *)webview
                                                                     factory:(MSIDOauth2Factory *)factory;
{
    return nil;
}

+ (id<MSIDWebviewInteracting>)systemWebviewControllerWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                   factory:(MSIDOauth2Factory *)factory;
{
    return nil;
}

+ (BOOL)handleURLResponse:(NSURL *)url
{
    return NO;
}

+ (void)startWebviewSession:(MSIDRequestParameters *)parameters
                    factory:(MSIDOauth2Factory *)factory
          completionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    //TODO: make sure only one webview session is going on at the same time
    
    NSURL *startURL = [factory generateStartURL:parameters];
    MSIDOAuth2EmbeddedWebviewController *webviewController = [MSIDOAuth2EmbeddedWebviewController new];
    [webviewController startWithURL:startURL completion:completionHandler];
}

@end
