//
//  MSIDBrokerOperationRemoveAccountRequest.m
//  IdentityCore iOS
//
//  Created by JZ on 10/9/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationRemoveAccountRequest.h"
#import "MSIDBrokerOperationRequestFactory.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"

@implementation MSIDBrokerOperationRemoveAccountRequest

+ (void)load
{
    [MSIDBrokerOperationRequestFactory registerOperationRequestClass:self operation:self.operation];
}

#pragma mark - MSIDBrokerOperationRequest

+ (NSString *)operation
{
    return @"remove_account";
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];
    
    if (self)
        {
            if (![json msidAssertType:NSDictionary.class ofKey:@"request_parameters" required:YES error:error]) return nil;
            
            NSDictionary *requestParameters = json[@"request_parameters"];
            
            _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:requestParameters error:error];
            if (!_accountIdentifier) return nil;
            
            _clientId = requestParameters[@"client_id"];
            if (!_clientId)
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"client id is missing in remove account operation call!", nil, nil, nil, nil, nil);
                }
                return nil;
            }
        }
        
        return self;
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    
    NSMutableDictionary *requestParametersJson = [json[@"request_parameters"] mutableCopy];
    
    if (!requestParametersJson) return nil;
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [requestParametersJson addEntriesFromDictionary:accountIdentifierJson];
    
    [requestParametersJson setValue:self.clientId forKey:@"client_id"];
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
