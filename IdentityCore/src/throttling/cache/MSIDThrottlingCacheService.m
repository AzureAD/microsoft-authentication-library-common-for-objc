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


#import <Foundation/Foundation.h>
#import "MSIDThrottlingCacheService.h"
#import "MSIDThrottlingCacheNode.h"
#import "MSIDThrottlingCacheRecord.h"
#import "MSIDCache.h"

static NSString *const HEAD_NODE_KEY = @"HEAD";
static NSString *const TAIL_NODE_KEY = @"TAIL";

@interface MSIDThrottlingCacheNode ()

- (void)setPrevRequestThumbprintKey:(NSString *)prevRequestThumbprintKey;
- (void)setNextRequestThumbprintKey:(NSString *)nextRequestThumbprintKey;

@end

@interface MSIDThrottlingCacheService ()

@property (nonatomic) NSUInteger cacheSizeInt;
@property (nonatomic) MSIDThrottlingCacheNode *head;
@property (nonatomic) MSIDThrottlingCacheNode *tail;
@property (nonatomic) NSMutableDictionary *container;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDThrottlingCacheService

- (NSUInteger)cacheSize
{
    return self.cacheSizeInt-2;
}

- (instancetype)initWithThrottlingCacheSize:(NSUInteger)cacheSize
{
    self = [super init];
    if (self)
    {
        _cacheSizeInt = cacheSize+2;
        //create dummy head and tail
        _head = [[MSIDThrottlingCacheNode alloc] initWithThumbprintKey:HEAD_NODE_KEY
                                                         errorResponse:nil
                                                          throttleType:nil
                                                      throttleDuration:0
                                              prevRequestThumbprintKey:nil
                                              nextRequestThumbprintKey:TAIL_NODE_KEY];
        
        _tail = [[MSIDThrottlingCacheNode alloc] initWithThumbprintKey:TAIL_NODE_KEY
                                                         errorResponse:nil
                                                          throttleType:nil
                                                      throttleDuration:0
                                              prevRequestThumbprintKey:HEAD_NODE_KEY
                                              nextRequestThumbprintKey:nil];
        
        //create concurrent queue and container dictionary
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidthrottlingcache-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        _container = [NSMutableDictionary new];
        
        [self.container setObject:_head forKey:HEAD_NODE_KEY];
        [self.container setObject:_tail forKey:TAIL_NODE_KEY];
        
        
    }
    return self;
}

/* add new node to the front of LRU cache.
if node already exists, update and move it to the front of LRU cache */
- (void)addRequestToCache:(NSString *)thumbprintKey
            errorResponse:(NSError *)errorResponse
             throttleType:(NSString *)throttleType
         throttleDuration:(NSInteger)throttleDuration
                    error:(NSError **)error
{
    __block NSError *subError = nil;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        if (self.cacheSizeInt <= 2)
        {
            subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDThrottlingCacheService Error: Attempting to write to an empty cache!", nil, nil, nil, nil, nil, YES);
        }
        
        else
        {
            //node already exists - simply move it to front
            if ([self.container objectForKey:thumbprintKey])
            {
                [self getResponseFromCacheImpl:thumbprintKey
                                         error:&subError];
            }
            
            else
            {
                //if cache is full, invalidate least recently used entry
                if (self.container.allKeys.count >= self.cacheSizeInt)
                {
                    NSString *leastRecentlyUsed = self.tail.prevRequestThumbprintKey;
                    [self removeRequestFromCacheImpl:leastRecentlyUsed
                                               error:&subError];
                }
                MSIDThrottlingCacheNode *newNode = [[MSIDThrottlingCacheNode alloc] initWithThumbprintKey:thumbprintKey
                                                                                            errorResponse:errorResponse
                                                                                             throttleType:throttleType
                                                                                         throttleDuration:throttleDuration
                                                                                 prevRequestThumbprintKey:nil
                                                                                 nextRequestThumbprintKey:nil];
                [self addToFrontImpl:newNode];
            }
        }
    });
    
    if (error)
    {
        *error = subError;
    }
}


- (void)removeRequestFromCache:(NSString *)thumbprintKey
                         error:(NSError **)error
{
    __block NSError *subError = nil;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        [self removeRequestFromCacheImpl:thumbprintKey
                                   error:&subError];
    });
    if (error)
    {
        *error = subError;
    }
}

- (void)removeRequestFromCacheImpl:(NSString *)thumbprintKey
                             error:(NSError **)error
{
    if (![self.container objectForKey:thumbprintKey])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDThrottlingCacheService Error: Attempting to remove a non-existent entry!", nil, nil, nil, nil, nil, YES);
        }
        return;
    }
    
    MSIDThrottlingCacheNode *node = [self.container objectForKey:thumbprintKey];
    MSIDThrottlingCacheNode *prevNode = [self.container objectForKey:node.prevRequestThumbprintKey];
    MSIDThrottlingCacheNode *nextNode = [self.container objectForKey:node.nextRequestThumbprintKey];

    prevNode.nextRequestThumbprintKey = node.nextRequestThumbprintKey;
    nextNode.prevRequestThumbprintKey = node.prevRequestThumbprintKey;

    [self.container setObject:prevNode forKey:node.prevRequestThumbprintKey];
    [self.container setObject:nextNode forKey:node.nextRequestThumbprintKey];
    
    [self.container removeObjectForKey:thumbprintKey];
}

