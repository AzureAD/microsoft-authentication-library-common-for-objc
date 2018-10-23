//
//  MSIDIntuenEnrollmentCache.m
//  IdentityCore iOS
//
//  Created by Sergey Demchenko on 10/23/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDAuthority.h"

static MSIDIntuneMAMResourcesCache *s_sharedCache;

@interface MSIDIntuneMAMResourcesCache()

@property (nonatomic) MSIDCache *cache;

@end

@implementation MSIDIntuneMAMResourcesCache

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _cache = [MSIDCache new];
    }
    return self;
}

+ (void)setSharedCache:(MSIDIntuneMAMResourcesCache *)cache
{
    @synchronized(self)
    {
        if (cache == nil) return;
        
        s_sharedCache = cache;
    }
}

+ (MSIDIntuneMAMResourcesCache *)sharedCache
{
    @synchronized(self)
    {
        if (!s_sharedCache)
        {
            s_sharedCache = [MSIDIntuneMAMResourcesCache new];
        }
        
        return s_sharedCache;
    }
}

- (NSString *)resourceForAuthority:(MSIDAuthority *)authority
{
    __auto_type aliases = [authority defaultCacheEnvironmentAliases];
    
    for (NSString *environment in aliases)
    {
         NSString *resource = [self.cache objectForKey:environment];
        
        if (resource) return resource;
    }
    
    return nil;
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
    
    for (id key in [json allKeys])
    {
        if (![key isKindOfClass:NSString.class])
        {
            if (error) *error = validationError;
            return NO;
        }
    }
    
    for (id value in [json allValues])
    {
        if (![value isKindOfClass:NSString.class])
        {
            if (error) *error = validationError;
            return NO;
        }
    }
    
    return YES;
}

@end
