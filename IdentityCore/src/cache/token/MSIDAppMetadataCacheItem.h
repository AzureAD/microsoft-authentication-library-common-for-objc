//
//  MSIDAppMetadataCacheItem.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 10/8/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDJsonSerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAppMetadataCacheItem : NSObject <NSCopying, MSIDJsonSerializable>

@property (readwrite, nonnull) NSString *clientId;
@property (readwrite, nonnull) NSString *environment;
@property (readwrite, nullable) NSString *familyId;

@end

NS_ASSUME_NONNULL_END
