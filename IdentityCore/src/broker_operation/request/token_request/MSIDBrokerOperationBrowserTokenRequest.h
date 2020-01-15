//
//  MSIDBrokerOperationBrowserTokenRequest.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/2/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDBrokerOperationRequest.h"
@class MSIDConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationBrowserTokenRequest : MSIDBrokerOperationRequest

@property (nonatomic) MSIDConfiguration *configuration;
@property (nonatomic) NSString *requestURL;

@end

NS_ASSUME_NONNULL_END
