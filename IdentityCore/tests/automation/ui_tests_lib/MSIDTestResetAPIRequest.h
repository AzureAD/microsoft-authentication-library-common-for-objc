//
//  MSIDTestDeviceAPIRequest.h
//  IdentityCore
//
//  Created by Olga Dalton on 2/8/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSIDTestResetAPIRequest : NSObject

@property (nonatomic) NSString *apiOperation;
@property (nonatomic) NSString *userUPN;
@property (nonatomic) NSString *deviceGUID;

- (NSURL *)requestURLWithAPIPath:(NSString *)apiPath labPassword:(NSString *)labPassword;

@end

NS_ASSUME_NONNULL_END
