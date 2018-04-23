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
#import "MSIDSystemWebviewRequest.h"
#import <SafariServices/SafariServices.h>

@implementation MSIDSystemWebviewController
{
    id<MSIDRequestContext> _context;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    SFAuthenticationSession *_authSession;
#endif
}

@synthesize parentViewController;

- (id)initWithStartURL:(NSURL *)startURL
     callbackURLScheme:(NSString *)callbackURLScheme
               context:(id<MSIDRequestContext>)context;
{
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _context = context;
        _callbackURLScheme = callbackURLScheme;
    }
    
    return self;
}

- (void)startRequestWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
#ifdef __IPHONE_11_0
    if (@available(iOS 11.0, *)) {
        _authSession = [[SFAuthenticationSession alloc] initWithURL:_startURL
                                                  callbackURLScheme:_callbackURLScheme
                                                  completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
        {
            
            
        }];
        
    }
    
#endif
}

- (void)cancel
{
    
}

@end
