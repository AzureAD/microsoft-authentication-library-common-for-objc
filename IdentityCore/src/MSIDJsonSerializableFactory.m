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

#import "MSIDJsonSerializableFactory.h"
#import "MSIDJsonSerializable.h"

static NSMutableDictionary<NSString *, Class<MSIDJsonSerializable>> *s_container = nil;

@implementation MSIDJsonSerializableFactory

+ (void)registertClass:(Class<MSIDJsonSerializable>)class forKey:(NSString *)key
{
    if (!class || !key) return;
    if (![key isKindOfClass:NSString.class]) return;
    if (![class conformsToProtocol:@protocol(MSIDJsonSerializable)]) return;
    
    @synchronized(self)
    {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            s_container = [NSMutableDictionary new];
        });
        
        s_container[key] = class;
    }
}

+ (void)unregisterAll
{
    @synchronized(self)
    {
        [s_container removeAllObjects];
    }
}

+ (id<MSIDJsonSerializable>)createFromJSONDictionary:(NSDictionary *)json
                                        classTypeKey:(NSString *)classTypeKey
                                               error:(NSError **)error
{
    if (![json msidAssertType:NSString.class ofKey:classTypeKey required:YES error:error]) return nil;
    NSString *containerKey = json[classTypeKey];
    
    Class class = (Class<MSIDJsonSerializable>)s_container[containerKey];
    
    if (!class)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"Failed to create object from json, class: %@ wasn't registered in factory under %@ key.", class, classTypeKey];
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
    
    return [[(Class)class alloc] initWithJSONDictionary:json error:error];
}

@end
