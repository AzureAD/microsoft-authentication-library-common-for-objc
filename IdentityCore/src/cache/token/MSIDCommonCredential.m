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

#import <Foundation/Foundation.h>
#import "MSIDClientInfo.h"
#import "MSIDCommonCredential.h"
#import "MSIDCommonLogger.h"
#import "MSIDCommonStorageConstants.h"
#import "MSIDCredentialType.h"
#import "NSDate+MSIDExtensions.h"

@interface MSIDCommonCredential ()

@property (readwrite) NSDictionary *json;

@end

@implementation MSIDCommonCredential

- (nullable instancetype)init {
    self = [super init];
    if (self) {
        // defaults...
    }

    return self;
}

- (nullable instancetype)initWithType:(MSIDCredentialType)credentialType
                        homeAccountId:(nonnull NSString *)homeAccountId
                          environment:(nonnull NSString *)environment
                                realm:(nullable NSString *)realm
                             clientId:(nullable NSString *)clientId
                               target:(nullable NSString *)target
                             cachedAt:(nullable NSDate *)cachedAt
                            expiresOn:(nullable NSDate *)expiresOn
                    extendedExpiresOn:(nullable NSDate *)extendedExpiresOn
                               secret:(nullable NSString *)secret
                             familyId:(nullable NSString *)familyId
                           clientInfo:(nullable MSIDClientInfo *)clientInfo
                     additionalFields:(nullable NSDictionary *)additionalFields {
    MSID_TRACE;

    _credentialType = credentialType;
    _homeAccountId = homeAccountId;
    _environment = environment;
    _realm = realm;
    _clientId = clientId;
    _target = target;
    _cachedAt = cachedAt;
    _expiresOn = expiresOn;
    _extendedExpiresOn = extendedExpiresOn;
    _secret = secret;
    _familyId = familyId;
    _clientInfo = clientInfo;
    _additionalFields = additionalFields;

    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:self.class]) {
        return NO;
    }

    return [self isEqualToItem:(MSIDCommonCredential *)object];
}

- (BOOL)isEqualToItem:(MSIDCommonCredential *)item {
    BOOL result = (_credentialType == item.credentialType)
        && (_clientId == item.clientId || [_clientId isEqualToString:item.clientId])
        && (_secret == item.secret || [_secret isEqualToString:item.secret])
        && (_target == item.target || [_target isEqualToString:item.target])
        && (_realm == item.realm || [_realm isEqualToString:item.realm])
        && (_environment == item.environment || [_environment isEqualToString:item.environment])
        && (_expiresOn == item.expiresOn || [_expiresOn isEqual:item.expiresOn])
        && (_extendedExpiresOn == item.extendedExpiresOn || [_extendedExpiresOn isEqual:item.extendedExpiresOn])
        && (_cachedAt == item.cachedAt || [_cachedAt isEqual:item.cachedAt])
        && (_familyId == item.familyId || [_familyId isEqualToString:item.familyId])
        && (_homeAccountId == item.homeAccountId || [_homeAccountId isEqualToString:item.homeAccountId])
        && (_clientInfo == item.clientInfo || [_clientInfo.rawClientInfo isEqualToString:item.clientInfo.rawClientInfo])
        && (_additionalFields == item.additionalFields || [_additionalFields isEqual:item.additionalFields]);
    return result;
}

#pragma mark - NSObject

- (NSUInteger)hash {
    NSUInteger hash = [super hash];
    hash = hash * 31 + _clientId.hash;
    hash = hash * 31 + _credentialType;
    hash = hash * 31 + _secret.hash;
    hash = hash * 31 + _target.hash;
    hash = hash * 31 + _realm.hash;
    hash = hash * 31 + _environment.hash;
    hash = hash * 31 + _expiresOn.hash;
    hash = hash * 31 + _extendedExpiresOn.hash;
    hash = hash * 31 + _cachedAt.hash;
    hash = hash * 31 + _familyId.hash;
    hash = hash * 31 + _homeAccountId.hash;
    hash = hash * 31 + _clientInfo.hash;
    hash = hash * 31 + _additionalFields.hash;
    return hash;
}

#pragma mark - NSCopying

