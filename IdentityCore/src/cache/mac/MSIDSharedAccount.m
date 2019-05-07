//
//  MSIDSharedAccount.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 5/3/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDSharedAccount.h"

@implementation MSIDSharedAccount

- (instancetype)init
{
    if(self = [super init])
    {
        self.refreshTokens = [NSMutableDictionary new];
    }
    
    return self;
}

@end
