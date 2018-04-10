//
//  MSIDWebAADAuthResponse.h
//  IdentityCore iOS
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDWebOAuth2Response.h"

@interface MSIDWebAADAuthResponse : MSIDWebOAuth2Response

@property NSString *cloudHostName;

@end
