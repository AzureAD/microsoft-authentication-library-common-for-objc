//
//  MSIDBrokerNativeAppOperationResponse.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 2/26/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDJsonSerializable.h"
#import "MSIDBrokerOperationResponse.h"

@class MSIDDeviceInfo;

extern NSString * _Nonnull const MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerNativeAppOperationResponse : MSIDBrokerOperationResponse <MSIDJsonSerializable>

@property (nonatomic, class, readonly) NSString *responseType;
@property (nonatomic) BOOL success;
@property (nonatomic, nullable) NSString *clientAppVersion;

@property (nonatomic) MSIDDeviceInfo *deviceInfo;

@property (nonatomic) NSNumber *httpStatusCode;
@property (nonatomic, nullable) NSDictionary *httpHeaders;
@property (nonatomic) NSString *httpVersion;

- (instancetype)initWithDeviceInfo:(MSIDDeviceInfo *)deviceInfo;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;


@end

NS_ASSUME_NONNULL_END
