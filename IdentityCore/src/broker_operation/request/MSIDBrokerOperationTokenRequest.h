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

// TODO: uncomment.
//@property (nonatomic, nullable) NSOrderedSet<NSString *> *extraScopesToConsent;
//@property (nonatomic, nullable) NSOrderedSet<NSString *> *extraOIDCScopes;
//@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *extraAuthorizeURLQueryParameters;
//@property (nonatomic, nullable) NSArray<NSString *> *clientCapabilities;
///*! Claims is a json dictionary. It is not url encoded. */
//@property (nonatomic, nullable) NSDictionary *claims;

@end

NS_ASSUME_NONNULL_END
