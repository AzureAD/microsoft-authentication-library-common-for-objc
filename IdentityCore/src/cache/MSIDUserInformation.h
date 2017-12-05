//
//  MSIDUserInformation.h
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/7/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MSIDUserInformation : NSObject <NSCoding>

@property (nonatomic) NSString *rawIdToken;

@end
