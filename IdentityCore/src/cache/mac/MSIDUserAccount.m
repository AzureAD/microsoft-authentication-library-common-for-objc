//
//  MSIDUserAccount.m
//  IdentityCore Mac
//
//  Created by Rohit Narula on 5/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDUserAccount.h"

@implementation MSIDUserAccount

- (nullable id)initWithAccount:(nullable NSString *)account
                       service:(nullable NSString *)service
                       generic:(nullable NSData *)generic
                          type:(nullable NSNumber *)type
           credentialCacheItem:(MSIDCredentialCacheItem *)cacheItem
{
    self = [super init];
    if (self)
    {
        _acct = account;
        _svce = service;
        _gena = generic;
        _type = type;
        _cacheItem = cacheItem;
    }
    
    return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDUserAccount *)object];
}

- (BOOL)isEqualToItem:(MSIDUserAccount *)item
{
    BOOL result = YES;
    result &= (!self.acct && !item.acct) || [self.acct isEqualToString:item.acct];
    result &= (!self.svce && !item.svce) || [self.svce isEqualToString:item.svce];
    result &= (!self.gena && !item.gena) || [self.gena isEqualToData:item.gena];
    result &= (!self.type && !item.type) || [self.type isEqualToNumber:item.type];
    result &= (!self.cacheItem && !item.cacheItem) || [self.cacheItem isEqual:item.cacheItem];
    
    return result;
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.acct.hash;
    hash = hash * 31 + self.svce.hash;
    hash = hash * 31 + self.gena.hash;
    hash = hash * 31 + self.type.hash;
    hash = hash * 31 + self.cacheItem.hash;
    return hash;
}


@end
