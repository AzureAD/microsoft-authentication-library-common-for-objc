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

//singleton instances of MSIDServerDelayCache & MSIDUIRequiredCache will be in the implementation file as private properties.
//Additionally, there will be dummy head and tail node in the .m file to maintain pseudo doubly-linked-list so we can better handle all corner cases.
@interface MSIDThrottlingCacheAccessor : NSObject

//Will implement getters in the .m file. 
@property (nonatomic, readonly) NSDate *lastCleanUpTimeForUICache;
@property (nonatomic, readonly) NSDate *lastCleanUpTimeForServerDelayCache;

- (instancetype)initializeThrottlingCacheAccessor;

//add new node to the front of LRU cache.
//if node already exists, update and move it to the front of LRU cache
- (void)addRequestToUICache:(NSString *)thumbprintKey
              errorResponse:(NSError *)errrorResponse;


- (void)removeRequestFromUICache:(NSString *)thumbprintKey;

//retrieve cache record from the corresponding node, and move the node to the front of LRU cache.
- (MSIDThrottlingCacheRecord *)getCachedResponseFromUICache:(NSString *)thumbprintKey;

- (void)addRequestToServerDelayCache:(NSString *)thumbprintKey
                       errorResponse:(NSError *)errrorResponse;

- (void)removeRequestFromServerDelayCache:(NSString *)thumbprintKey;

- (MSIDThrottlingCacheRecord *)getCachedResponseFromServerDelayCache:(NSString *)thumbprintKey;

@end
