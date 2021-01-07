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
#import "MSIDLRUCache.h"
#import "MSIDLRUCacheNode.h"

static NSString *const HEAD_SIGNATURE = @"HEAD";
static NSString *const TAIL_SIGNATURE = @"TAIL";

#define DEFAULT_CACHE_SIZE 1000
#define DEFAULT_SIGNATURE_LENGTH 8

@interface MSIDLRUCache ()

@property (nonatomic) NSUInteger cacheSizeInt;
@property (nonatomic) NSUInteger cacheUpdateCountInt;
@property (nonatomic) MSIDLRUCacheNode *head;
@property (nonatomic) MSIDLRUCacheNode *tail;
@property (nonatomic) NSMutableDictionary *container;
@property (nonatomic) NSMutableDictionary *key_signature_map;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDLRUCache

- (NSUInteger)cacheSize
{
    return self.cacheSizeInt-2;
}

- (NSUInteger)numCacheRecords
{
    return self.container.allKeys.count-2;
}

- (NSUInteger)cacheUpdateCount
{
    return self.cacheUpdateCountInt;
}

- (instancetype)initWithCacheSize:(NSUInteger)cacheSize
{
    self = [super init];
    if (self)
    {
        _cacheSizeInt = cacheSize+2;
        _cacheUpdateCountInt = 0;
        //create dummy head and tail
        _head = [[MSIDLRUCacheNode alloc] initWithSignature:HEAD_SIGNATURE
                                              prevSignature:nil
                                              nextSignature:TAIL_SIGNATURE
                                                    cacheRecord:nil];
        
        _tail = [[MSIDLRUCacheNode alloc] initWithSignature:TAIL_SIGNATURE
                                              prevSignature:HEAD_SIGNATURE
                                              nextSignature:nil
                                                cacheRecord:nil];
        
        //create concurrent queue and container dictionary
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidlrucache-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        _container = [NSMutableDictionary new];
        _key_signature_map = [NSMutableDictionary new];
        
        [self.container setObject:_head forKey:HEAD_SIGNATURE];
        [self.container setObject:_tail forKey:TAIL_SIGNATURE];
    }
    return self;
}

+ (MSIDLRUCache *)sharedInstance
{
    static MSIDLRUCache *m_service;
    static dispatch_once_t once_token;
    
    dispatch_once(&once_token, ^{
        m_service = [[MSIDLRUCache alloc] initWithCacheSize:DEFAULT_CACHE_SIZE];
    });
    
    return m_service;
}

/* add new node to the front of LRU cache.
if node already exists, update and move it to the front of LRU cache */
- (BOOL)addToCache:(id)key
       cacheRecord:(id)cacheRecord
             error:(NSError *__nullable*__nullable)error
{
    __block NSError *subError = nil;
    BOOL result = YES;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        if (self.cacheSizeInt <= 2)
        {
            subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDLRUCache Error: Attempting to write to an empty cache!", nil, nil, nil, nil, nil, YES);
        }
        
        else
        {
            //node already exists - simply move it to front
            if ([self.key_signature_map objectForKey:key])
            {
                [self updateAndReturnCacheRecordImpl:[self.key_signature_map objectForKey:key]
                                               error:&subError];
                self.cacheUpdateCountInt++;
            }
            
            else
            {
                //if cache is full, invalidate least recently used entry
                if (self.container.allKeys.count >= self.cacheSizeInt)
                {
                    NSString *leastRecentlyUsed = self.tail.prevSignature;
                    [self removeFromCacheImpl:leastRecentlyUsed
                                        error:&subError];
                }
                NSString *signature = [self mapKeyToSignature:key];
                MSIDLRUCacheNode *newNode = [[MSIDLRUCacheNode alloc] initWithSignature:signature
                                                                          prevSignature:nil
                                                                          nextSignature:nil
                                                                            cacheRecord:cacheRecord];
                [self addToFrontImpl:newNode];
            }
        }
    });
    
    if (subError)
    {
        result = NO;
    }
    
    if (error)
    {
        *error = subError;
    }
    return result;
}


- (BOOL)removeFromCache:(id)key
                  error:(NSError **)error
{
    __block NSError *subError = nil;
    BOOL result = YES;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        if (![self.key_signature_map objectForKey:key])
        {
            subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDLRUCache Error: Unable to find valid signature for the input key during removal", nil, nil, nil, nil, nil, YES);
        }
        
        else
        {
            NSString *signature = [self.key_signature_map objectForKey:key];
            [self.key_signature_map removeObjectForKey:key];
            [self removeFromCacheImpl:signature
                                error:&subError];
        }
    });
    
    if (subError)
    {
        result = NO;
    }
    
    if (error)
    {
        *error = subError;
    }
    return result;
}

