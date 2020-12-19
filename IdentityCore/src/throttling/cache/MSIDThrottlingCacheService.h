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

@class MSIDThrottlingCacheRecord;
@class MSIDThrottlingCacheNode;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDThrottlingCacheService : NSObject

@property (nonatomic, readonly) NSUInteger cacheSize;

- (instancetype)initThrottlingCacheService:(NSUInteger)cacheSize;

/* add new node to the front of LRU cache.
if node already exists, update and move it to the front of LRU cache */
- (NSError *)addRequestToCache:(NSString *)thumbprintKey
                 errorResponse:(nullable NSError *)errorResponse
                  throttleType:(NSString *)throttleType
              throttleDuration:(NSInteger)throttleDuration;

- (void)removeRequestFromCache:(NSString *)thumbprintKey;

//retrieve cache record from the corresponding node, and move the node to the front of LRU cache.
- (MSIDThrottlingCacheRecord *)getResponseFromCache:(NSString *)thumbprintKey;

- (MSIDThrottlingCacheNode *)getHeadNode; //query first element without disturbing order

- (MSIDThrottlingCacheNode *)getTailNode; //query last element without disturbing order

- (NSArray *)enumerateAndReturnAllCachedObjects; //return all cached elements without disturbing order 

@end

NS_ASSUME_NONNULL_END
