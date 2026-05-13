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
#import "MSIDIntuneDeviceIdCache.h"
#import "MSIDCacheKey.h"
#import "MSIDConstants.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDJsonObject.h"
#import "MSIDRequestContext.h"
#import "NSDictionary+MSIDExtensions.h"

static NSString *const kIntuneDeviceIdJsonKey = @"intune_device_id";
static MSIDIntuneDeviceIdCache *s_sharedCache;

@interface MSIDIntuneDeviceIdCache()

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;

@end

@implementation MSIDIntuneDeviceIdCache

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDExtendedTokenCacheDataSource>)dataSource
{
    self = [super init];
    if (self)
    {
        _dataSource = dataSource;
    }
    return self;
}

#pragma mark - Shared instance

+ (void)setSharedCache:(MSIDIntuneDeviceIdCache *)cache
{
    @synchronized(self)
    {
        if (cache == nil) return;
        s_sharedCache = cache;
    }
}

+ (MSIDIntuneDeviceIdCache *)sharedCache
{
    @synchronized(self)
    {
        if (!s_sharedCache)
        {
            s_sharedCache = [[MSIDIntuneDeviceIdCache alloc] initWithDataSource:[MSIDKeychainTokenCache defaultKeychainCache]];
        }
        return s_sharedCache;
    }
}

#pragma mark - Public API

- (BOOL)setIntuneDeviceId:(NSString *)intuneDeviceId
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError *_Nullable *_Nullable)error
{
    if (!intuneDeviceId.length)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"intuneDeviceId must be a non-empty string.",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return NO;
    }

    if (!self.dataSource)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"No keychain data source available.",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return NO;
    }

    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc]
        initWithJSONDictionary:@{ kIntuneDeviceIdJsonKey : intuneDeviceId }
                         error:error];
    if (!jsonObject)
    {
        return NO;
    }

    return [self.dataSource saveJsonObject:jsonObject
                                serializer:[MSIDCacheItemJsonSerializer new]
                                       key:[self.class cacheKey]
                                   context:context
                                     error:error];
}

- (nullable NSString *)intuneDeviceIdWithContext:(nullable id<MSIDRequestContext>)context
                                           error:(NSError *_Nullable *_Nullable)error
{
    if (!self.dataSource) return nil;

    NSArray<MSIDJsonObject *> *jsonObjects = [self.dataSource jsonObjectsWithKey:[self.class cacheKey]
                                                                      serializer:[MSIDCacheItemJsonSerializer new]
                                                                         context:context
                                                                           error:error];
    if (!jsonObjects.count) return nil;

    NSDictionary *json = [jsonObjects.firstObject jsonDictionary];
    NSString *value = [json msidStringObjectForKey:kIntuneDeviceIdJsonKey];
    return value.length ? value : nil;
}

- (void)clear
{
    [self.dataSource removeTokensWithKey:[self.class cacheKey] context:nil error:nil];
}

#pragma mark - Private

+ (MSIDCacheKey *)cacheKey
{
    static MSIDCacheKey *cacheKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheKey = [[MSIDCacheKey alloc] initWithAccount:MSID_INTUNE_DEVICE_ID_KEYCHAIN
                                                 service:MSID_INTUNE_DEVICE_ID_KEYCHAIN_VERSION
                                                 generic:nil
                                                    type:nil];
    });
    return cacheKey;
}

@end
