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
#import "MSIDIdTokenWrapper.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"

@implementation MSIDAccount

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccount *item = [[self.class allocWithZone:zone] init];
    item->_legacyUserId = [_legacyUserId copyWithZone:zone];
    item->_uid = [_uid copyWithZone:zone];
    item->_utid = [_utid copyWithZone:zone];
    item->_firstName = [_firstName copyWithZone:zone];
    item->_lastName = [_lastName copyWithZone:zone];
    item->_username = [_username copyWithZone:zone];
    item->_accountType = _accountType;
    
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
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.legacyUserId.hash;
    hash = hash * 31 + self.uid.hash;
    hash = hash * 31 + self.utid.hash;
    hash = hash * 31 + self.firstName.hash;
    hash = hash * 31 + self.lastName.hash;
    hash = hash * 31 + self.accountType;
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
    result &= (!self.legacyUserId && !account.legacyUserId) || [self.legacyUserId isEqualToString:account.legacyUserId];
    result &= (!self.uid && !account.uid) || [self.uid isEqualToString:account.uid];
    result &= (!self.utid && !account.utid) || [self.utid isEqualToString:account.utid];
    result &= (!self.firstName && !account.firstName) || [self.firstName isEqualToString:account.firstName];
    result &= (!self.lastName && !account.lastName) || [self.lastName isEqualToString:account.lastName];
    result &= (!self.username && !account.username) || [self.username isEqualToString:account.username];
    result &= (!self.userIdentifier && !account.userIdentifier) || [self.userIdentifier isEqualToString:account.userIdentifier];
    result &= self.accountType == account.accountType;
    
    return result;
}

#pragma mark - Init

- (instancetype)init
{
    return [self initWithLegacyUserId:nil
                                 utid:nil
                                  uid:nil];
}

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                                utid:(NSString *)utid
                                 uid:(NSString *)uid
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self->_legacyUserId = legacyUserId;
    self->_utid = utid;
    self->_uid = uid;
    
    if (uid && utid)
    {
        self->_userIdentifier = [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
    }

    return self;
}

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
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
    self->_legacyUserId = userId;
    self->_utid = utid;
    self->_uid = uid;
    self->_userIdentifier = [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
    self->_firstName = response.idTokenObj.givenName;
    self->_lastName = response.idTokenObj.familyName;
    
    return self;
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
        
        _legacyUserId = cacheItem.legacyUserIdentifier;
        _accountType = cacheItem.accountType;
        _firstName = cacheItem.firstName;
        _lastName = cacheItem.lastName;
        _authority = cacheItem.authority;
        _username = cacheItem.username;
        _userIdentifier = cacheItem.uniqueUserId;
    }
    
    return self;
}

- (MSIDAccountCacheItem *)accountCacheItem
{
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] init];
    cacheItem.authority = self.authority;
    cacheItem.username = self.username;
    cacheItem.uniqueUserId = self.userIdentifier;
    cacheItem.legacyUserIdentifier = self.legacyUserId;
    cacheItem.accountType = self.accountType;
    cacheItem.firstName = self.firstName;
    cacheItem.lastName = self.lastName;
    
    return cacheItem;
}

@end
