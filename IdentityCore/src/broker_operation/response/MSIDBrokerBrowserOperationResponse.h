//
//  MSIDBrokerBrowserOperationResponse.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 2/26/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDBrokerOperationResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerBrowserOperationResponse : MSIDBrokerOperationResponse

@property (nonatomic, nullable) NSHTTPURLResponse *httpResponse;
@property (nonatomic, nullable) NSData *httpBody;
@property (nonatomic, nullable) NSError *httpError;

- (instancetype)initWithURLResponse:(NSHTTPURLResponse *)httpResponse body:(NSData *)httpBody;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
