//
//  MSIDSignedHttpRequestJwt.h
//  IdentityCore
//
//  Created by Rohit Narula on 4/29/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSIDSignedHttpRequestJwt : NSObject

@property (nonatomic, nullable) NSString *accessToken;
@property (nonatomic, nullable) NSString *timestamp;
@property (nonatomic, nullable) NSString *httpMethod;
@property (nonatomic, nullable) NSString *httpHost;
@property (nonatomic, nullable) NSString *httpPath;
@property (nonatomic, nullable) NSString *conf;
@property (nonatomic, nullable) NSString *nonce;

@end

NS_ASSUME_NONNULL_END
