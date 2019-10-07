//
//  MSIDBrokerOperationGetAccountsRequest.h
//  IdentityCore
//
//  Created by JZ on 10/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationGetAccountsRequest : MSIDBrokerOperationRequest

// TODO: if we want to support more sophisticated account query.
//@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
//@property (nonatomic) NSString *clientId;
//@property (nonatomic) MSIDAuthority *authority;

@end

NS_ASSUME_NONNULL_END
