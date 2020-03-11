//
//  NSDictionary+MSIDLogging.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 3/11/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "NSDictionary+MSIDLogging.h"

@implementation NSDictionary (MSIDLogging)

+ (NSArray *)secretRequestKeys
{
    static NSArray *s_blackListedKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_blackListedKeys = @[@"broker_key"];
    });
    
    return s_blackListedKeys;
}

- (NSDictionary *)maskedRequestDictionary
{
    NSMutableDictionary *mutableRequestDict = [self mutableCopy];
    [mutableRequestDict removeObjectsForKeys:[[self class] secretRequestKeys]];
    return mutableRequestDict;
}

@end
