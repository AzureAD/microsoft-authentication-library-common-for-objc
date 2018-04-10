//
//  MSIDAADV2RequestParameter.h
//  IdentityCore iOS
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSIDRequestParameters.h"
#import "MSIDUserInformation.h"

@interface MSIDAADV2RequestParameter : MSIDRequestParameters

@property MSIDUserInformation *userInformation;

@end
