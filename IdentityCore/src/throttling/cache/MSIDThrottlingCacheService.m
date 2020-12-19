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

@interface MSIDThrottlingCacheService ()

@property (nonatomic) NSUInteger cacheSizeInt;
@property (nonatomic) MSIDThrottlingCacheNode *head;
@property (nonatomic) MSIDThrottlingCacheNode *tail;

@end

@implementation MSIDThrottlingCacheService

- (NSUInteger)cacheSize
{
    return self.cacheSizeInt;
}

- (instancetype)initThrottlingCacheService:(NSUInteger)cacheSize
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
        [self.internalCache setObject:_head forKey:HEAD_NODE_KEY];
        [self.internalCache setObject:_tail forKey:TAIL_NODE_KEY];
    }
    return self;
}

/* add new node to the front of LRU cache.
if node already exists, update and move it to the front of LRU cache */
- (NSError *)addRequestToCache:(NSString *)thumbprintKey
                 errorResponse:(NSError *)errorResponse
                  throttleType:(NSString *)throttleType
              throttleDuration:(NSInteger)throttleDuration
{
    NSError *error = nil;
    if (self.cacheSizeInt <= 0)
    {
        //TODO: LOG Error
        return error;
    }
    
    //node already exists - simply move it to front
    if ([self.internalCache objectForKey:thumbprintKey])
    {
        [self getResponseFromCache:thumbprintKey];
        return nil;
    }
    
    //if cache is full, invalidate least recently used entry
    if ([self.internalCache count] >= self.cacheSizeInt)
    {
        NSString *leastRecentlyUsed = self.tail.prevRequestThumbprintKey;
        [self removeRequestFromCache:leastRecentlyUsed];
    }
    
    MSIDThrottlingCacheNode *newNode = [[MSIDThrottlingCacheNode alloc] initWithThumbprintKey:thumbprintKey
                                                                                errorResponse:errorResponse
                                                                                 throttleType:throttleType
                                                                             throttleDuration:throttleDuration
                                                                     prevRequestThumbprintKey:nil
                                                                     nextRequestThumbprintKey:nil];
    
    [self addToFront:newNode];
    
    return error;
}


- (void)removeRequestFromCache:(NSString *)thumbprintKey
{
    if ([self.internalCache objectForKey:thumbprintKey] == nil)
    {
        return;
    }
    
    MSIDThrottlingCacheNode *node = [self.internalCache objectForKey:thumbprintKey];
    MSIDThrottlingCacheNode *prevNode = [self.internalCache objectForKey:node.prevRequestThumbprintKey];
    MSIDThrottlingCacheNode *nextNode = [self.internalCache objectForKey:node.nextRequestThumbprintKey];

    prevNode.nextRequestThumbprintKey = node.nextRequestThumbprintKey;
    nextNode.prevRequestThumbprintKey = node.prevRequestThumbprintKey;
    [self.internalCache setObject:prevNode forKey:node.prevRequestThumbprintKey];
    [self.internalCache setObject:nextNode forKey:node.nextRequestThumbprintKey];
    
    [self.internalCache removeObjectForKey:thumbprintKey];
}

//retrieve cache record from the corresponding node, and move the node to the front of LRU cache.
- (MSIDThrottlingCacheRecord *)getResponseFromCache:(NSString *)thumbprintKey
{
    MSIDThrottlingCacheNode *node = [self.internalCache objectForKey:thumbprintKey];
    node.cacheRecord.throttledCount += 1; //update throttledCount for telemetry purpose
    //remove from current cache slot
    [self removeRequestFromCache:thumbprintKey];
    //move to front
    [self addToFront:node];
    
    return node.cacheRecord;
}


- (MSIDCache *)internalCache
{
    static MSIDCache *m_cache;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        m_cache = [MSIDCache new];
    });
    return m_cache;
}

- (void)addToFront:(MSIDThrottlingCacheNode *)node
{
    NSString *currentHeadKey = self.head.nextRequestThumbprintKey; //node currently pointed by the head
    MSIDThrottlingCacheNode *currentHeadNode = [self.internalCache objectForKey:currentHeadKey];
    currentHeadNode.prevRequestThumbprintKey = node.requestThumbprintKey; //update linking
    [self.internalCache setObject:currentHeadNode forKey:currentHeadKey];
    
    node.prevRequestThumbprintKey = HEAD_NODE_KEY;
    node.nextRequestThumbprintKey = currentHeadKey;
    
    self.head.nextRequestThumbprintKey = node.requestThumbprintKey;
    [self.internalCache setObject:node forKey:node.requestThumbprintKey];
}

- (MSIDThrottlingCacheNode *)getHeadNode
{
    if ([self.head.nextRequestThumbprintKey isEqualToString:TAIL_NODE_KEY]) return nil;
    else return [self.internalCache objectForKey:self.head.nextRequestThumbprintKey];
}
- (MSIDThrottlingCacheNode *)getTailNode
{
    if ([self.tail.prevRequestThumbprintKey isEqualToString:HEAD_NODE_KEY]) return nil;
    else return [self.internalCache objectForKey:self.tail.prevRequestThumbprintKey];
}

- (NSArray *)enumerateAndReturnAllCachedObjects
{
    if ([self.head.nextRequestThumbprintKey isEqualToString:TAIL_NODE_KEY]) return nil;
    NSMutableArray *res = [NSMutableArray new];
    NSMutableString *key = [self.head.nextRequestThumbprintKey mutableCopy];
    
    while (![key isEqualToString:TAIL_NODE_KEY])
    {
        MSIDThrottlingCacheNode *node = [self.internalCache objectForKey:key];
        [key setString:node.nextRequestThumbprintKey];
        [res addObject:node];
    }
    
    return res;
}

@end
