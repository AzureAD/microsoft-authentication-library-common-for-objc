//
//  MSIDAccessTokenWithAuthScheme.m
//  IdentityCore
//
//  Created by Rohit Narula on 6/3/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDAccessTokenWithAuthScheme.h"

@implementation MSIDAccessTokenWithAuthScheme

#pragma mark - Token type

- (MSIDCredentialType)credentialType
{
    return MSIDAccessTokenWithAuthSchemeType;
}

- (MSIDCredentialCacheItem *)tokenCacheItem
{
    MSIDCredentialCacheItem *cacheItem = [super tokenCacheItem];
    cacheItem.tokenType = self.tokenType;
    return cacheItem;
}

@end
