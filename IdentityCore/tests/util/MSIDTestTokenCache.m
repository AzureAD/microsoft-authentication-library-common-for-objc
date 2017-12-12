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

#import "MSIDTestTokenCache.h"
#import "MSIDTokenSerializer.h"

#include <pthread.h>

@implementation MSIDTestTokenCache
{
    NSMutableDictionary *_cache;
    pthread_rwlock_t _lock;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _cache = [NSMutableDictionary new];
    
    pthread_rwlock_init(&_lock, NULL);
    
    return self;
}

- (void)dealloc
{
    _cache = nil;
    pthread_rwlock_destroy(&_lock);
}


- (BOOL)setItem:(MSIDToken *)item
            key:(MSIDTokenCacheKey *)key
     serializer:(id<MSIDTokenSerializer>)serializer
        context:(id<MSIDRequestContext>)context
          error:(NSError **)error
{
    
    return NO;
}

- (MSIDToken *)itemWithKey:(MSIDTokenCacheKey *)key
                serializer:(id<MSIDTokenSerializer>)serializer
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    return nil;
}

- (BOOL)removeItemsWithKey:(MSIDTokenCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    return NO;
}

- (NSArray<MSIDToken *> *)itemsWithKey:(MSIDTokenCacheKey *)key
                            serializer:(id<MSIDTokenSerializer>)serializer
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    return nil;
}

- (BOOL)saveWipeInfo:(NSDictionary *)wipeInfo
             context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    return NO;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    return nil;
}

@end
