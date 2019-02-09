//
//  MSIDTestDeviceAPIRequest.m
//  IdentityCore
//
//  Created by Olga Dalton on 2/8/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDTestResetAPIRequest.h"

@implementation MSIDTestResetAPIRequest

- (NSURL *)requestURLWithAPIPath:(NSString *)apiPath labPassword:(NSString *)labPassword
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:apiPath];
    
    NSMutableArray *queryItems = [NSMutableArray array];
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"code" value:labPassword]];
    
    if (self.apiOperation)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"Operation" value:self.apiOperation]];
    }
    
    if (self.userUPN)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"upn" value:self.userUPN]];
    }
    
    if (self.deviceGUID)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"DeviceID" value:self.deviceGUID]];
    }
    
    components.queryItems = queryItems;
    NSURL *resultURL = [components URL];
    return resultURL;
}

@end
