//
//  MSIDSharedAccount.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 5/3/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDCredentialCacheItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDSharedAccount : NSObject

@property (nonatomic, strong) NSString *accountIdentifier;
@property NSMutableDictionary<NSString *,MSIDCredentialCacheItem *> *refreshTokens;

@end

NS_ASSUME_NONNULL_END
