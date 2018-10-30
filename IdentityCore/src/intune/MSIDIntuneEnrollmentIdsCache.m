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

#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneInMemmoryCacheDataSource.h"

NSString *const MSID_INTUNE_ENROLLMENT_ID_ARRAY = @"enrollment_ids";
NSString *const MSID_INTUNE_USER_ID = @"user_id";
NSString *const MSID_INTUNE_ENROLL_ID = @"enrollment_id";
NSString *const MSID_INTUNE_TID = @"tid";
NSString *const MSID_INTUNE_OID = @"oid";
NSString *const MSID_INTUNE_HOME_ACCOUNT_ID = @"home_account_id";

#define MSID_INTUNE_ENROLLMENT_ID @"intune_app_protection_enrollment_id_V"
#define MSID_INTUNE_ENROLLMENT_ID_VERSION @"1"
#define MSID_INTUNE_ENROLLMENT_ID_KEY (MSID_INTUNE_ENROLLMENT_ID MSID_INTUNE_ENROLLMENT_ID_VERSION)

static MSIDIntuneEnrollmentIdsCache *s_sharedCache;

@interface MSIDIntuneEnrollmentIdsCache()

@property (nonatomic) id<MSIDIntuneCacheDataSource> dataSource;

@end

@implementation MSIDIntuneEnrollmentIdsCache

- (instancetype)initWithDataSource:(id<MSIDIntuneCacheDataSource>)dataSource
{
    self = [super init];
    if (self)
    {
        _dataSource = dataSource;
    }
    return self;
}

+ (void)setSharedCache:(MSIDIntuneEnrollmentIdsCache *)cache
{
    @synchronized(self)
    {
        if (cache == nil) return;
        
        s_sharedCache = cache;
    }
}

+ (MSIDIntuneEnrollmentIdsCache *)sharedCache
{
    @synchronized(self)
    {
        if (!s_sharedCache)
        {
            s_sharedCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:[MSIDIntuneInMemmoryCacheDataSource new]];
        }
        
        return s_sharedCache;
    }
}

- (NSString *)enrollmentIdForUserId:(NSString *)userId
                              error:(NSError **)error
{
    NSDictionary *jsonDictionary = [self.dataSource jsonDictionaryForKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
    if (![self isValid:jsonDictionary error:error]) return nil;
    
    NSArray *enrollIds = [jsonDictionary objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if ([enrollIdDic[MSID_INTUNE_USER_ID] isEqualToString:userId])
        {
            return enrollIdDic[MSID_INTUNE_ENROLL_ID];
        }
    }
    
    return nil;
}

- (NSString *)enrollmentIdForUserObjectId:(NSString *)userObjectId
                                 tenantId:(NSString *)tenantId
                                    error:(NSError **)error
{
    if (!userObjectId || !tenantId) return nil;
    
    NSDictionary *jsonDictionary = [self.dataSource jsonDictionaryForKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
    if (![self isValid:jsonDictionary error:error]) return nil;
    
    NSArray *enrollIds = [jsonDictionary objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if ([enrollIdDic[MSID_INTUNE_OID] isEqualToString:userObjectId] &&
            [enrollIdDic[MSID_INTUNE_TID] isEqualToString:tenantId])
        {
            return enrollIdDic[MSID_INTUNE_ENROLL_ID];
        }
    }
    
    return nil;
}

- (NSString *)enrollmentIdForHomeAccountId:(NSString *)homeAccountId
                                     error:(NSError **)error
{
    NSDictionary *jsonDictionary = [self.dataSource jsonDictionaryForKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
    if (![self isValid:jsonDictionary error:error]) return nil;
    
    NSArray *enrollIds = [jsonDictionary objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if ([enrollIdDic[MSID_INTUNE_HOME_ACCOUNT_ID] isEqualToString:homeAccountId])
        {
            return enrollIdDic[MSID_INTUNE_ENROLL_ID];
        }
    }
    
    return nil;
}

- (NSString *)enrollmentIdForHomeAccountId:(NSString *)homeAccountId
                                    userId:(NSString *)userId
                                     error:(NSError **)error
{
    if (homeAccountId)
    {
        // If homeAccountID is provided, always require an exact match
        return [self enrollmentIdForUserId:homeAccountId error:error];
    }
    else
    {
        // If legacy userID is provided and we didn't find an exact match, do a fallback to any enrollment ID to support no userID or single userID scenarios
        NSString *enrollmentID = userId ? [self enrollmentIdForUserId:userId error:error] : nil;
        if (enrollmentID)
        {
            return enrollmentID;
        }
        
        enrollmentID = [self enrollmentIdIfAvailable:error];
        return enrollmentID;
    }
}

- (NSString *)enrollmentIdIfAvailable:(NSError **)error
{
    NSDictionary *jsonDictionary = [self.dataSource jsonDictionaryForKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
    if (![self isValid:jsonDictionary error:error]) return nil;
    
    NSArray *enrollIds = [jsonDictionary objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    NSDictionary *enrollIdDic = enrollIds.firstObject;
    
    return enrollIdDic[MSID_INTUNE_ENROLL_ID];
}

- (void)setEnrollmentIdsJsonDictionary:(NSDictionary *)jsonDictionary
                                 error:(NSError **)error
{
    if (![self isValid:jsonDictionary error:error]) return;
    
    [self.dataSource setJsonDictionary:jsonDictionary forKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
}

- (NSDictionary *)enrollmentIdsJsonDictionary:(NSError **)error
{
    __auto_type jsonDictionary = [self.dataSource jsonDictionaryForKey:MSID_INTUNE_ENROLLMENT_ID_KEY];
    if (![self isValid:jsonDictionary error:error]) return nil;
    
    return jsonDictionary;
}

#pragma mark - Private

- (BOOL)isValid:(NSDictionary *)json error:(NSError **)error
{
    NSString *errorDescription = @"Intune Enrollment ID JSON structure is incorrect.";
    __auto_type validationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil);
    
    if (!json) return YES;
    
    if (![json isKindOfClass:NSDictionary.class])
    {
        if (error) *error = validationError;
        return NO;
    }
    
    NSArray *enrollIds = json[MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    
    if (![enrollIds isKindOfClass:NSArray.class])
    {
        if (error) *error = validationError;
        return NO;
    }
    
    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if (![enrollIdDic isKindOfClass:NSDictionary.class])
        {
            if (error) *error = validationError;
            return NO;
        }
        
        NSString *enrollId = enrollIdDic[MSID_INTUNE_ENROLL_ID];
        if (enrollId)
        {
            if (![enrollId isKindOfClass:NSString.class])
            {
                if (error) *error = validationError;
                return NO;
            }
        }
    }
    
    return YES;
}

@end
