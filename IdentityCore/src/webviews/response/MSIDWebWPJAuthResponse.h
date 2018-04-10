//
//  MSIDWebWPJAuthResponse.h
//  IdentityCore iOS
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDWebOAuth2Response.h"

@interface MSIDWebWPJAuthResponse : MSIDWebOAuth2Response

@property NSString *upn;
@property NSString *appLink; // TBD on the need

@end
