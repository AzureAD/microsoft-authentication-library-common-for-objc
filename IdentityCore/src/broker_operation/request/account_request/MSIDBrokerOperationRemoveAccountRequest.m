//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

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
        
        if (![requestParameters msidAssertType:NSDictionary.class ofKey:@"account_identifier" required:YES error:error])
        {
            return nil;
        }
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:requestParameters[@"account_identifier"] error:error];
        if (!_accountIdentifier || !_accountIdentifier.homeAccountId)
        {
            if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"At least homeAccountId is required for remove account operation!", nil, nil, nil, nil, nil);
            return nil;
        }
        
        _clientId = [requestParameters msidStringObjectForKey:@"client_id"];
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
