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
#import "MSIDWebviewInteracting.h"

@implementation MSIDWebviewAuthorization

static id<MSIDWebviewInteracting> s_currentWebSession = nil;

+ (void)startEmbeddedWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                              factory:(MSIDOAuth2Factory *)factory
{
    
}

+ (void)startEmbeddedWebviewWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                                     webview:(WKWebView *)webview
                                                     factory:(MSIDOAuth2Factory *)factory
{
    
}

+ (void)startSystemWebviewWebviewAuthWithRequestParameters:(MSIDRequestParameters *)parameters
                                                   factory:(MSIDOAuth2Factory *)factory
{
    
}

+ (BOOL)setCurrentWebSession:(id<MSIDWebviewInteracting>)newWebSession
{
    if (!s_currentWebSession)
    {
        @synchronized([MSIDWebviewAuthorization class])
        {
            s_currentWebSession = newWebSession;
        }
        return YES;
    }
    
    return NO;
    
    
}

+ (BOOL)handleURLResponse:(NSURL *)url
{
    return NO;
}

+ (BOOL)cancelCurrentWebAuthSession
{
    return NO;
}

@end
