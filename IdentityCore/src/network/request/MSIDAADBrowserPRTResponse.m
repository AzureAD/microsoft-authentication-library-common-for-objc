//
//  MSIDAADBrowserPRTResponse.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDAADBrowserPRTResponse.h"

@implementation MSIDAADBrowserPRTResponse

- (instancetype)initWithResponse:(NSHTTPURLResponse *)response bundleIdentifier:(NSData *)body
{
    self = [super init];
    if (self)
    {
        _response = response;
        _body = body;
    }
    
    return self;
}

@end
