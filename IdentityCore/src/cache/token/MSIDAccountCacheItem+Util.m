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

#import "MSIDJsonSerializable.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCacheItem+Util.h"
#import "MSIDClientInfo.h"

@implementation MSIDAccountCacheItem (Util)

#pragma mark - Equal

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDAccountCacheItem *)object];
}

- (BOOL)isEqualToItem:(MSIDAccountCacheItem *)item
{
    BOOL result = YES;
    result &= self.accountType == item.accountType;
    result &= (!self.homeAccountId && !item.homeAccountId) || [self.homeAccountId isEqualToString:item.homeAccountId];
    result &= (!self.localAccountId && !item.localAccountId) || [self.localAccountId isEqualToString:item.localAccountId];
    result &= (!self.username && !item.username) || [self.username isEqualToString:item.username];
    result &= (!self.givenName && !item.givenName) || [self.givenName isEqualToString:item.givenName];
    result &= (!self.middleName && !item.middleName) || [self.middleName isEqualToString:item.middleName];
    result &= (!self.familyName && !item.familyName) || [self.familyName isEqualToString:item.familyName];
    result &= (!self.name && !item.name) || [self.name isEqualToString:item.name];
    result &= (!self.realm && !item.realm) || [self.realm isEqualToString:item.realm];
    result &= (!self.rawClientInfo && !item.rawClientInfo) || [self.rawClientInfo isEqualToString:item.rawClientInfo];
    result &= (!self.environment && !item.environment) || [self.environment isEqualToString:item.environment];
    result &= (!self.alternativeAccountId && !item.alternativeAccountId) || [self.alternativeAccountId isEqualToString:item.alternativeAccountId];
    return result;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.accountType;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.localAccountId.hash;
    hash = hash * 31 + self.username.hash;
    hash = hash * 31 + self.givenName.hash;
    hash = hash * 31 + self.middleName.hash;
    hash = hash * 31 + self.familyName.hash;
    hash = hash * 31 + self.name.hash;
    hash = hash * 31 + self.realm.hash;
    hash = hash * 31 + self.rawClientInfo.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.alternativeAccountId.hash;
    return hash;
}

#pragma mark - NSCopying

- (nonnull id)copyWithZone:(NSZone *)zone
{
    MSIDAccountCacheItem *item = [[self class] allocWithZone:zone];
    item.accountType = self.accountType;
    item.homeAccountId = [self.homeAccountId copyWithZone:zone];
    item.localAccountId = [self.localAccountId copyWithZone:zone];
    item.username = [self.username copyWithZone:zone];
    item.givenName = [self.givenName copyWithZone:zone];
    item.middleName = [self.middleName copyWithZone:zone];
    item.familyName = [self.familyName copyWithZone:zone];
    item.name = [self.name copyWithZone:zone];
    item.realm = [self.realm copyWithZone:zone];
    item.rawClientInfo = [self.rawClientInfo copyWithZone:zone];
    item.environment = [self.environment copyWithZone:zone];
    item.alternativeAccountId = [self.alternativeAccountId copyWithZone:zone];
    return item;
}

#pragma mark - JSON

- (nonnull instancetype)initWithJSONDictionary:(nullable NSDictionary *)json error:(__unused NSError * __nullable * __nullable)error
{
    MSID_TRACE;
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!json)
    {
        MSID_LOG_WARN(nil, @"Tried to decode an account cache item from nil json");
        return nil;
    }
    
    self.json = json;
    
    self.accountType = [MSIDAccountTypeHelpers accountTypeFromString:json[MSID_AUTHORITY_TYPE_CACHE_KEY]];
    
    if (!self.accountType)
    {
        MSID_LOG_WARN(nil, @"No account type present in the JSON for credential");
        return nil;
    }
    
    self.localAccountId = json[MSID_LOCAL_ACCOUNT_ID_CACHE_KEY];
    self.homeAccountId = json[MSID_HOME_ACCOUNT_ID_CACHE_KEY];
    self.username = json[MSID_USERNAME_CACHE_KEY];
    self.givenName = json[MSID_GIVEN_NAME_CACHE_KEY];
    self.middleName = json[MSID_MIDDLE_NAME_CACHE_KEY];
    self.familyName = json[MSID_FAMILY_NAME_CACHE_KEY];
    self.name = json[MSID_NAME_CACHE_KEY];
    self.realm = json[MSID_REALM_CACHE_KEY];
    self.rawClientInfo = json[MSID_CLIENT_INFO_CACHE_KEY];
    self.environment = json[MSID_ENVIRONMENT_CACHE_KEY];
    self.alternativeAccountId = json[MSID_ALTERNATIVE_ACCOUNT_ID_KEY];
    return self;
}

- (nullable NSDictionary *)jsonDictionary
{
    MSID_TRACE;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (self.json)
    {
        [dictionary addEntriesFromDictionary:self.json];
    }
    
    NSDictionary* additionalAccountFields = self.additionalAccountFields;
    if (additionalAccountFields)
    {
        [dictionary addEntriesFromDictionary:additionalAccountFields];
    }
    
    dictionary[MSID_AUTHORITY_TYPE_CACHE_KEY] = [MSIDAccountTypeHelpers accountTypeAsString:self.accountType];
    dictionary[MSID_HOME_ACCOUNT_ID_CACHE_KEY] = self.homeAccountId;
    dictionary[MSID_LOCAL_ACCOUNT_ID_CACHE_KEY] = self.localAccountId;
    dictionary[MSID_USERNAME_CACHE_KEY] = self.username;
    dictionary[MSID_GIVEN_NAME_CACHE_KEY] = self.givenName;
    dictionary[MSID_MIDDLE_NAME_CACHE_KEY] = self.middleName;
    dictionary[MSID_FAMILY_NAME_CACHE_KEY] = self.familyName;
    dictionary[MSID_NAME_CACHE_KEY] = self.name;
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = self.environment;
    dictionary[MSID_REALM_CACHE_KEY] = self.realm;
    dictionary[MSID_CLIENT_INFO_CACHE_KEY] = self.rawClientInfo;
    dictionary[MSID_ALTERNATIVE_ACCOUNT_ID_KEY] = self.alternativeAccountId;
    return dictionary;
}

#pragma mark - Update

- (void)updateFieldsFromAccount:(nullable MSIDAccountCacheItem *)account
{
    NSMutableDictionary *allAdditionalFields = [NSMutableDictionary dictionary];
    [allAdditionalFields addEntriesFromDictionary:account.additionalAccountFields];
    [allAdditionalFields addEntriesFromDictionary:self.additionalAccountFields];
    self.additionalAccountFields = allAdditionalFields;
}

#pragma mark - Query

- (BOOL)matchesWithHomeAccountId:(nullable NSString *)homeAccountId
                     environment:(nullable NSString *)environment
              environmentAliases:(nullable NSArray<NSString *> *)environmentAliases
{
    if (homeAccountId && ![self.homeAccountId isEqualToString:homeAccountId])
    {
        return NO;
    }
    
    if (environment && ![self.environment isEqualToString:environment])
    {
        return NO;
    }
    
    if ([environmentAliases count] && ![self.environment msidIsEquivalentWithAnyAlias:environmentAliases])
    {
        return NO;
    }
    
    return YES;
}
@end
