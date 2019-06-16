//
//  MSIDMacCredentialCacheItem.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 6/14/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDCredentialCacheItem.h"
#import "MSIDDefaultCredentialCacheKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDMacCredentialCacheItem : NSObject <MSIDJsonSerializable>

- (void)setCredential:(MSIDCredentialCacheItem *)token forKey:(MSIDDefaultCredentialCacheKey *)key;

- (void)mergeCredential:(MSIDMacCredentialCacheItem *)credential;

- (NSArray<MSIDCredentialCacheItem *> *)credentialsWithKey:(MSIDDefaultCredentialCacheKey *)key;

- (void)removeCredentialForKey:(MSIDDefaultCredentialCacheKey *)key;

@end

NS_ASSUME_NONNULL_END
