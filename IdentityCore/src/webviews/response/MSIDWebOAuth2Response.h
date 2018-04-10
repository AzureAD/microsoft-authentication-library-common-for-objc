//
//  MSIDWebOAuth2Response.h
//  IdentityCore iOS
//
//  Created by Jason Kim on 4/10/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MSIDWebOAuth2Response : NSObject

@property NSError *error;
@property NSString *code;

@end
