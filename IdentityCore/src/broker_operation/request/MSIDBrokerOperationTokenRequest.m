//
//  MSIDBrokerOperationTokenRequest.m
//  IdentityCore iOS
//
//  Created by Serhii Demchenko on 2019-09-23.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationTokenRequest.h"
#import "MSIDConfiguration+MSIDJsonSerializable.h"

@implementation MSIDBrokerOperationTokenRequest

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class ofField:@"request_parameters" context:nil errorCode:MSIDErrorInvalidInternalParameter error:error]) return nil;
        NSDictionary *requestParameters = json[@"request_parameters"];
        
        _configuration = [[MSIDConfiguration alloc] initWithJSONDictionary:requestParameters error:error];
        if (!_configuration) return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *requestParametersJson = [NSMutableDictionary new];
    
    NSDictionary *configurationJson = [self.configuration jsonDictionary];
    if (configurationJson) [requestParametersJson addEntriesFromDictionary:configurationJson];
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
