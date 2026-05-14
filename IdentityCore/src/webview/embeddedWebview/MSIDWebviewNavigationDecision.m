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

#import "MSIDWebviewNavigationDecision.h"

@implementation MSIDWebviewNavigationDecision

#pragma mark - Initializers

- (instancetype)initWithType:(MSIDWebviewNavigationDecisionType)type
                     request:(NSURLRequest *)request
                         URL:(NSURL *)URL
                       error:(NSError *)error
{
    self = [super init];
    if (self)
    {
        _type = type;
        _request = request;
        _URL = URL;
        _error = error;
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)continueDefault
{
    return [[self alloc] initWithType:MSIDWebviewNavigationDecisionContinueDefault
                              request:nil
                                  URL:nil
                                error:nil];
}

+ (instancetype)loadRequest:(NSURLRequest *)request
{
    return [[self alloc] initWithType:MSIDWebviewNavigationDecisionLoadRequest
                              request:request
                                  URL:nil
                                error:nil];
}

+ (instancetype)completeWithURL:(NSURL *)URL
{
    return [[self alloc] initWithType:MSIDWebviewNavigationDecisionCompleteWithURL
                              request:nil
                                  URL:URL
                                error:nil];
}

+ (instancetype)failWithError:(NSError *)error
{
    return [[self alloc] initWithType:MSIDWebviewNavigationDecisionFailWithError
                              request:nil
                                  URL:nil
                                error:error];
}

#pragma mark - Validation

- (BOOL)isValid
{
    switch (self.type)
    {
        case MSIDWebviewNavigationDecisionLoadRequest:
            // Must have a request to load
            return self.request != nil;
            
        case MSIDWebviewNavigationDecisionCompleteWithURL:
            // Must have a URL
            return self.URL != nil;
            
        case MSIDWebviewNavigationDecisionFailWithError:
            // Must have an error
            return self.error != nil;
            
        case MSIDWebviewNavigationDecisionContinueDefault:
            // Always valid - no required properties
            return YES;
            
        default:
            // Unknown decision type
            return NO;
    }
}

@end
