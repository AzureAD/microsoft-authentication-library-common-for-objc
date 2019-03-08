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

#import "MSIDAccount.h"
#import "MSIDClientInfo.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDIdTokenClaims.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDTokenResponse.h"
#import "MSIDClientInfo.h"
#import "MSIDClientInfo.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDAuthorityFactory.h"

@implementation MSIDAccount

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccount *item = [[self.class allocWithZone:zone] init];
    item->_accountIdentifier = [_accountIdentifier copyWithZone:zone];
    item->_localAccountId = [_localAccountId copyWithZone:zone];
    item->_accountType = _accountType;
    item->_authority = [_authority copyWithZone:zone];
    item->_username = [_username copyWithZone:zone];
    item->_givenName = [_givenName copyWithZone:zone];
    item->_middleName = [_middleName copyWithZone:zone];
    item->_familyName = [_familyName copyWithZone:zone];
    item->_name = [_name copyWithZone:zone];
    item->_clientInfo = [_clientInfo copyWithZone:zone];
    item->_alternativeAccountId = [_alternativeAccountId copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDAccount.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDAccount *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.accountIdentifier.displayableId.hash;
    hash = hash * 31 + self.accountType;
    hash = hash * 31 + self.authority.hash;
    hash = hash * 31 + self.alternativeAccountId.hash;
    hash = hash * 31 + self.username.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDAccount *)account
{
    if (!account)
    {
        return NO;
    }
    
    BOOL result = YES;

    if (self.accountIdentifier.homeAccountId && account.accountIdentifier.homeAccountId)
    {
        // In case we have 2 accounts in cache, but one of them doesn't have home account identifier,
        // we'll compare those accounts by legacy account ID instead to avoid duplicates being returned
        // due to presence of multiple caches
        result &= [self.accountIdentifier isEqual:account.accountIdentifier];
    }
    else
    {
        result &= [self.accountIdentifier.displayableId isEqual:account.accountIdentifier.displayableId];
    }

    result &= self.accountType == account.accountType;
    result &= (!self.alternativeAccountId && !account.alternativeAccountId) || [self.alternativeAccountId isEqualToString:account.alternativeAccountId];
    result &= (!self.authority && !account.authority) || [self.authority isEqual:account.authority];
    result &= (!self.username && !account.username) || [self.username isEqualToString:account.username];
    return result;
}

#pragma mark - Cache

- (instancetype)initWithAccountCacheItem:(MSIDAccountCacheItem *)cacheItem
{
    self = [super init];
    
    if (self)
    {
        if (!cacheItem)
        {
            return nil;
        }
        
        _accountType = cacheItem.accountType;
        _givenName = cacheItem.givenName;
        _familyName = cacheItem.familyName;
        _middleName = cacheItem.middleName;
        _name = cacheItem.name;
        _username = cacheItem.username;
        _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:cacheItem.username homeAccountId:cacheItem.homeAccountId];
        _clientInfo = cacheItem.clientInfo;
        _alternativeAccountId = cacheItem.alternativeAccountId;
        _localAccountId = cacheItem.localAccountId;

        NSString *environment = cacheItem.environment;
        NSString *tenant = cacheItem.realm;
        
        __auto_type authorityUrl = [NSURL msidURLWithEnvironment:environment tenant:tenant];
        _authority = [MSIDAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    }
    
    return self;
}

- (MSIDAccountCacheItem *)accountCacheItem
{
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] init];

    if (self.storageAuthority)
    {
        cacheItem.environment = self.storageAuthority.url.msidHostWithPortIfNecessary;
    }
    else
    {
        cacheItem.environment = self.authority.environment;
    }

    cacheItem.realm = self.authority.url.msidTenant;
    cacheItem.username = self.username;
    cacheItem.homeAccountId = self.accountIdentifier.homeAccountId;
    cacheItem.localAccountId = self.localAccountId;
    cacheItem.accountType = self.accountType;
    cacheItem.givenName = self.givenName;
    cacheItem.middleName = self.middleName;
    cacheItem.name = self.name;
    cacheItem.familyName = self.familyName;
    cacheItem.clientInfo = self.clientInfo;
    
    return cacheItem;
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"MSIDAccount authority: %@ username: %@ homeAccountId: %@ accountType: %@ localAccountId: %@",self.authority, self.username, self.accountIdentifier.homeAccountId, [MSIDAccountTypeHelpers accountTypeAsString:self.accountType], self.localAccountId];
}

@end
