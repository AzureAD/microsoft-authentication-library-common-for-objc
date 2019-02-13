//
//  MSIDKeychainTokenCache+Internal.h
//  IdentityCore
//
//  Created by Serhii Demchenko on 2019-02-12.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDKeychainTokenCache.h"

@interface MSIDKeychainTokenCache (Internal)

- (NSString *)keychainGroupLoggingName;

- (NSMutableArray<MSIDCredentialCacheItem *> *)filterTokenItemsFromKeychainItems:(NSArray *)items
                                                                      serializer:(id<MSIDCredentialItemSerializer>)serializer
                                                                         context:(id<MSIDRequestContext>)context;

- (MSIDCacheKey *)overrideTokenKey:(MSIDCacheKey *)key;

- (NSString *)extractAppKey:(NSString *)cacheKeyString;

@end
