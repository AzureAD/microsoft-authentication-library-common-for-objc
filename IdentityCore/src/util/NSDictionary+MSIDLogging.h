//
//  NSDictionary+MSIDLogging.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 3/11/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (MSIDLogging)

- (nullable NSDictionary *)maskedRequestDictionary;

@end

NS_ASSUME_NONNULL_END
