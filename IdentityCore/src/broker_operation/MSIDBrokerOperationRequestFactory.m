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

#import "MSIDBrokerOperationRequestFactory.h"
#import "MSIDBrokerOperationRequest.h"
#import "MSIDJsonSerializable.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDConstants.h"

static NSMutableDictionary *s_operationRequestClasses = nil;

@implementation MSIDBrokerOperationRequestFactory

+ (void)registerOperationRequestClass:(Class<MSIDJsonSerializable>)operationRequestClass
                            operation:(NSString *)operation
{
    if (!operationRequestClass || !operation) return;
    if ([operationRequestClass isKindOfClass:MSIDBrokerOperationRequest.class]) return;
    
    @synchronized(self)
    {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            s_operationRequestClasses = [NSMutableDictionary new];
        });
        
        s_operationRequestClasses[operation] = operationRequestClass;
    }
}

+ (void)unregisterAll
{
    @synchronized(self)
    {
        [s_operationRequestClasses removeAllObjects];
    }
}

- (MSIDBrokerOperationRequest *)operationRequestFromJSONDictionary:(NSDictionary *)json
                                                             error:(NSError **)error
{
    if (![json msidAssertType:NSString.class ofKey:MSID_BROKER_OPERATION_KEY required:YES error:error]) return nil;
    NSString *operation = json[MSID_BROKER_OPERATION_KEY];
    
    Class operationRequestClass = s_operationRequestClasses[operation];
    
    if (!operationRequestClass)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"Unknown broker operation: %@", operation];
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInvalidDeveloperParameter,
                                     errorMessage,
                                     nil, nil, nil, nil, nil);
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        return nil;
    }
    
    return [[(Class)operationRequestClass alloc] initWithJSONDictionary:json error:error];
}

@end
