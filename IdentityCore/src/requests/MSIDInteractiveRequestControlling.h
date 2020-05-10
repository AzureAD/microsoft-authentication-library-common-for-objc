//
//  MSIDInteractiveRequstControlling.h
//  IdentityCore
//
//  Created by Olga Dalton on 5/9/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MSIDTokenResult;
@class MSIDWebWPJResponse;

typedef void (^MSIDInteractiveRequestCompletionBlock)(MSIDTokenResult * _Nullable result, NSError * _Nullable error, MSIDWebWPJResponse * _Nullable installBrokerResponse);

NS_ASSUME_NONNULL_BEGIN

@protocol MSIDInteractiveRequestControlling <NSObject>

- (void)executeRequestWithCompletion:(MSIDInteractiveRequestCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
