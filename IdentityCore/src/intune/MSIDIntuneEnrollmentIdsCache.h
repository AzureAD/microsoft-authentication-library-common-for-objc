//
//  MSIDIntuneEnrollmentIdsCache.h
//  IdentityCore
//
//  Created by Sergey Demchenko on 10/24/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDJsonSerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDIntuneEnrollmentIdsCache : NSObject <MSIDJsonSerializable>

@property (class, strong) MSIDIntuneEnrollmentIdsCache *sharedCache;

- (NSString *)enrollmentIdForUserId:(NSString *)userId;

- (NSString *)enrollmentIdForUserObjectId:(NSString *)userObjectId
                                 tenantId:(NSString *)tenantId;

- (NSString *)enrollmentIdForHomeAccountId:(NSString *)homeAccountId;

/*!
 Tries to find an enrollmentID for a homeAccountId first,
 then checks userId, then returns any enrollmentID available.
 */
- (NSString *)enrollmentIdForHomeAccountId:(NSString *)homeAccountId
                                    userId:(NSString *)userId;

/*!
 Returns the first available enrollmentID if one is available.
 */
- (NSString *)enrollmentIdIfAvailable;

@end

NS_ASSUME_NONNULL_END
