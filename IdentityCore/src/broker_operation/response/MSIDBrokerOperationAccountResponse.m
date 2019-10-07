//
//  MSIDBrokerOperationAccountResponse.m
//  IdentityCore iOS
//
//  Created by JZ on 10/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationAccountResponse.h"
#import "MSIDAccount+MSIDJsonSerializable.h"

@implementation MSIDBrokerOperationAccountResponse

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        if (![json msidAssertType:NSDictionary.class
                          ofField:@"response_data"
                          context:nil
                        errorCode:MSIDErrorInvalidInternalParameter
                            error:error])
        {
            return nil;
        }
        
        NSMutableArray *accounts = [NSMutableArray new];
        
        NSArray *accountsJson = json[@"response_data"];
        for (NSDictionary *accountJson in accountsJson)
        {
            MSIDAccount *account = [[MSIDAccount alloc] initWithJSONDictionary:accountJson error:error];
            if (!account) return nil;
            
            [accounts addObject:account];
        }
        
        self.accounts = accounts;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableArray *accountsJson = [NSMutableArray new];
    
    for (MSIDAccount *account in self.accounts)
    {
        NSDictionary *accountJson = [account jsonDictionary];
        if (accountJson) [accountsJson addObject:accountJson];
    }
    
    json[@"response_data"] = accountsJson;
    
    return json;
}

@end
