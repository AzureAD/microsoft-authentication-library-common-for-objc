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

@property (nonatomic) NSURL *requestURL;
@property (nonatomic) NSString *bundleIdentifier;
@property (nonatomic) MSIDAADAuthority *authority;
@property (nonatomic) NSDictionary *headers;

- (instancetype)initWithRequest:(NSURL *)requestURL headers:(NSDictionary *)headers
               bundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
