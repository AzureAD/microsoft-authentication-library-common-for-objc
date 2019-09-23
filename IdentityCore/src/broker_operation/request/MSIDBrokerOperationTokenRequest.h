//
//  MSIDBrokerOperationTokenRequest.h
//  IdentityCore iOS
//
//  Created by Serhii Demchenko on 2019-09-23.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationRequest.h"

@class MSIDConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationTokenRequest : MSIDBrokerOperationRequest

@property (nonatomic) MSIDConfiguration *configuration;

@end

NS_ASSUME_NONNULL_END
