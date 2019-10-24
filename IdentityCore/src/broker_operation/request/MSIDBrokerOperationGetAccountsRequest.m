//
//  MSIDBrokerOperationGetAccountsRequest.m
//  IdentityCore iOS
//
//  Created by JZ on 10/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationGetAccountsRequest.h"
#import "MSIDBrokerOperationRequestFactory.h"

@implementation MSIDBrokerOperationGetAccountsRequest

+ (void)load
{
    [MSIDBrokerOperationRequestFactory registerOperationRequestClass:self operation:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return @"get_accounts";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class ofKey:@"request_parameters" required:YES error:error]) return nil;
        
        NSDictionary *requestParameters = json[@"request_parameters"];
        
        _clientId = requestParameters[@"client_id"];
        if (!_clientId)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"client id is missing in get accounts operation call!", nil, nil, nil, nil, nil);
            }
            return nil;
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *requestParametersJson = [json[@"request_parameters"] mutableCopy];
    if (!requestParametersJson) return nil;
    [requestParametersJson setValue:self.clientId forKey:@"client_id"];
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
