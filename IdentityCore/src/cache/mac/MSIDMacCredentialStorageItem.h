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
#import "MSIDCredentialCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDDefaultCredentialCacheKey.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDAppMetadataCacheKey.h"
#import "MSIDAccountMetadataCacheKey.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAccountMetadataCacheItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDMacCredentialStorageItem : NSObject <MSIDJsonSerializable>

- (void)storeItem:(id<MSIDJsonSerializable>)item forKey:(MSIDCacheKey *)key;

/*
 This api is thread safe only if an immutable object is passed as parameter.
 */
- (void)mergeStorageItem:(MSIDMacCredentialStorageItem *)storageItem;

- (NSArray<id<MSIDJsonSerializable>> *)storedItemsForKey:(MSIDCacheKey *)key;

- (void)removeStoredItemForKey:(MSIDCacheKey *)key;

- (NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
