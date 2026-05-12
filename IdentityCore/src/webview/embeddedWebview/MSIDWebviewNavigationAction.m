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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDWebviewNavigationAction.h"

@implementation MSIDWebviewNavigationAction

#pragma mark - Initializers

- (instancetype)initWithType:(MSIDWebviewNavigationActionType)type
                     request:(NSURLRequest *)request
                         url:(NSURL *)url
                       error:(NSError *)error
{
    self = [super init];
    if (self)
    {
        _type = type;
        _request = request;
        _url = url;
        _error = error;
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)continueDefaultAction
{
    return [[self alloc] initWithType:MSIDWebviewNavigationActionTypeContinueDefault
                              request:nil
                                  url:nil
                                error:nil];
}

+ (instancetype)loadRequestAction:(NSURLRequest *)request
{
    return [[self alloc] initWithType:MSIDWebviewNavigationActionTypeLoadRequestInWebview
                              request:request
                                  url:nil
                                error:nil];
}

+ (instancetype)completeWebAuthWithURLAction:(NSURL *)url
{
    return [[self alloc] initWithType:MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL
                              request:nil
                                  url:url
                                error:nil];
}

+ (instancetype)failWebAuthWithErrorAction:(NSError *)error
{
    return [[self alloc] initWithType:MSIDWebviewNavigationActionTypeFailWithError
                              request:nil
                                  url:nil
                                error:error];
}

#pragma mark - Validation

- (BOOL)isValid
{
    switch (self.type)
    {
        case MSIDWebviewNavigationActionTypeLoadRequestInWebview:
            // Must have a request to load
            return self.request != nil;
            
        case MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL:
            // Must have a URL
            return self.url != nil;
            
        case MSIDWebviewNavigationActionTypeFailWithError:
            // Must have an error
            return self.error != nil;
            
        case MSIDWebviewNavigationActionTypeContinueDefault:
            // Always valid - no required properties
            return YES;
            
        default:
            // Unknown action type
            return NO;
    }
}

@end
