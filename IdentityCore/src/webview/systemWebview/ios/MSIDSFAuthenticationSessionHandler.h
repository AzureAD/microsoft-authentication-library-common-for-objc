//
//  MSIDSFAuthenticationSessionHandler.h
//  IdentityCore iOS
//
//  Created by Olga Dalton on 10/28/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSIDAuthSessionHandling.h"

#if !MSID_EXCLUDE_WEBKIT && !TARGET_OS_MACCATALYST

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(11.0))
@interface MSIDSFAuthenticationSessionHandler : NSObject <MSIDAuthSessionHandling>

@end

NS_ASSUME_NONNULL_END

#endif
