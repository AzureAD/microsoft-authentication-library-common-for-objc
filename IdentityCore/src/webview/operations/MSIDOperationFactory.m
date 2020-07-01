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

#import <Foundation/Foundation.h>
#import "MSIDOperationFactory.h"
#import "MSIDWebviewResponse.h"
#import "MSIDBaseOperation.h"

static NSMutableDictionary *s_container = nil;

@implementation MSIDOperationFactory

+ (void)registerOperationClass:(Class)operationClass
              forResponseClass:(Class)responseClass
{
    if (!operationClass || !responseClass) return;
    if (![operationClass isSubclassOfClass:MSIDBaseOperation.class]) return;
    if (![responseClass isSubclassOfClass:MSIDWebviewResponse.class]) return;

    @synchronized(self)
    {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            s_container = [NSMutableDictionary new];
        });

        NSString *operation = [responseClass operation];
        s_container[operation] = operationClass;
    }
}

+ (void)unregisterAll
{
    @synchronized(self)
    {
        [s_container removeAllObjects];
    }
}

+ (MSIDBaseOperation *)createOperationForResponse:(MSIDWebviewResponse *)response
                                      error:(NSError **)error
{
    if (!response) return nil;

    NSString *operation = [response.class operation];
    Class operationClass = s_container[operation];

    if (!operationClass)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"No operation for response: %@.", response.class);
        return nil;
    }

    return [[(Class)operationClass alloc] initWithResponse:response error:error];
}

@end
