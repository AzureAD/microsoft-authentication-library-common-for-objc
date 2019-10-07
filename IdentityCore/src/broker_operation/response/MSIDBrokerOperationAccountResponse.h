//
//  MSIDBrokerOperationAccountResponse.h
//  IdentityCore
//
//  Created by JZ on 10/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationResponse.h"

@class MSIDAccount;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationAccountResponse : MSIDBrokerOperationResponse

@property (nonatomic, nullable) NSArray<MSIDAccount *> *accounts;

@end

NS_ASSUME_NONNULL_END
