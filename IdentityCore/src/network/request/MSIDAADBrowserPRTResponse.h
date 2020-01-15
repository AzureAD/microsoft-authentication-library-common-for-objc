//
//  MSIDAADBrowserPRTResponse.h
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAADBrowserPRTResponse : NSObject

@property (nonatomic, nullable) NSHTTPURLResponse *httpURLresponse;
@property (nonatomic, nullable) NSData *body;

@end

NS_ASSUME_NONNULL_END