//retrieve cache record from the corresponding node, and move the node to the front of LRU cache.
- (MSIDThrottlingCacheRecord *)getResponseFromCache:(NSString *)thumbprintKey
                                              error:(NSError **)error
{
    __block MSIDThrottlingCacheRecord *throttlingCacheRecord;
    __block NSError *subError = nil;
    dispatch_sync(self.synchronizationQueue, ^{
        throttlingCacheRecord = [self getResponseFromCacheImpl:thumbprintKey
                                                         error:&subError];
    });
    
    if (error)
    {
        *error = subError;
    }
    
    return throttlingCacheRecord;
}

- (MSIDThrottlingCacheRecord *)getResponseFromCacheImpl:(NSString *)thumbprintKey
                                                  error:(NSError **)error
{
    if (![self.container objectForKey:thumbprintKey])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDThrottlingCacheService Error: Attempting to retrieve a non-existent entry!", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }
    
    MSIDThrottlingCacheNode *node = [self.container objectForKey:thumbprintKey];
    node.cacheRecord.throttledCount += 1; //update throttledCount for telemetry purpose
    //remove from current cache slot
    [self removeRequestFromCacheImpl:thumbprintKey
                               error:error];
    //move to front
    [self addToFrontImpl:node];
    
    return node.cacheRecord;
    
}

- (void)addToFront:(MSIDThrottlingCacheNode *)node
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        [self addToFrontImpl:node];
    });
}

- (void)addToFrontImpl:(MSIDThrottlingCacheNode *)node
{
    NSString *currentHeadKey = self.head.nextRequestThumbprintKey; //node currently pointed by the head
    MSIDThrottlingCacheNode *currentHeadNode = [self.container objectForKey:currentHeadKey];
    currentHeadNode.prevRequestThumbprintKey = node.requestThumbprintKey;
    [self.container setObject:currentHeadNode forKey:currentHeadKey];
    
    node.prevRequestThumbprintKey = HEAD_NODE_KEY;
    node.nextRequestThumbprintKey = currentHeadKey;
    
    self.head.nextRequestThumbprintKey = node.requestThumbprintKey;
    [self.container setObject:node forKey:node.requestThumbprintKey];
}

- (MSIDThrottlingCacheNode *)getHeadNode
{
    __block MSIDThrottlingCacheNode *node;
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self.head.nextRequestThumbprintKey isEqualToString:TAIL_NODE_KEY])
        {
            node = [self.container objectForKey:self.head.nextRequestThumbprintKey];
        }
    });
    return node;
    
}

- (MSIDThrottlingCacheNode *)getTailNode
{
    __block MSIDThrottlingCacheNode *node;
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self.tail.prevRequestThumbprintKey isEqualToString:HEAD_NODE_KEY])
        {
            node = [self.container objectForKey:self.tail.prevRequestThumbprintKey];
        }
    });
    return node;
}

- (NSArray *)enumerateAndReturnAllObjects
{
    __block NSMutableArray *res;
    dispatch_sync(self.synchronizationQueue, ^{
        res = [self enumerateAndReturnAllObjectsImpl];
    });
    return res;
}

- (NSMutableArray *)enumerateAndReturnAllObjectsImpl
{
    NSMutableArray *res;
    if (![self.head.nextRequestThumbprintKey isEqualToString:TAIL_NODE_KEY])
    {
        res = [NSMutableArray new];
        NSMutableString *key = [self.head.nextRequestThumbprintKey mutableCopy];
        
        while (![key isEqualToString:TAIL_NODE_KEY])
        {
            MSIDThrottlingCacheNode *node = [self.container objectForKey:key];
            [key setString:node.nextRequestThumbprintKey];
            [res addObject:node];
        }
    }
    return res;
}

- (void)removeAllExpiredObjects:(NSError *__nullable*__nullable)error
{
    __block NSError *subError;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        NSMutableArray *arr = [self enumerateAndReturnAllObjectsImpl];
        if (arr)
        {
            NSDate *currentTime = [NSDate date];
            for (id object in arr)
            {
                if ([object isKindOfClass:[MSIDThrottlingCacheNode class]])
                {
                    MSIDThrottlingCacheNode *throttlingCacheNode = (MSIDThrottlingCacheNode *)object;
                    NSString *thumbprintKey = throttlingCacheNode.requestThumbprintKey;
                    MSIDThrottlingCacheRecord *throttlingCacheRecord = throttlingCacheNode.cacheRecord;
                    if (([currentTime compare:throttlingCacheRecord.expirationTime] == NSOrderedDescending) ||
                        ([currentTime compare:throttlingCacheRecord.creationTime] == NSOrderedAscending))
                    {
                        [self removeRequestFromCacheImpl:thumbprintKey
                                                   error:&subError];
                    }
                }
            }
        }
        
        else
        {
            subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDThrottlingCacheService Error: Attempting to remove entries from an empty cache!", nil, nil, nil, nil, nil, YES);
        }
    });
    
    if (error)
    {
        *error = subError;
    }
}

@end
