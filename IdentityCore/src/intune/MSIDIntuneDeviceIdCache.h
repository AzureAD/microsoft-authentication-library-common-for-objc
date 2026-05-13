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
#import "MSIDExtendedTokenCacheDataSource.h"

@protocol MSIDRequestContext;

NS_ASSUME_NONNULL_BEGIN

/*!
 Cache for the Intune device id captured from the
 @c msauth://profile_download_complete redirect.

 The cached value is read back later when building the
 @c msauth://enroll request so it can be attached as a query parameter,
 and cleared once enrollment completes successfully.

 Persisted via the keychain data source provided at initialization (defaults
 to @c [MSIDKeychainTokenCache defaultKeychainCache] when created via
 @c +sharedCache).
 */
@interface MSIDIntuneDeviceIdCache : NSObject

@property (class, strong) MSIDIntuneDeviceIdCache *sharedCache;

- (instancetype)initWithDataSource:(id<MSIDExtendedTokenCacheDataSource>)dataSource;
- (instancetype _Nullable)init NS_UNAVAILABLE;
+ (instancetype _Nullable)new NS_UNAVAILABLE;

/*!
 Persist the Intune device id. Single-slot; overwrites any existing value.

 @param intuneDeviceId The device id string to persist. Must be non-empty.
 @param context        Optional request context used for logging/correlation.
 @param error          On failure, set to an NSError describing the problem.
 @return YES on success; NO on failure with @c error populated.
 */
- (BOOL)setIntuneDeviceId:(NSString *)intuneDeviceId
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError *_Nullable *_Nullable)error;

/*!
 @param context Optional request context used for logging/correlation.
 @param error   On failure, set to an NSError describing the problem.
 @return The cached Intune device id, or nil if none has been persisted or on error.
 */
- (nullable NSString *)intuneDeviceIdWithContext:(nullable id<MSIDRequestContext>)context
                                           error:(NSError *_Nullable *_Nullable)error;

/*!
 Removes the cached Intune device id. No-op when nothing is cached.
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