- (BOOL)removeFromCacheImpl:(NSString *)signature
                      error:(NSError **)error
{
    if (![self.container objectForKey:signature])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDLRUCache Error: Unable to find valid node for the input signature during removal", nil, nil, nil, nil, nil, YES);
        }
        return NO;
    }
    
    MSIDLRUCacheNode *node = [self.container objectForKey:signature];
    MSIDLRUCacheNode *prevNode = [self.container objectForKey:node.prevSignature];
    MSIDLRUCacheNode *nextNode = [self.container objectForKey:node.nextSignature];

    prevNode.nextSignature = node.nextSignature;
    nextNode.prevSignature = node.prevSignature;

    [self.container setObject:prevNode forKey:node.prevSignature];
    [self.container setObject:nextNode forKey:node.nextSignature];
    
    [self.container removeObjectForKey:signature];
    return YES;
}

//retrieve cache record from the corresponding node, and move the node to the front of LRU cache.
- (id)updateAndReturnCacheRecord:(id)key
                           error:(NSError **)error
{
    __block id cacheRecord;
    __block NSError *subError = nil;
    
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self.key_signature_map objectForKey:key])
        {
            subError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDLRUCache Error: Unable to find valid signature for the input key during retrieval", nil, nil, nil, nil, nil, YES);
        }
        
        cacheRecord = [self updateAndReturnCacheRecordImpl:[self.key_signature_map objectForKey:key]
                                                     error:&subError];
    });
    if (subError)
    {
        cacheRecord = nil;
    }
    
    if (error)
    {
        *error = subError;
    }

    return cacheRecord;
}

- (id)updateAndReturnCacheRecordImpl:(NSString *)signature
                               error:(NSError **)error
{
    if (![self.container objectForKey:signature])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"MSIDLRUCache Error: Unable to find valid node for the input signature during retrieval", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }
    
    //retrieve node
    MSIDLRUCacheNode *node = [self.container objectForKey:signature];
    
    //remove from current cache slot
    [self removeFromCacheImpl:signature
                        error:error];
    //move to front
    [self addToFrontImpl:node];
    
    return node.cacheRecord;
}

- (void)addToFront:(MSIDLRUCacheNode *)node
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        [self addToFrontImpl:node];
    });
}

- (void)addToFrontImpl:(MSIDLRUCacheNode *)node
{
    NSString *currentHeadSignature = self.head.nextSignature; //node currently pointed by the head
    MSIDLRUCacheNode *currentHeadNode = [self.container objectForKey:currentHeadSignature];
    
    /**
    BEFORE:
     A->B->C
     A<-B<-C
    AFTER:
     A->C
     A<-C
     */
    currentHeadNode.prevSignature = [node.signature mutableCopy];
    node.prevSignature = [HEAD_SIGNATURE mutableCopy];
    node.nextSignature = [currentHeadSignature mutableCopy];
    self.head.nextSignature = [node.signature mutableCopy];
    
    [self.container setObject:currentHeadNode forKey:currentHeadSignature];
    [self.container setObject:node forKey:node.signature];
}

- (MSIDLRUCacheNode *)getHeadNode
{
    __block MSIDLRUCacheNode *node;
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self.head.nextSignature isEqualToString:TAIL_SIGNATURE])
        {
            node = [self.container objectForKey:self.head.nextSignature];
        }
    });
    return node;
    
}

- (MSIDLRUCacheNode *)getTailNode
{
    __block MSIDLRUCacheNode *node;
    dispatch_sync(self.synchronizationQueue, ^{
        if (![self.tail.prevSignature isEqualToString:HEAD_SIGNATURE])
        {
            node = [self.container objectForKey:self.tail.prevSignature];
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
    if (![self.head.nextSignature isEqualToString:TAIL_SIGNATURE])
    {
        res = [NSMutableArray new];
        NSMutableString *signature = [self.head.nextSignature mutableCopy];
        
        while (![signature isEqualToString:TAIL_SIGNATURE])
        {
            MSIDLRUCacheNode *node = [self.container objectForKey:signature];
            [signature setString:node.nextSignature];
            [res addObject:node.cacheRecord];
        }
    }
    return res;
}

- (NSMutableArray *)enumerateAndReturnAllNodesImpl
{
    NSMutableArray *res;
    if (![self.head.nextSignature isEqualToString:TAIL_SIGNATURE])
    {
        res = [NSMutableArray new];
        NSMutableString *signature = [self.head.nextSignature mutableCopy];
        
        while (![signature isEqualToString:TAIL_SIGNATURE])
        {
            MSIDLRUCacheNode *node = [self.container objectForKey:signature];
            [signature setString:node.nextSignature];
            [res addObject:node];
        }
    }
    return res;
}

- (NSString *)generateRandomSignature //mock pointer 62^8 ~ 2^14 randomness
{
    NSString *validLetters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:DEFAULT_SIGNATURE_LENGTH];

    for (int i=0; i< DEFAULT_SIGNATURE_LENGTH; i++)
    {
        [randomString appendFormat:@"%C", [validLetters characterAtIndex:arc4random_uniform((int)[validLetters length])]];
    }
    return randomString;
}

- (NSString *)mapKeyToSignature:(id)key
{
    NSString *signature = [self generateRandomSignature];
    [self.key_signature_map setObject:signature forKey:key];
    return signature;
}



@end
