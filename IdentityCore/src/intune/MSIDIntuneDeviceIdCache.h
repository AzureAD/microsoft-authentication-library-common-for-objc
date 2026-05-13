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

@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-memory cache that persists the Intune device identifier across the MDM
 * profile-installation redirect and the subsequent enrollment redirect within
 * the same app session.
 */
@interface MSIDIntuneDeviceIdCache : NSObject

/**
 * Shared singleton instance. Can be replaced in tests via +setSharedCache:.
 */
@property (class, strong) MSIDIntuneDeviceIdCache *sharedCache;

/**
 * Returns the cached Intune device identifier, or nil if none is stored.
 */
- (nullable NSString *)intuneDeviceIdWithContext:(nullable id<MSIDRequestContext>)context
                                           error:(NSError *__autoreleasing *)error;

/**
 * Stores the Intune device identifier in memory.
 * @return YES on success.
 */
- (BOOL)setIntuneDeviceId:(NSString *)deviceId
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError *__autoreleasing *)error;

/**
 * Removes the cached device identifier.
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
