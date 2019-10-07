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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDAccount+MSIDJsonSerializable.h"
#import "MSIDClientInfo.h"
#import "MSIDAccountIdentifier+MSIDJsonSerializable.h"

@implementation MSIDAccount (MSIDJsonSerializable)

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithJSONDictionary:json[@"account_identifier"] error:error];
    if (!self.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"No valid account identifier present in the JSON");
        return nil;
    }
    
    self.accountType = [MSIDAccountTypeHelpers accountTypeFromString:[json msidStringObjectForKey:@"account_type"]];
    if (!self.accountType)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"No valid account type present in the JSON");
        return nil;
    }
    
    self.localAccountId = [json msidStringObjectForKey:@"local_account_id"];
    self.environment = [json msidStringObjectForKey:@"environment"];
    self.storageEnvironment = [json msidStringObjectForKey:@"storage_environment"];
    self.realm = [json msidStringObjectForKey:@"realm"];
    self.username = [json msidStringObjectForKey:@"username"];
    self.givenName = [json msidStringObjectForKey:@"given_name"];
    self.middleName = [json msidStringObjectForKey:@"middle_name"];
    self.familyName = [json msidStringObjectForKey:@"family_name"];
    self.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:[json msidStringObjectForKey:@"client_info"] error:nil];
    self.alternativeAccountId = [json msidStringObjectForKey:@"alternative_account_id"];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"account_identifier"] = [self.accountIdentifier jsonDictionary];
    json[@"local_account_id"] = self.localAccountId;
    json[@"account_type"] = [MSIDAccountTypeHelpers accountTypeAsString:self.accountType];;
    json[@"environment"] = self.environment;
    json[@"storage_environment"] = self.storageEnvironment;
    json[@"realm"] = self.realm;
    json[@"username"] = self.username;
    json[@"given_name"] = self.givenName;
    json[@"middle_name"] = self.middleName;
    json[@"family_name"] = self.familyName;
    json[@"client_info"] = self.clientInfo.rawClientInfo;
    json[@"alternative_account_id"] = self.alternativeAccountId;
    
    return json;
}

@end