- (nonnull instancetype)copyWithZone:(NSZone *)zone {
    MSIDCommonCredential *item = [[self class] allocWithZone:zone];
    item.clientId = [_clientId copyWithZone:zone];
    item.credentialType = _credentialType;
    item.secret = [_secret copyWithZone:zone];
    item.target = [_target copyWithZone:zone];
    item.realm = [_realm copyWithZone:zone];
    item.environment = [_environment copyWithZone:zone];
    item.expiresOn = [_expiresOn copyWithZone:zone];
    item.extendedExpiresOn = [_extendedExpiresOn copyWithZone:zone];
    item.cachedAt = [_cachedAt copyWithZone:zone];
    item.familyId = [_familyId copyWithZone:zone];
    item.homeAccountId = [_homeAccountId copyWithZone:zone];
    item.clientInfo = [_clientInfo copyWithZone:zone];
    item.additionalFields = [_additionalFields copyWithZone:zone];
    return item;
}

#pragma mark - JSON

- (nullable instancetype)initWithJSONDictionary:(NSDictionary *)json error:(__unused NSError **)error {
    MSID_TRACE;
    if (!(self = [super init])) {
        return nil;
    }

    if (!json) {
        MSID_LOG_WARN(nil, @"Tried to decode a credential cache item from nil json");
        return nil;
    }

    _json = json;

    _clientId = json[MSID_CLIENT_ID_CACHE_KEY];
    _credentialType = [MSIDCredentialTypeHelpers credentialTypeFromString:json[MSID_CREDENTIAL_TYPE_CACHE_KEY]];
    _secret = json[MSID_TOKEN_CACHE_KEY];

    if (!_secret) {
        MSID_LOG_WARN(nil, @"No secret present in the credential");
        return nil;
    }

    _target = json[MSID_TARGET_CACHE_KEY];
    _realm = json[MSID_REALM_CACHE_KEY];
    _environment = json[MSID_ENVIRONMENT_CACHE_KEY];

    _expiresOn = [NSDate msidDateFromTimeStamp:json[MSID_EXPIRES_ON_CACHE_KEY]];
    _cachedAt = [NSDate msidDateFromTimeStamp:json[MSID_CACHED_AT_CACHE_KEY]];
    _extendedExpiresOn = [NSDate msidDateFromTimeStamp:json[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY]];

    _familyId = json[MSID_FAMILY_ID_CACHE_KEY];
    _homeAccountId = json[MSID_HOME_ACCOUNT_ID_CACHE_KEY];
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:json[MSID_CLIENT_INFO_CACHE_KEY] error:nil];

    // Additional Fields
    NSString *speInfo = json[MSID_SPE_INFO_CACHE_KEY];
    NSMutableDictionary *additionalFields = [NSMutableDictionary dictionary];
    additionalFields[MSID_SPE_INFO_CACHE_KEY] = speInfo;
    if ([additionalFields count]) {
        _additionalFields = additionalFields;
    }

    return self;
}

- (nonnull NSDictionary *)jsonDictionary {
    MSID_TRACE;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    if (_json) {
        [dictionary addEntriesFromDictionary:_json];
    }

    if (_additionalFields) {
        [dictionary addEntriesFromDictionary:_additionalFields];
    }

    dictionary[MSID_CLIENT_ID_CACHE_KEY] = _clientId;
    dictionary[MSID_CREDENTIAL_TYPE_CACHE_KEY] = [MSIDCredentialTypeHelpers credentialTypeAsString:_credentialType];
    dictionary[MSID_TOKEN_CACHE_KEY] = _secret;
    dictionary[MSID_TARGET_CACHE_KEY] = _target;
    dictionary[MSID_REALM_CACHE_KEY] = _realm;
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = _environment;
    dictionary[MSID_EXPIRES_ON_CACHE_KEY] = _expiresOn.msidDateToTimestamp;
    dictionary[MSID_CACHED_AT_CACHE_KEY] = _cachedAt.msidDateToTimestamp;
    dictionary[MSID_EXTENDED_EXPIRES_ON_CACHE_KEY] = _extendedExpiresOn.msidDateToTimestamp;
    dictionary[MSID_FAMILY_ID_CACHE_KEY] = _familyId;
    dictionary[MSID_HOME_ACCOUNT_ID_CACHE_KEY] = _homeAccountId;
    dictionary[MSID_CLIENT_INFO_CACHE_KEY] = _clientInfo.rawClientInfo;
    dictionary[MSID_SPE_INFO_CACHE_KEY] = _additionalFields[MSID_SPE_INFO_CACHE_KEY];
    return dictionary;
}

@end
