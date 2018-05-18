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

#import "MSIDSFAuthenticationSession.h"
#import <SafariServices/SafariServices.h>
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebOAuth2Response.h"

@implementation MSIDSFAuthenticationSession
{
    API_AVAILABLE(ios(11.0))
    SFAuthenticationSession *_authSession;
    
    NSURL *_startURL;
    NSString *_callbackURLScheme;

    id<MSIDRequestContext> _context;
}

- (instancetype)initWithURL:(NSURL *)url
          callbackURLScheme:(NSString *)callbackURLScheme
               requestState:(NSString *)requestState
              stateVerifier:(MSIDWebUIStateVerifier)stateVerifier
                    context:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _startURL = url;
        _context = context;
        _requestState = requestState;
        _stateVerifier = stateVerifier;
    }
    
    return self;
}


- (BOOL)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (@available(iOS 11.0, *))
    {
        _authSession = [[SFAuthenticationSession alloc] initWithURL:_startURL
                                                  callbackURLScheme:_callbackURLScheme
                                                  completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
                                            {
                                                if (error)
                                                {
                                                    if (error.code == SFAuthenticationErrorCanceledLogin)
                                                    {
                                                        error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, _context.correlationId, nil);
                                                    }
                                                    completionHandler(nil, error);
                                                    return;
                                                }
                                
                                                NSError *authError = nil;
                                                MSIDWebOAuth2Response *response = [MSIDWebviewAuthorization responseWithURL:callbackURL
                                                                                                               requestState:self.requestState
                                                                                                              stateVerifier:self.stateVerifier
                                                                                                                    context:_context
                                                                                                                      error:&authError];

                                                completionHandler(response, authError);
                                            }];
        return  [_authSession start];;
    }
    return NO;
}


- (void)cancel
{
    MSID_LOG_INFO(_context, @"Authorization session was cancelled programatically");
    [_authSession cancel];
}

@end

