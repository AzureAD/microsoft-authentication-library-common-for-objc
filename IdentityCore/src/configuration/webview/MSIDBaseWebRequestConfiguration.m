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

#import "MSIDBaseWebRequestConfiguration.h"

@implementation MSIDBaseWebRequestConfiguration

- (instancetype)initWithStartURL:(NSURL *)startURL
                  endRedirectUri:(NSString *)endRedirectUri
                           state:(NSString *)state
              ignoreInvalidState:(BOOL)ignoreInvalidState
                      ssoContext:(MSIDExternalSSOContext *)ssoContext
{
    self = [super init];
    
    if (self)
    {
        _startURL = startURL;
        _endRedirectUrl = endRedirectUri;
        _state = state;
        _ignoreInvalidState = ignoreInvalidState;
        _ssoContext = ssoContext;
    }
    
    return self;
}

- (instancetype)initWithStartURL:(NSURL *)startURL
                  endRedirectUri:(NSString *)endRedirectUri
                           state:(NSString *)state
              ignoreInvalidState:(BOOL)ignoreInvalidState
{
    return [self initWithStartURL:startURL
                   endRedirectUri:endRedirectUri
                            state:state
               ignoreInvalidState:ignoreInvalidState
                       ssoContext:nil];
}

- (MSIDWebviewResponse *)responseWithResultURL:(__unused NSURL *)url
                                       factory:(__unused MSIDWebviewFactory *)factory
                                       context:(__unused id<MSIDRequestContext>)context
                                         error:(__unused NSError *__autoreleasing*)error
{
    return nil;
}

@end
