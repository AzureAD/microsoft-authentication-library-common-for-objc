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

#import "MSIDCacheAside.h"
#import "MSIDMetadataCacheDataSource.h"
#import "MSIDCache.h"
#import "MSIDJsonSerializable.h"
#import "MSIDJsonSerializer.h"
#import "MSIDJsonSerializing.h"

@implementation MSIDCacheAside
{
    MSIDCache *_memoryCache;
    id<MSIDMetadataCacheDataSource> _dataSource;
    dispatch_queue_t _synchronizationQueue;
    MSIDJsonSerializer *_jsonSerializer;
}

- (instancetype)initWithDataSource:(id<MSIDMetadataCacheDataSource>)dataSource
{
    if (!dataSource) return nil;
    
    self = [super init];
    
    if (self)
    {
        _memoryCache = [MSIDCache new];
        _dataSource = dataSource;
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidcacheaside-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        _jsonSerializer = [MSIDJsonSerializer new];
    }
    
    return self;
}

- (id<MSIDJsonSerializable>)cacheItemWithKey:(MSIDCacheKey *)key
                                      ofType:(Class)klass
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    if (!key) return nil;
    
    NSParameterAssert([klass conformsToProtocol:@protocol(MSIDJsonSerializable)]);
    if (![klass conformsToProtocol:@protocol(MSIDJsonSerializable)]) return nil;
    
    __block id item;
    __block NSError *localError;
    dispatch_sync(_synchronizationQueue, ^{
        item = [self cacheItemWithKeyImpl:key ofType:klass context:context error:&localError];
    });
    
    if (localError)
    {
        if (error) *error = localError;
    }
    
    return item;
}

- (BOOL)updateCacheItem:(id<MSIDJsonSerializable>)cacheItem
                withKey:(MSIDCacheKey *)key
                 ofType:(Class)klass
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (!cacheItem || !key)
    {
        if (error) *error = MSIDCreateError(MSIDErrorDomain,
                                            MSIDErrorInvalidInternalParameter,
                                            @"cacheItem and key could not be nil.",
                                            nil, nil, nil, nil, nil);
        return NO;
    }
    
    __block BOOL update;
    __block NSError *localError;
    //Will it be better if we make it dispatch_barrier_async?
    //such that we need to remove all the return values of this function, i.e. BOOL and error.
    dispatch_barrier_sync(_synchronizationQueue, ^{
        NSError *localError = nil;
        id<MSIDJsonSerializable> item = [self cacheItemWithKeyImpl:key ofType:klass context:context error:&localError];
        
        if (localError)
        {
            update = NO;
        }
        else if (cacheItem == item)
        {
            update = YES;
        }
        else
        {
            [_memoryCache setObject:cacheItem forKey:key];
            update = [self saveItemToDataSource:cacheItem forKey:key error:&localError];
        }
    });
    
    if (error) *error = localError;
    
    return update;
}

- (id<MSIDJsonSerializable>)cacheItemWithKeyImpl:(MSIDCacheKey *)key
                                          ofType:(Class)klass
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    id<MSIDJsonSerializable> item = [_memoryCache objectForKey:key];
    if (item) return item;
    
    NSError *localError = nil;
    NSData *data = [_dataSource itemWithKey:key error:&localError];
    if (data && !localError)
    {
        item = [_jsonSerializer fromJsonData:data ofType:klass context:context error:&localError];
    }
    
    if (localError)
    {
        if (error) *error = localError;
        return nil;
    }
    
    if (item)
    {
        [_memoryCache setObject:item forKey:key];
    }
    
    return item;
}

- (BOOL)saveItemToDataSource:(id<MSIDJsonSerializable>)cacheItem
                      forKey:key
                     context:(id<MSIDRequestContext>)context
                       error:(NSError **)error
{
    NSData *data = [_jsonSerializer toJsonData:cacheItem context:context error:error];
    if (!data) return NO;
    
    return [_dataSource saveOrUpdateItem:data forKey:key error:error];
}

@end
