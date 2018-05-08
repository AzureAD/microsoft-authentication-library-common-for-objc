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
    
    _legacyUserId = [coder decodeObjectOfClass:[NSString class] forKey:@"legacy_user_id"];
    
    _accountType = [MSIDAccountTypeHelpers accountTypeFromString:[coder decodeObjectOfClass:[NSString class] forKey:@"authority_type"]];
    _username = [coder decodeObjectOfClass:[NSString class] forKey:@"username"];
    
    _givenName = [coder decodeObjectOfClass:[NSString class] forKey:@"given_name"];
    _middleName = [coder decodeObjectOfClass:[NSString class] forKey:@"middle_name"];
    _familyName = [coder decodeObjectOfClass:[NSString class] forKey:@"family_name"];
    _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
    _environment = [coder decodeObjectOfClass:[NSString class] forKey:@"environment"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:_legacyUserId forKey:@"legacy_user_id"];
    [coder encodeObject:[MSIDAccountTypeHelpers accountTypeAsString:_accountType] forKey:@"authority_type"];
    [coder encodeObject:_username forKey:@"username"];
    [coder encodeObject:_givenName forKey:@"given_name"];
    [coder encodeObject:_middleName forKey:@"middle_name"];
    [coder encodeObject:_familyName forKey:@"family_name"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_environment forKey:@"environment"];
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    // Authority account ID
    _legacyUserId = json[MSID_ACCOUNT_ID_CACHE_KEY];
    
    /* Optional fields */
    // First name
    _givenName = json[MSID_GIVEN_NAME_CACHE_KEY];

    // Middle name
    _middleName = json[MSID_MIDDLE_NAME_CACHE_KEY];
    
    // Last name
    _familyName = json[MSID_FAMILY_NAME_CACHE_KEY];

    // Name
    _name = json[MSID_NAME_CACHE_KEY];
    
    // Account type
    _accountType = [MSIDAccountTypeHelpers accountTypeFromString:json[MSID_AUTHORITY_TYPE_CACHE_KEY]];
    
    // Extensibility
    _additionalAccountFields = json;

    // Username
    _username = json[MSID_USERNAME_CACHE_KEY];

    // Environment
    _environment = json[MSID_ENVIRONMENT_CACHE_KEY];
    
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
    
    // Authority account ID
    dictionary[MSID_ACCOUNT_ID_CACHE_KEY] = _legacyUserId;
    
    /* Optional fields */
    // First name
    dictionary[MSID_GIVEN_NAME_CACHE_KEY] = _givenName;

    // Middle name
    dictionary[MSID_MIDDLE_NAME_CACHE_KEY] = _middleName;

    // Name
    dictionary[MSID_NAME_CACHE_KEY] = _name;
    
    // Last name
    dictionary[MSID_FAMILY_NAME_CACHE_KEY] = _familyName;

    // Username
    dictionary[MSID_USERNAME_CACHE_KEY] = _username;
    
    // Account type
    dictionary[MSID_AUTHORITY_TYPE_CACHE_KEY] = [MSIDAccountTypeHelpers accountTypeAsString:_accountType];

    // Environment
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = _environment;
    
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
