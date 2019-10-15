//
//  MSIDBrokerOperationRemoveAccountRequest.m
//  IdentityCore iOS
//
//  Created by JZ on 10/9/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerOperationRemoveAccountRequest.h"
#import "MSIDJsonSerializableFactory.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDBrokerOperationRemoveAccountRequest

+ (void)load
{
    [MSIDJsonSerializableFactory registerClass:self forClassType:self.operation];
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
            
            _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:requestParameters[@"account_identifier"] error:error];
            if (!_accountIdentifier || !_accountIdentifier.homeAccountId)
            {
                if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"At least homeAccountId is required for remove account operation!", nil, nil, nil, nil, nil);
                return nil;
            }
            
            _clientId = requestParameters[@"client_id"];
            if (!_clientId)
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"client id is missing in remove account operation call!", nil, nil, nil, nil, nil);
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
    
    NSMutableDictionary *requestParametersJson = [json[@"request_parameters"] mutableCopy] ?: [NSMutableDictionary new];
    
    if (!requestParametersJson) return nil;
    
    NSDictionary *accountIdentifierJson = [self.accountIdentifier jsonDictionary];
    if (accountIdentifierJson) [requestParametersJson setValue:accountIdentifierJson forKey:@"account_identifier"];
    
    [requestParametersJson setValue:self.clientId forKey:@"client_id"];
    
    json[@"request_parameters"] = requestParametersJson;
    
    return json;
}

@end
