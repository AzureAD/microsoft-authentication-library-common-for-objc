//
//  MSIDMacLegacyCachePersistenceHandler.h
//  IdentityCore Mac
//
//  Created by Olga Dalton on 10/26/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDMacACLKeychainAccessor.h"
#import "MSIDMacTokenCache.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDMacLegacyCachePersistenceHandler : MSIDMacACLKeychainAccessor <MSIDMacTokenCacheDelegate>

- (nullable instancetype)initWithTrustedApplications:(nullable NSArray *)trustedApplications
                                         accessLabel:(nonnull NSString *)accessLabel
                                          attributes:(nonnull NSDictionary *)attributes
                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
