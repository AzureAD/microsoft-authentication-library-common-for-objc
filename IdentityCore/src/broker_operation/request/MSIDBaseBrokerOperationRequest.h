//
//  MSIDBaseBrokerOperationRequest.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 2/6/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBaseBrokerOperationRequest : NSObject

@property (nonatomic, class, readonly) NSString *operation;

@end

NS_ASSUME_NONNULL_END
