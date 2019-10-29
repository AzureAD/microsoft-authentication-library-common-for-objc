//
//  MSIDAuthSessionHandlerFactory.h
//  IdentityCore
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDAuthSessionHandling.h"

#if !MSID_EXCLUDE_WEBKIT

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAuthSessionHandlerFactory : NSObject

+ (id<MSIDAuthSessionHandling>)authSessionWithParentController:(MSIDViewController *)parentController;

@end

NS_ASSUME_NONNULL_END

#endif
