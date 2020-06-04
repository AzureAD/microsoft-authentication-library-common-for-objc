//
//  MSIDAccessTokenWithAuthScheme.h
//  IdentityCore
//
//  Created by Rohit Narula on 6/3/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDAccessToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAccessTokenWithAuthScheme : MSIDAccessToken

@property (nonatomic) NSString *kid;

@end

NS_ASSUME_NONNULL_END
