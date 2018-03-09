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

#import "MSIDAccountCacheItem.h"

@implementation MSIDAccountCacheItem

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    _legacyUserIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"legacy_user_id"];
    
    _accountType = [MSIDAccountTypeHelpers accountTypeFromString:[coder decodeObjectOfClass:[NSString class] forKey:@"authority_type"]];
    
    _firstName = [coder decodeObjectOfClass:[NSString class] forKey:@"first_name"];
    _lastName = [coder decodeObjectOfClass:[NSString class] forKey:@"last_name"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_legacyUserIdentifier forKey:@"legacy_user_id"];
    [coder encodeObject:[MSIDAccountTypeHelpers accountTypeAsString:_accountType] forKey:@"authority_type"];
    [coder encodeObject:_firstName forKey:@"first_name"];
    [coder encodeObject:_lastName forKey:@"last_name"];
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    // Authority account ID
    _legacyUserIdentifier = json[MSID_ACCOUNT_ID_CACHE_KEY];
    
    /* Optional fields */
    // First name
    _firstName = json[MSID_FIRST_NAME_CACHE_KEY];
    
    // Last name
    _lastName = json[MSID_LAST_NAME_CACHE_KEY];
    
    // Account type
    _accountType = [MSIDAccountTypeHelpers accountTypeFromString:json[MSID_AUTHORITY_TYPE_CACHE_KEY]];
    
    // Extensibility
    _additionalAccountFields = json;
    
    return self;
}

- (NSDictionary *)jsonDictionary
{    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (_additionalAccountFields)
    {
        [dictionary addEntriesFromDictionary:_additionalAccountFields];
    }
    
    // Parent JSON
    [dictionary addEntriesFromDictionary:[super jsonDictionary]];
    
    /* Mandatory fields */
    // Tenant
    dictionary[MSID_REALM_CACHE_KEY] = _authority.msidTenant;
    
    // Authority account ID
    dictionary[MSID_ACCOUNT_ID_CACHE_KEY] = _legacyUserIdentifier;
    
    /* Optional fields */
    // First name
    dictionary[MSID_FIRST_NAME_CACHE_KEY] = _firstName;
    
    // Last name
    dictionary[MSID_LAST_NAME_CACHE_KEY] = _lastName;
    
    // Account type
    dictionary[MSID_AUTHORITY_TYPE_CACHE_KEY] = [MSIDAccountTypeHelpers accountTypeAsString:_accountType];
    
    return dictionary;
}

#pragma mark - Update

- (void)updateFieldsFromAccount:(MSIDAccountCacheItem *)account
{
    NSMutableDictionary *allAdditionalFields = [NSMutableDictionary dictionary];
    [allAdditionalFields addEntriesFromDictionary:account.additionalAccountFields];
    [allAdditionalFields addEntriesFromDictionary:_additionalAccountFields];
    _additionalAccountFields = allAdditionalFields;
}

@end
