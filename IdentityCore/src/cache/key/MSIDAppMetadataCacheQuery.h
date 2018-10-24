//
//  MSIDAppMetadataCacheQuery.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 10/23/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDAppMetadataCacheKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAppMetadataCacheQuery : MSIDAppMetadataCacheKey

@property (nonatomic, readonly) BOOL exactMatch;
@property (nonatomic) NSArray<NSString *> *environmentAliases;

@end

NS_ASSUME_NONNULL_END
