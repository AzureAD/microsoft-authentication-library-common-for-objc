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

#import "MSIDCredentialCacheItem.h"
#import "MSIDUserInformation.h"
#import "MSIDCredentialType.h"
#import "NSDate+MSIDExtensions.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDIdTokenClaims.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDIdToken.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDClientInfo.h"

@interface MSIDCredentialCacheItem()

@property (readwrite) NSDictionary *json;

@end

@implementation MSIDCredentialCacheItem

#pragma mark - MSIDCacheItem

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

    return [self isEqualToItem:(MSIDCredentialCacheItem *)object];
}

- (BOOL)isEqualToItem:(MSIDCredentialCacheItem *)item
{
    BOOL result = YES;
    result &= (!self.clientId || !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= self.credentialType == item.credentialType;
    result &= (!self.secret || !item.secret) || [self.secret isEqualToString:item.secret];
    result &= (!self.target || !item.target) || [self.target isEqualToString:item.target];
    result &= (!self.realm || !item.realm) || [self.realm isEqualToString:item.realm];
    result &= (!self.environment || !item.environment) || [self.environment isEqualToString:item.environment];
    result &= (!self.expiresOn || !item.expiresOn) || [self.expiresOn isEqual:item.expiresOn];
    result &= (!self.cachedAt || !item.cachedAt) || [self.cachedAt isEqual:item.cachedAt];
    result &= (!self.familyId || !item.familyId) || [self.familyId isEqualToString:item.familyId];
    result &= (!self.homeAccountId || !item.homeAccountId) || [self.homeAccountId isEqualToString:item.homeAccountId];
    result &= (!self.additionalInfo || !item.additionalInfo) || [self.additionalInfo isEqual:item.additionalInfo];
    result &= (!self.applicationIdentifier || !item.applicationIdentifier) || [self.applicationIdentifier isEqualToString:item.applicationIdentifier];
    return result;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.credentialType;
    hash = hash * 31 + self.secret.hash;
    hash = hash * 31 + self.target.hash;
    hash = hash * 31 + self.realm.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.expiresOn.hash;
    hash = hash * 31 + self.cachedAt.hash;
    hash = hash * 31 + self.familyId.hash;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.additionalInfo.hash;
    hash = hash * 31 + self.applicationIdentifier.hash;
    return hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDCredentialCacheItem *item = [[self class] allocWithZone:zone];
    item.clientId = [self.clientId copyWithZone:zone];
    item.credentialType = self.credentialType;
    item.secret = [self.secret copyWithZone:zone];
    item.target = [self.target copyWithZone:zone];
    item.realm = [self.realm copyWithZone:zone];
    item.environment = [self.environment copyWithZone:zone];
    item.expiresOn = [self.expiresOn copyWithZone:zone];
    item.cachedAt = [self.cachedAt copyWithZone:zone];
    item.familyId = [self.familyId copyWithZone:zone];
    item.homeAccountId = [self.homeAccountId copyWithZone:zone];
    item.additionalInfo = [self.additionalInfo copyWithZone:zone];
    item.enrollmentId = [self.enrollmentId copyWithZone:zone];
    item.applicationIdentifier = [self.applicationIdentifier copyWithZone:zone];
    return item;
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super init]))
    {
        return nil;
    }

    if (!json)
    {
        MSID_LOG_WARN(nil, @"Tried to decode a credential cache item from nil json");
        return nil;
    }

    _json = json;

    _clientId = [json msidStringObjectForKey:MSID_CLIENT_ID_CACHE_KEY];
    _credentialType = [MSIDCredentialTypeHelpers credentialTypeFromString:[json msidStringObjectForKey:MSID_CREDENTIAL_TYPE_CACHE_KEY]];
    _secret = [json msidStringObjectForKey:MSID_TOKEN_CACHE_KEY];

    if (!_secret)
    {
        MSID_LOG_WARN(nil, @"No secret present in the credential");
        return nil;
    }

    _target = [json msidStringObjectForKey:MSID_TARGET_CACHE_KEY];
    _realm = [json msidStringObjectForKey:MSID_REALM_CACHE_KEY];
    _environment = [json msidStringObjectForKey:MSID_ENVIRONMENT_CACHE_KEY];
    _expiresOn = [NSDate msidDateFromTimeStamp:[json msidStringObjectForKey:MSID_EXPIRES_ON_CACHE_KEY]];
    _cachedAt = [NSDate msidDateFromTimeStamp:[json msidStringObjectForKey:MSID_CACHED_AT_CACHE_KEY]];
    _familyId = [json msidStringObjectForKey:MSID_FAMILY_ID_CACHE_KEY];
    _homeAccountId = [json msidStringObjectForKey:MSID_HOME_ACCOUNT_ID_CACHE_KEY];

    // Additional Info
    NSString *speInfo = [json msidStringObjectForKey:MSID_SPE_INFO_CACHE_KEY];
    NSDate *extendedExpiresOn = [NSDate msidDateFromTimeStamp:[json msidStringObjectForKey:MSID_EXTENDED_EXPIRES_ON_CACHE_KEY]];
    
    NSMutableDictionary *additionalInfo = [NSMutableDictionary dictionary];
    additionalInfo[MSID_SPE_INFO_CACHE_KEY] = speInfo;
    additionalInfo[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY] = extendedExpiresOn;
    _additionalInfo = additionalInfo;
    
    _enrollmentId = [json msidStringObjectForKey:MSID_ENROLLMENT_ID_CACHE_KEY];
    _applicationIdentifier = [json msidStringObjectForKey:MSID_APPLICATION_IDENTIFIER_CACHE_KEY];
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    if (_json)
    {
        [dictionary addEntriesFromDictionary:_json];
    }

    dictionary[MSID_CLIENT_ID_CACHE_KEY] = _clientId;
    dictionary[MSID_CREDENTIAL_TYPE_CACHE_KEY] = [MSIDCredentialTypeHelpers credentialTypeAsString:self.credentialType];
    dictionary[MSID_TOKEN_CACHE_KEY] = _secret;
    dictionary[MSID_TARGET_CACHE_KEY] = _target;
    dictionary[MSID_REALM_CACHE_KEY] = _realm;
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = _environment;
    dictionary[MSID_EXPIRES_ON_CACHE_KEY] = _expiresOn.msidDateToTimestamp;
    dictionary[MSID_CACHED_AT_CACHE_KEY] = _cachedAt.msidDateToTimestamp;
    dictionary[MSID_FAMILY_ID_CACHE_KEY] = _familyId;
    dictionary[MSID_HOME_ACCOUNT_ID_CACHE_KEY] = _homeAccountId;
    dictionary[MSID_SPE_INFO_CACHE_KEY] = _additionalInfo[MSID_SPE_INFO_CACHE_KEY];
    dictionary[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY] = [_additionalInfo[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY] msidDateToTimestamp];
    dictionary[MSID_ENROLLMENT_ID_CACHE_KEY] = _enrollmentId;
    dictionary[MSID_APPLICATION_IDENTIFIER_CACHE_KEY] = _applicationIdentifier;
    return dictionary;
}

