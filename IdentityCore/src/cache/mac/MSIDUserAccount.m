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

@end
