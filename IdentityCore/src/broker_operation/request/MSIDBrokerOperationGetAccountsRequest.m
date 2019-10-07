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
    self = [super initWithJSONDictionary:json error:error];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    return json;
}

@end
