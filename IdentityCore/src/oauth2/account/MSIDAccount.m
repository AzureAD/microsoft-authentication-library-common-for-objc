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
#import "MSIDClientInfo.h"

@implementation MSIDAccount

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAccount *item = [[self.class allocWithZone:zone] init];
    item->_legacyUserId = [_legacyUserId copyWithZone:zone];
    item->_clientInfo = [_clientInfo copyWithZone:zone];
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
    hash = hash * 31 + self.clientInfo.rawClientInfo.hash;
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
    result &= (!self.clientInfo.rawClientInfo && !account.clientInfo.rawClientInfo) || [self.clientInfo.rawClientInfo isEqualToString:account.clientInfo.rawClientInfo];
    result &= (!self.firstName && !account.firstName) || [self.firstName isEqualToString:account.firstName];
    result &= (!self.lastName && !account.lastName) || [self.lastName isEqualToString:account.lastName];
    result &= (!self.username && !account.username) || [self.username isEqualToString:account.username];
    result &= (!self.userIdentifier && !account.userIdentifier) || [self.userIdentifier isEqualToString:account.userIdentifier];
    result &= self.accountType == account.accountType;
    
    return result;
}

#pragma mark - Init

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                          clientInfo:(MSIDClientInfo *)clientInfo
{
    self = [self initWithLegacyUserId:legacyUserId
                         uniqueUserId:clientInfo.userIdentifier];
    
    if (self)
    {
        _clientInfo = clientInfo;
    }
    
    return self;
}

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                        uniqueUserId:(NSString *)userIdentifier
{
    if (!(self = [self init]))
    {
        return nil;
    }
    
    _legacyUserId = legacyUserId;
    _userIdentifier = userIdentifier;
    
    return self;
}

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
{
    if (!(self = [self init]))
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
    _legacyUserId = userId;
    if (uid && utid)
    {
        _userIdentifier = [NSString stringWithFormat:@"%@.%@", uid, utid];
    }
    _username = response.idTokenObj.preferredUsername; // TODO: Is it correct?
    _firstName = response.idTokenObj.givenName;
    _lastName = response.idTokenObj.familyName;
    // TODO: should we put middle name as well?
    _authority = requestParams.authority;
    _accountType = response.accountType;
    
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
