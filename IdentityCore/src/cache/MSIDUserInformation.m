//
//  MSIDUserInformation.m
//  IdentityCore
//
//  Created by Sergey Demchenko on 12/7/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "MSIDUserInformation.h"

@implementation MSIDUserInformation

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _rawIdToken = [coder decodeObjectOfClass:[NSString class] forKey:@"rawIdToken"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_rawIdToken forKey:@"rawIdToken"];
}

@end
