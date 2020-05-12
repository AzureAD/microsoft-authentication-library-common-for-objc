//
//  MSIDDevicePopManager.h
//  IdentityCore
//
//  Created by Rohit Narula on 4/28/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface MSIDDevicePopManager : NSObject

+ (instancetype)sharedManager;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (NSString *)getRequestConfirmation:(NSError **)error;

- (NSString *)createSignedAccessToken:(NSString *)accessToken
                            timeStamp:(NSUInteger)timeStamp
                           httpMethod:(NSString *)httpMethod
                           requestUrl:(NSString *)requestUrl
                                nonce:(NSString *)nonce
                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
