//
//  MSIDBrowserUrlRequestSerializer.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDBrowserUrlRequestSerializer.h"

@implementation MSIDBrowserUrlRequestSerializer

- (NSURLRequest *)serializeWithRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters
{
    NSParameterAssert(request);
    
    if (!parameters) return request;
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.allHTTPHeaderFields = parameters;
    return mutableRequest;
}

@end
