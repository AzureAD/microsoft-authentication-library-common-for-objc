//
//  MSIDAccountCacheItem+MSIDAccountMatchers.m
//  IdentityCore
//
//  Created by Valentin on 1/22/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDAccountCacheItem+MSIDAccountMatchers.h"

@implementation MSIDAccountCacheItem (MSIDAccountMatchers)

#pragma mark - Query

- (BOOL)matchesWithHomeAccountId:(nullable NSString *)homeAccountId
                     environment:(nullable NSString *)environment
              environmentAliases:(nullable NSArray<NSString *> *)environmentAliases
{
    if (homeAccountId && ![self.homeAccountId isEqualToString:homeAccountId])
    {
        return NO;
    }
    
    if (environment && ![self.environment isEqualToString:environment])
    {
        return NO;
    }
    
    if ([environmentAliases count] && ![self.environment msidIsEquivalentWithAnyAlias:environmentAliases])
    {
        return NO;
    }
    
    return YES;
}

@end
