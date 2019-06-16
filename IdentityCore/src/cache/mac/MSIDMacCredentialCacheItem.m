//
//  MSIDMacCredentialCacheItem.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 6/14/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDMacCredentialCacheItem.h"

static NSString *keyDelimiter = @"-";

@interface MSIDMacCredentialCacheItem ()

@property (nonatomic) NSMutableDictionary *cacheObjects;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MSIDMacCredentialCacheItem

- (instancetype)init
{
    if(self = [super init])
    {
        self.cacheObjects = [NSMutableDictionary dictionary];
        self.queue = dispatch_queue_create("com.microsoft.universalStorage", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (void)setCredential:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects setObject:token forKey:key];
    });
}

-(MSIDCredentialCacheItem *)credentialForKey:(MSIDDefaultCredentialCacheKey *)key
{
    __block MSIDCredentialCacheItem *appCredential = nil;
    
    dispatch_sync(self.queue, ^{
        appCredential = [self.cacheObjects objectForKey:key];
    });
    
    return appCredential;
}

- (void)removeCredentialForKey:(MSIDDefaultCredentialCacheKey *)key
{
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects removeObjectForKey:key];
    });
}

- (void)mergeCredential:(MSIDMacCredentialCacheItem *)credential
{
    NSDictionary *copy = [credential getCopy];
    
    dispatch_barrier_async(self.queue, ^{
        [self.cacheObjects addEntriesFromDictionary:copy];
    });
}

- (NSArray<MSIDCredentialCacheItem *> *)credentialsWithKey:(MSIDDefaultCredentialCacheKey *)key
{
    if (key.account && key.service)
    {
        MSIDCredentialCacheItem *credential = [self credentialForKey:key];
        if (credential)
        {
            return @[credential];
        }
        
        return nil;
    }
    
    NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
    
    if (key.clientId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.clientId == %@", key.clientId]];
    if (key.familyId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.clientId == %@", key.familyId]];
    if (key.environment)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.environment == %@", key.environment]];
    if (key.homeAccountId)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.homeAccountId == %@", key.homeAccountId]];
    if (key.credentialType)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.credentialType == %d", key.credentialType]];
    if (key.target)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.target == %@", key.target]];
    if (key.realm)
        [subPredicates addObject:[NSPredicate predicateWithFormat:@"self.realm == %@", key.realm]];
    
    // Combine all sub-predicates with AND:
    NSPredicate *matchAttributes = [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
    
    NSDictionary *cacheObjects = [self getCopy];
    return [[cacheObjects allValues] filteredArrayUsingPredicate:matchAttributes];
}

- (NSDictionary *)getCopy
{
    __block NSMutableDictionary *copy;
    
    dispatch_sync(self.queue, ^{
        copy = [self.cacheObjects mutableDeepCopy];
    });
    
    return copy;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [self init]))
    {
        return nil;
    }
    
    for (NSString *tokenKey in json)
    {
        NSDictionary *rtDict = [json objectForKey:tokenKey];
        
        if (rtDict)
        {
            MSIDCredentialCacheItem *appToken = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:rtDict error:error];
            
            if (appToken)
            {
                MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:appToken.homeAccountId                      environment:appToken.environment clientId:appToken.clientId credentialType:appToken.credentialType];
                
                key.familyId = appToken.familyId;
                key.realm = appToken.realm;
                key.target = appToken.target;
                key.enrollmentId = appToken.enrollmentId;
                
                [self setCredential:appToken forKey:key];
            }
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSDictionary *cacheObjects = [self getCopy];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (MSIDDefaultCredentialCacheKey *appTokenKey in cacheObjects)
    {
        NSString *key = [NSString stringWithFormat:@"%@%@%@", appTokenKey.account, keyDelimiter, appTokenKey.service];
        MSIDCredentialCacheItem *appToken = [cacheObjects objectForKey:appTokenKey];
        NSDictionary *atDict = [appToken jsonDictionary];
        
        if (atDict)
        {
            [dictionary setObject:atDict forKey:key];
        }
    }
    
    return dictionary;
}

@end
