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
#import "MSIDThumbprintCalculatable.h"
#import "MSIDThrottlingCacheRecord.h"
#import "NSError+MSIDThrottlingExtension.h"
#import "MSIDRequestContext.h"
#import "MSIDLRUCache.h"
typedef NS_ENUM(NSInteger, MSIDThrottlingType)
{
    MSIDThrottlingTypeNone = 0,
    MSIDThrottlingType429 = 1,
    MSIDThrottlingTypeInteractiveRequired = 2
};

typedef NS_ENUM(NSInteger, MSIDThrottlingThumbprintType)
{
    MSIDThrottlingThumbprintTypeStrict = 0,
    MSIDThrottlingThumbprintTypeFull = 1
};

NS_ASSUME_NONNULL_BEGIN
@interface MSIDThrottlingModelBase : NSObject

@property NSString *thumbprintValue;
@property MSIDThrottlingThumbprintType thumbprintType;
@property NSInteger throttleDuration;
@property id<MSIDThumbprintCalculatable> request;
@property NSError *errorResponse;
@property MSIDThrottlingCacheRecord *cacheRecord;
@property NSString *accessGroup;
@property id<MSIDRequestContext> context;

- (instancetype) initWithRequest:(id<MSIDThumbprintCalculatable> _Nonnull)request
                     cacheRecord:(MSIDThrottlingCacheRecord * _Nullable)cacheRecord
                   errorResponse:(NSError *)errorResponse
                     accessGroup:(NSString *)accessGroup;

+ (BOOL)isApplicableForTheThrottleModel:(NSError *)errorResponse;
- (BOOL)shouldThrottleRequest;
- (MSIDLRUCache *)cacheService;
- (void)updateServerTelemetry;
- (void)cleanCacheRecordFromDB;
- (void)insertOrUpdateCacheRecordToDB:(MSIDThrottlingCacheRecord *)cacheRecord;
- (MSIDThrottlingCacheRecord *)prepareCacheRecord;

@end
NS_ASSUME_NONNULL_END
