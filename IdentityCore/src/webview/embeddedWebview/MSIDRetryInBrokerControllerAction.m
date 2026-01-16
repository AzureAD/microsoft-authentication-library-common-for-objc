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

#import "MSIDRetryInBrokerControllerAction.h"
#import "MSIDInteractiveWebviewState.h"
#import "MSIDInteractiveWebviewHandler.h"

@implementation MSIDRetryInBrokerControllerAction

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        _url = url;
    }
    return self;
}

- (void)executeWithState:(MSIDInteractiveWebviewState *)state
                 handler:(id<MSIDInteractiveWebviewHandler>)handler
              completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // Retry the interactive request in broker context
    [handler retryInteractiveRequestInBrokerContextForURL:self.url
                                               completion:^(BOOL success, NSError * _Nullable error) {
        if (success)
        {
            // Mark that we've transferred to broker
            state.transferredToBroker = YES;
            
            // Dismiss the embedded webview since broker will take over
            [handler dismissEmbeddedWebviewIfPresent];
        }
        
        completion(success, error);
    }];
}

@end
