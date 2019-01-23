//
//  MSIDAccountCacheItem+MSIDAccountMatchers.h
//  IdentityCore
//
//  Created by Valentin on 1/22/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDAccountCacheItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAccountCacheItem (MSIDAccountMatchers)

- (BOOL)matchesWithHomeAccountId:(nullable NSString *)homeAccountId
                     environment:(nullable NSString *)environment
              environmentAliases:(nullable NSArray<NSString *> *)environmentAliases;

@end

NS_ASSUME_NONNULL_END
