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

NS_ASSUME_NONNULL_BEGIN

@interface MSIDLRUCache <KeyType, ObjectType>: NSObject

@property (nonatomic, readonly) NSUInteger cacheSize; //size of the LRU cache
@property (nonatomic, readonly) NSUInteger numCacheRecords; //number of valid records currently stored in the LRU cache
@property (nonatomic, readonly) NSUInteger cacheUpdateCount; //number of times cache entries have been updated
@property (nonatomic, readonly) NSUInteger cacheEvictionCount; //number of times cache entries have been evicted

- (instancetype)initWithCacheSize:(NSUInteger)cacheSize;

+ (MSIDLRUCache *)sharedInstance;

/**
add new node to the front of LRU cache.
if node already exists, update and move it to the front of LRU cache
 */
- (BOOL)setObject:(ObjectType)cacheRecord
           forKey:(KeyType)key
            error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeObjectForKey:(KeyType)key
                     error:(NSError * _Nullable * _Nullable)error;

/**
 retrieve cache object corresponding to the input key, and move the object to the front of LRU cache.
 */
- (nullable ObjectType)objectForKey:(KeyType)key
                              error:(NSError * _Nullable * _Nullable)error;

/**
 return all cached elements sorted from most recently used (first) to least recently used (last)
*/

- (nullable NSArray<ObjectType> *)enumerateAndReturnAllObjects;

/**
 clear all objects in cache
 */
- (BOOL)removeAllObjects:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
