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

#import "MSIDWebviewAction.h"

@implementation MSIDWebviewAction

- (instancetype)initWithType:(MSIDWebviewActionType)type
                     request:(NSURLRequest *)request
                         url:(NSURL *)url
                     purpose:(MSIDSystemWebviewPurpose)purpose
                       error:(NSError *)error
{
    self = [super init];
    if (self)
    {
        _type = type;
        _request = request;
        _url = url;
        _purpose = purpose;
        _error = error;
    }
    return self;
}

#pragma mark - Convenience constructors

+ (instancetype)noopAction
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeNoop
                              request:nil
                                  url:nil
                              purpose:MSIDSystemWebviewPurposeUnknown
                                error:nil];
}

+ (instancetype)loadRequestAction:(NSURLRequest *)request
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeLoadRequestInWebview
                              request:request
                                  url:nil
                              purpose:MSIDSystemWebviewPurposeUnknown
                                error:nil];
}

+ (instancetype)openASWebAuthSessionAction:(NSURL *)url purpose:(MSIDSystemWebviewPurpose)purpose
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeOpenASWebAuthenticationSession
                              request:nil
                                  url:url
                              purpose:purpose
                                error:nil];
}

+ (instancetype)openExternalBrowserAction:(NSURL *)url
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeOpenExternalBrowser
                              request:nil
                                  url:url
                              purpose:MSIDSystemWebviewPurposeUnknown
                                error:nil];
}

+ (instancetype)completeWithURLAction:(NSURL *)url
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeCompleteWithURL
                              request:nil
                                  url:url
                              purpose:MSIDSystemWebviewPurposeUnknown
                                error:nil];
}

+ (instancetype)failWithErrorAction:(NSError *)error
{
    return [[self alloc] initWithType:MSIDWebviewActionTypeFailWithError
                              request:nil
                                  url:nil
                              purpose:MSIDSystemWebviewPurposeUnknown
                                error:error];
}

@end