#pragma mark - Helpers

- (MSIDBaseToken *)tokenWithType:(MSIDCredentialType)credentialType
{
    switch (credentialType)
    {
        case MSIDAccessTokenType:
        {
            return [[MSIDAccessToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDRefreshTokenType:
        {
            return [[MSIDRefreshToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDLegacySingleResourceTokenType:
        {
            return [[MSIDLegacySingleResourceToken alloc] initWithTokenCacheItem:self];
        }
        case MSIDIDTokenType:
        {
            return [[MSIDIdToken alloc] initWithTokenCacheItem:self];
        }
        default:
            return [[MSIDBaseToken alloc] initWithTokenCacheItem:self];
    }
    
    return nil;
}

- (BOOL)matchesTarget:(NSString *)target comparisonOptions:(MSIDComparisonOptions)comparisonOptions
{
    if (!target)
    {
        return YES;
    }

    switch (comparisonOptions) {
        case MSIDExactStringMatch:
            return [self.target isEqualToString:target];
        case MSIDSubSet:
            return [[target msidScopeSet] isSubsetOfOrderedSet:[self.target msidScopeSet]];
        case MSIDIntersect:
            return [[target msidScopeSet] intersectsOrderedSet:[self.target msidScopeSet]];
        default:
            return NO;
    }

    return NO;
}

- (BOOL)matchesWithHomeAccountId:(nullable NSString *)homeAccountId
                     environment:(nullable NSString *)environment
              environmentAliases:(nullable NSArray<NSString *> *)environmentAliases
{
    if (homeAccountId && ![self.homeAccountId isEqualToString:homeAccountId])
    {
        return NO;
    }

    return [self matchByEnvironment:environment environmentAliases:environmentAliases];
}

- (BOOL)matchByEnvironment:(nullable NSString *)environment
        environmentAliases:(nullable NSArray<NSString *> *)environmentAliases
{
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

- (BOOL)matchesWithRealm:(nullable NSString *)realm
                clientId:(nullable NSString *)clientId
                familyId:(nullable NSString *)familyId
                  target:(nullable NSString *)target
          targetMatching:(MSIDComparisonOptions)matchingOptions
        clientIdMatching:(MSIDComparisonOptions)clientIDMatchingOptions
{
    if (realm && ![self.realm isEqualToString:realm])
    {
        return NO;
    }

    if (![self matchesTarget:target comparisonOptions:matchingOptions])
    {
        return NO;
    }

    if (!clientId && !familyId)
    {
        return YES;
    }

    if (clientIDMatchingOptions == MSIDSuperSet)
    {
        if ((clientId && [self.clientId isEqualToString:clientId])
            || (familyId && [self.familyId isEqualToString:familyId]))
        {
            return YES;
        }

        return NO;
    }
    else
    {
        if (clientId && ![self.clientId isEqualToString:clientId])
        {
            return NO;
        }

        if (familyId && ![self.familyId isEqualToString:familyId])
        {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isTombstone
{
    return [self.secret isEqualToString:@"<tombstone>"];
}

@end
