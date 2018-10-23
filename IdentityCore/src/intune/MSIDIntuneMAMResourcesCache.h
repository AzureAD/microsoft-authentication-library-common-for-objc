//
//  MSIDIntuenEnrollmentCache.h
//  IdentityCore iOS
//
//  Created by Sergey Demchenko on 10/23/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDCache.h"
#import "MSIDJsonSerializable.h"

@class MSIDAuthority;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDIntuneMAMResourcesCache : NSObject <MSIDJsonSerializable>

@property (class, strong) MSIDIntuneMAMResourcesCache *sharedCache;

/*! Returns the Intune MAM resource for the associated authority*/
- (NSString *)resourceForAuthority:(MSIDAuthority *)authority;

@end

NS_ASSUME_NONNULL_END
