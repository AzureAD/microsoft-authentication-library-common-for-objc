//
//  MSIDBrokerOperationBrowserTokenRequest.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/2/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDBaseBrokerOperationRequest.h"

NS_ASSUME_NONNULL_BEGIN

@class MSIDAADAuthority;

@interface MSIDBrokerOperationBrowserTokenRequest : MSIDBaseBrokerOperationRequest

@property (nonatomic, readonly) NSURL *requestURL;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) MSIDAADAuthority *authority;
@property (nonatomic, readonly) NSDictionary *headers;
@property (nonatomic, readonly) NSUUID *correlationId;

- (instancetype)initWithRequest:(NSURL *)requestURL
                        headers:(NSDictionary *)headers
               bundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
