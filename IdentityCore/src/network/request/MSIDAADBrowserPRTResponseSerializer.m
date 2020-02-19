//
//  MSIDAADBrowserPRTResponseSerializer.m
//  IdentityCore iOS
//
//  Created by Rohit Narula on 1/13/20.
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "MSIDAADBrowserPRTResponseSerializer.h"
#import "MSIDAADBrowserPRTResponse.h"

@implementation MSIDAADBrowserPRTResponseSerializer

- (id)responseObjectForResponse:(NSHTTPURLResponse *)httpResponse
                           data:(NSData *)data
                        context:(id <MSIDRequestContext>)context
                          error:(NSError **)error
{
    if (!httpResponse || !data)
    {
        NSError *localError = MSIDCreateError(MSIDErrorDomain,
                                              MSIDErrorAuthorizationFailed,
                                              nil,
                                              nil,
                                              nil,
                                              nil,
                                              context.correlationId,
                                              nil, YES);
        
        if (error) *error = localError;
        
        return nil;
    }
    
    __auto_type response = [[MSIDAADBrowserPRTResponse alloc] initWithResponse:httpResponse bundleIdentifier:data];
    return response;
}

@end
