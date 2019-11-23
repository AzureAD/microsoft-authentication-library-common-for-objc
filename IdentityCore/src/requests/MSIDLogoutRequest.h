//
//  MSIDLogoutRequest.h
//  IdentityCore
//
//  Created by Olga Dalton on 11/20/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDConstants.h"

@class MSIDInteractiveRequestParameters;
@class MSIDOauth2Factory;
@class MSIDTokenResponseValidator;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDLogoutRequest : NSObject

@property (nonatomic, readonly, nonnull) MSIDInteractiveRequestParameters *requestParameters;
@property (nonatomic, readonly, nonnull) MSIDOauth2Factory *oauthFactory;

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory;

- (void)executeRequestWithCompletion:(nonnull MSIDLogoutRequestCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
