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

#import "MSIDAccountItem.h"
#import "MSIDClientInfo.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDIdTokenWrapper.h"

@implementation MSIDAccountItem

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccountItem *item = [super copyWithZone:zone];
    item->_legacyUserId = [_legacyUserId copyWithZone:zone];
    item->_uid = [_uid copyWithZone:zone];
    item->_utid = [_utid copyWithZone:zone];
    
    return item;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    _legacyUserId = [coder decodeObjectOfClass:[NSString class] forKey:@"upn"];
    _uid = [coder decodeObjectOfClass:[NSString class] forKey:@"uid"];
    _utid = [coder decodeObjectOfClass:[NSString class] forKey:@"utid"];
    _accountType = [self accountTypeFromString:[coder decodeObjectOfClass:[NSString class] forKey:@"account_type"]];
    _firstName = [coder decodeObjectOfClass:[NSString class] forKey:@"first_name"];
    _lastName = [coder decodeObjectOfClass:[NSString class] forKey:@"last_name"];
    _additionalFields = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additional_fields"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_legacyUserId forKey:@"upn"];
    [coder encodeObject:_uid forKey:@"uid"];
    [coder encodeObject:_utid forKey:@"utid"];
    [coder encodeObject:[self accountTypeString] forKey:@"account_type"];
    [coder encodeObject:_firstName forKey:@"first_name"];
    [coder encodeObject:_lastName forKey:@"last_name"];
    [coder encodeObject:_additionalFields forKey:@"additional_fields"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDAccountItem.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDAccountItem *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.legacyUserId.hash;
    hash = hash * 31 + self.uid.hash;
    hash = hash * 31 + self.utid.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDAccountItem *)account
{
    if (!account)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToItem:account];
    result &= (!self.legacyUserId && !account.legacyUserId) || [self.legacyUserId isEqualToString:account.legacyUserId];
    result &= (!self.uid && !account.uid) || [self.uid isEqualToString:account.uid];
    result &= (!self.utid && !account.utid) || [self.utid isEqualToString:account.utid];
    result &= (!self.firstName && !account.firstName) || [self.firstName isEqualToString:account.firstName];
    result &= (!self.lastName && !account.lastName) || [self.lastName isEqualToString:account.lastName];
    result &= self.accountType == account.accountType;
    
    return result;
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    // Realm
    if (json[MSID_AUTHORITY_CACHE_KEY])
    {
        _authority = [NSURL URLWithString:json[MSID_AUTHORITY_CACHE_KEY]];
    }
    else if (json[MSID_REALM_CACHE_KEY])
    {
        NSString *authorityString = [NSString stringWithFormat:@"https://%@/%@", json[MSID_ENVIRONMENT_CACHE_KEY], json[MSID_REALM_CACHE_KEY]];
        _authority = [NSURL URLWithString:authorityString];
    }
    
    // Authority account ID
    _legacyUserId = json[MSID_ACCOUNT_ID_CACHE_KEY];
    
    /* Optional fields */
    // First name
    _firstName = json[MSID_FIRST_NAME_CACHE_KEY];
    
    // Last name
    _lastName = json[MSID_LAST_NAME_CACHE_KEY];
    
    // Account type
    _accountType = [self accountTypeFromString:json[MSID_ACCOUNT_TYPE_CACHE_KEY]];
    
    // Additional fields for extensibility
    _additionalFields = json;
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    // Additional fields
    [dictionary addEntriesFromDictionary:_additionalFields];
    
    // Parent JSON
    [dictionary addEntriesFromDictionary:[super jsonDictionary]];
    
    /* Mandatory fields */
    // Realm
    [dictionary setValue:_authority.msidTenant
                  forKey:MSID_REALM_CACHE_KEY];
    
    // Authority account ID
    [dictionary setValue:_legacyUserId
                  forKey:MSID_ACCOUNT_ID_CACHE_KEY];
    
    /* Optional fields */
    // First name
    [dictionary setValue:_firstName
                  forKey:MSID_FIRST_NAME_CACHE_KEY];
    
    // Last name
    [dictionary setValue:_lastName
                  forKey:MSID_LAST_NAME_CACHE_KEY];
    
    // Account type
    [dictionary setValue:[self accountTypeString]
                  forKey:MSID_ACCOUNT_TYPE_CACHE_KEY];
    
    // Authority
    [dictionary setValue:_authority.absoluteString
                  forKey:MSID_AUTHORITY_CACHE_KEY];
    
    return dictionary;
}

#pragma mark - Init

- (instancetype)init
{
    return [self initWithUpn:nil
                        utid:nil
                         uid:nil];
}

- (instancetype)initWithUpn:(NSString *)upn
                       utid:(NSString *)utid
                        uid:(NSString *)uid
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self->_legacyUserId = upn;
    self->_utid = utid;
    self->_uid = uid;

    return self;
}

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    NSString *uid = nil;
    NSString *utid = nil;
    
    if ([response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        MSIDAADTokenResponse *aadTokenResponse = (MSIDAADTokenResponse *)response;
        uid = aadTokenResponse.clientInfo.uid;
        utid = aadTokenResponse.clientInfo.utid;
    }
    else
    {
        uid = response.idTokenObj.subject;
        utid = @"";
    }
    
    NSString *userId = response.idTokenObj.userId;
    return [self initWithUpn:userId utid:utid uid:uid];
}

- (NSString *)userIdentifier
{
    if (self.uid && self.uid)
    {
        return [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
    }
    return self.uniqueUserId;
}

#pragma mark - Helpers

- (NSString *)accountTypeString
{
    switch (self.accountType)
    {
        case MSIDAccountTypeAADV1:
            return @"AAD";
            
        case MSIDAccountTypeMSA:
            return @"MSA";
            
        case MSIDAccountTypeAADV2:
            return @"MSSTS";
            
        default:
            return @"Other";
    }
}

static NSDictionary *accountTypes = nil;

- (MSIDAccountType)accountTypeFromString:(NSString *)type
{
    if (!accountTypes)
    {
        accountTypes = @{@"AAD": @(MSIDAccountTypeAADV1),
                         @"MSA": @(MSIDAccountTypeMSA),
                         @"MSSTS": @(MSIDAccountTypeAADV2)};
    }
    
    NSNumber *accountType = accountTypes[type];
    return accountType ? [accountType integerValue] : MSIDAccountTypeOther;
}

#pragma mark - Update

- (void)updateFieldsFromAccount:(MSIDAccountItem *)account
{
    NSMutableDictionary *allAdditionalFields = [NSMutableDictionary dictionary];
    [allAdditionalFields addEntriesFromDictionary:account.additionalFields];
    [allAdditionalFields addEntriesFromDictionary:_additionalFields];
    _additionalFields = allAdditionalFields;
}

@end
