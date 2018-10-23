//
//  MSIDIntuneEnrollmentIdsCache.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 10/24/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDCache.h"

NSString *const MSID_INTUNE_ENROLLMENT_ID_ARRAY = @"enrollment_ids";
NSString *const MSID_INTUNE_USER_ID = @"user_id";
NSString *const MSID_INTUNE_ENROLL_ID = @"enrollment_id";
NSString *const MSID_INTUNE_TID = @"tid";
NSString *const MSID_INTUNE_OID = @"oid";
NSString *const MSID_INTUNE_HOME_ACCOUNT_ID = @"home_account_id";

static MSIDIntuneEnrollmentIdsCache *s_sharedCache;

@interface MSIDIntuneEnrollmentIdsCache()

@property (nonatomic) MSIDCache *cache;

@end

@implementation MSIDIntuneEnrollmentIdsCache

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _cache = [MSIDCache new];
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
            s_sharedCache = [MSIDIntuneEnrollmentIdsCache new];
        }
        
        return s_sharedCache;
    }
}

- (NSString *)enrollmentIdForUserId:(NSString *)userId
{
    NSArray *enrollIds = [self.cache objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];

    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if ([enrollIdDic[MSID_INTUNE_USER_ID] isEqualToString:userId])
        {
            return enrollIdDic[MSID_INTUNE_ENROLL_ID];
        }
    }
    
    return nil;
}

- (NSString *)enrollmentIdForUserObjectId:(NSString *)userObjectId tenantId:(NSString *)tenantId
{
    NSArray *enrollIds = [self.cache objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    
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
{
    NSArray *enrollIds = [self.cache objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    
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
{
    if (homeAccountId)
    {
        // If homeAccountID is provided, always require an exact match
        return [self enrollmentIdForUserId:homeAccountId];
    }
    else
    {
        // If legacy userID is provided and we didn't find an exact match, do a fallback to any enrollment ID to support no userID or single userID scenarios
        NSString *enrollmentID = userId ? [self enrollmentIdForUserId:userId] : nil;
        if (enrollmentID)
        {
            return enrollmentID;
        }
        
        enrollmentID = [self enrollmentIdIfAvailable];
        return enrollmentID;
    }
}

- (NSString *)enrollmentIdIfAvailable
{
    NSArray *enrollIds = [self.cache objectForKey:MSID_INTUNE_ENROLLMENT_ID_ARRAY];
    
    return enrollIds.firstObject;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        NSError *validationError;
        if (![self isValid:json error:&validationError])
        {
            MSID_LOG_ERROR(nil, @"%@", validationError);
            // TODO: should we log json object?
            // MSID_LOG_ERROR_PII(nil, @"%@ - JSON: %@", validationError, json);
            
            if (error) *error = validationError;
            return nil;
        }
        
        _cache = [[MSIDCache alloc] initWithDictionary:json];
    }
    return self;
}

- (NSDictionary *)jsonDictionary
{
    return [self.cache toDictionary];
}

#pragma mark - Private

- (BOOL)isValid:(NSDictionary *)json error:(NSError **)error
{
    NSString *errorDescription = @"Intune Resource JSON structure is incorrect.";
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
    
    // TODO: Should we check only for specific keys and ignore keys that we don't use?
    for (NSDictionary *enrollIdDic in enrollIds)
    {
        if (![enrollIdDic isKindOfClass:NSDictionary.class])
        {
            if (error) *error = validationError;
            return NO;
        }
        
        for (id key in [enrollIdDic allKeys])
        {
            if (![key isKindOfClass:NSString.class])
            {
                if (error) *error = validationError;
                return NO;
            }
        }
        
        for (id value in [enrollIdDic allValues])
        {
            if (![value isKindOfClass:NSString.class])
            {
                if (error) *error = validationError;
                return NO;
            }
        }
    }
    
    return YES;
}

@end
