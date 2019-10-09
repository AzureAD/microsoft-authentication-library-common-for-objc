//
//  MSIDBrokerOperationRemoveAccountRequest.h
//  IdentityCore
//
//  Created by JZ on 10/9/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationRequest.h"

@class MSIDAccountIdentifier;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationRemoveAccountRequest : MSIDBrokerOperationRequest

@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic) NSString *clientId;

@end

NS_ASSUME_NONNULL_END

