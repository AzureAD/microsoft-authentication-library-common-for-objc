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

#import <XCTest/XCTest.h>
#import "MSIDCredentialCacheItem.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDBoundRefreshTokenCacheItem.h"

@interface MSIDCredentialCacheItemTests : XCTestCase

@end

@implementation MSIDCredentialCacheItemTests

#pragma mark - JSON serialization

- (void)testJSONDictionary_whenAccessToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.credentialType = MSIDAccessTokenType;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.realm = @"contoso.com";
    cacheItem.secret = DEFAULT_TEST_ACCESS_TOKEN;
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.enrollmentId = @"enrollmentId";
    cacheItem.redirectUri = @"msauth.com.microsoft.teams://auth";

    NSDate *expiresOn = [NSDate date];
    NSDate *refreshOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];

    cacheItem.cachedAt = cachedAt;
    cacheItem.expiresOn = expiresOn;
    cacheItem.refreshOn = refreshOn;
    cacheItem.extendedExpiresOn = extExpiresOn;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    cacheItem.speInfo = @"2";

    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *refreshOnString = [NSString stringWithFormat:@"%ld", (long)[refreshOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];

    NSDictionary *expectedDictionary = @{@"credential_type": @"AccessToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"target": DEFAULT_TEST_RESOURCE,
                                         @"cached_at": cachedAtString,
                                         @"expires_on": expiresOnString,
                                         @"refresh_on": refreshOnString,
                                         @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                         @"realm": @"contoso.com",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"extended_expires_on": extExpiresOnString,
                                         @"spe_info": @"2",
                                         @"home_account_id": @"uid.utid",
                                         @"enrollment_id": @"enrollmentId",
                                         @"redirect_uri": @"msauth.com.microsoft.teams://auth"
                                        };

    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);

}

- (void)testJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    NSDate *lastRecoveryTimestamp = [NSDate date];
    NSString *lastRecoveryAttemptString = [NSString stringWithFormat:@"%ld", (long)[lastRecoveryTimestamp timeIntervalSince1970]];
    
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.secret = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.familyId = DEFAULT_TEST_FAMILY_ID;
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.lastRecoveryAttempt = lastRecoveryTimestamp;
    cacheItem.recoveryAttemptCount = @"2";
    cacheItem.lastRecoveryAttemptFailed = @"NO";

    NSDictionary *expectedDictionary = @{@"credential_type": @"RefreshToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"family_id": DEFAULT_TEST_FAMILY_ID,
                                         @"home_account_id": @"uid.utid",
                                         @"recovery_attempted_at": lastRecoveryAttemptString,
                                         @"recovery_attempt_count": @"2",
                                         @"last_recovery_attempt_failed":@"NO"
                                         };

    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

- (void)testJSONDictionary_whenIDToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.credentialType = MSIDIDTokenType;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.secret = DEFAULT_TEST_ID_TOKEN;
    cacheItem.homeAccountId = @"uid.utid";

    NSDictionary *expectedDictionary = @{@"credential_type": @"IdToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_ID_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"contoso.com",
                                         @"home_account_id": @"uid.utid"
                                         };

    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAccessToken_andAllFieldsSet_shouldReturnAccessTokenCacheItem
{
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *cachedAt = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *extExpiresOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *refreshOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];

    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    NSString *refreshOnString = [NSString stringWithFormat:@"%ld", (long)[refreshOn timeIntervalSince1970]];

    NSDictionary *jsonDictionary = @{@"credential_type": @"AccessToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"target": DEFAULT_TEST_RESOURCE,
                                     @"cached_at": cachedAtString,
                                     @"expires_on": expiresOnString,
                                     @"extended_expires_on": extExpiresOnString,
                                     @"refresh_on": refreshOnString,
                                     @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                     @"realm": @"contoso.com",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"spe_info": @"2",
                                     @"test": @"test2",
                                     @"home_account_id": @"uid.utid",
                                     @"enrollment_id": @"enrollmentId",
                                     @"redirect_uri": @"msauth.com.microsoft.teams://auth"
                                     };

    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqual(cacheItem.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(cacheItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(cacheItem.extendedExpiresOn, extExpiresOn);
    XCTAssertEqualObjects(cacheItem.realm, @"contoso.com");
    XCTAssertEqualObjects(cacheItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(cacheItem.speInfo, @"2");
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(cacheItem.enrollmentId, @"enrollmentId");
    XCTAssertEqualObjects(cacheItem.redirectUri, @"msauth.com.microsoft.teams://auth");
}

- (void)testInitWithJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnRefreshTokenCacheItem
{
    NSDate *lastRecoveryTimestamp = [NSDate date];
    NSString *lastRecoveryAttemptString = [NSString stringWithFormat:@"%ld", (long)[lastRecoveryTimestamp timeIntervalSince1970]];
    
    NSDictionary *jsonDictionary = @{@"credential_type": @"RefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"family_id": DEFAULT_TEST_FAMILY_ID,
                                     @"home_account_id": @"uid.utid",
                                     @"recovery_attempted_at": lastRecoveryAttemptString,
                                     @"recovery_attempt_count": @"2"
                                     };

    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertNil(cacheItem.realm);
    XCTAssertEqual(cacheItem.credentialType, MSIDRefreshTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(cacheItem.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    
    NSTimeInterval interval = ABS([cacheItem.lastRecoveryAttempt timeIntervalSinceDate:lastRecoveryTimestamp]);
    XCTAssertTrue(interval < 1);
    XCTAssertNil(cacheItem.enrollmentId);
    XCTAssertEqualObjects(cacheItem.recoveryAttemptCount, @"2");
}

- (void)testInitWithJSONDictionary_whenIDToken_andAllFieldsSet_shouldReturnIDTokenCacheItem
{
    NSDictionary *jsonDictionary = @{@"credential_type": @"IdToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_ID_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"realm": @"contoso.com",
                                     @"home_account_id": @"uid.utid"
                                     };

    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqual(cacheItem.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(cacheItem.realm, @"contoso.com");
    XCTAssertNil(cacheItem.enrollmentId);
}

- (void)testInitWithJSONData_whenJSONDictionaryContainsNulls_shouldReturnTokenCacheItemWithMissingFields
{
    NSDictionary *corruptedJsonDictionary = @{@"credential_type": @"IdToken",
                                              @"client_id": DEFAULT_TEST_CLIENT_ID,
                                              @"secret": DEFAULT_TEST_ID_TOKEN,
                                              @"environment": DEFAULT_TEST_ENVIRONMENT,
                                              @"realm": @"contoso.com",
                                              @"home_account_id": @"uid.utid",
                                              @"family_id": [NSNull null]
                                              };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:corruptedJsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqual(cacheItem.credentialType, MSIDIDTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
    XCTAssertEqualObjects(cacheItem.realm, @"contoso.com");
    XCTAssertNil(cacheItem.enrollmentId);
    XCTAssertNil(cacheItem.familyId);
    XCTAssertFalse([[cacheItem familyId] isKindOfClass:[NSNull class]]);
    XCTAssertNil(cacheItem.redirectUri);
}

- (void)testEqualityForCredentialCacheItems_WhenEitherOfTheComparedPropertiesInTheObject_IsNil
{
    MSIDCredentialCacheItem *cacheItem1 = [MSIDCredentialCacheItem new];
    cacheItem1.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem1.credentialType = MSIDIDTokenType;
    cacheItem1.secret = DEFAULT_TEST_ID_TOKEN;
    cacheItem1.target = DEFAULT_TEST_RESOURCE;
    cacheItem1.realm = @"contoso.com";
    cacheItem1.environment = @"login.microsoftonline.com";
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];
    cacheItem1.expiresOn = expiresOn;
    cacheItem1.cachedAt = cachedAt;
    cacheItem1.homeAccountId = @"uid.utid";
    cacheItem1.familyId = DEFAULT_TEST_FAMILY_ID;
    cacheItem1.extendedExpiresOn = extExpiresOn;
    cacheItem1.speInfo = @"2";

    MSIDCredentialCacheItem *cacheItem2 = [MSIDCredentialCacheItem new];
    cacheItem2.credentialType = MSIDIDTokenType;
    cacheItem2.secret = DEFAULT_TEST_ID_TOKEN;
    cacheItem2.clientId = DEFAULT_TEST_CLIENT_ID;
    XCTAssertNotEqualObjects(cacheItem1, cacheItem2);
}

#pragma mark - MSIDBoundRefreshTokenCacheItem tests

- (void)testJSONDictionary_whenBoundRefreshToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDBoundRefreshTokenCacheItem *cacheItem = [MSIDBoundRefreshTokenCacheItem new];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.credentialType = MSIDBoundRefreshTokenType;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.secret = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.homeAccountId = @"uid.utid";
    cacheItem.boundDeviceId = @"test-device-id";

    NSDictionary *expectedDictionary = @{MSID_BOUND_DEVICE_ID_CACHE_KEY: @"test-device-id",
                                         @"credential_type": @"BoundRefreshToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"home_account_id": @"uid.utid"
                                         };
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

- (void)testInitWithJSONDictionary_whenBoundRefreshToken_andAllFieldsSet_shouldReturnBoundRefreshTokenCacheItem
{
    NSDictionary *jsonDictionary = @{MSID_BOUND_DEVICE_ID_CACHE_KEY: @"test-device-id",
                                     @"credential_type": @"BoundRefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"home_account_id": @"uid.utid"
                                     };
    NSError *error = nil;
    MSIDBoundRefreshTokenCacheItem *cacheItem = [[MSIDBoundRefreshTokenCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.boundDeviceId, @"test-device-id");
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqual(cacheItem.credentialType, MSIDBoundRefreshTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");
}

- (void)testInitWithJSONDictionary_whenBoundRefreshToken_andDeviceIDMissing_shouldReturnNilItem
{
    NSDictionary *jsonDictionary = @{@"credential_type": @"BoundRefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"home_account_id": @"uid.utid"
                                     };
    NSError *error = nil;
    MSIDBoundRefreshTokenCacheItem *cacheItem = [[MSIDBoundRefreshTokenCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(cacheItem);
    XCTAssertNotNil(error);
    XCTAssertTrue([error.description containsString:@"Bound device ID is nil"]);
}

- (void)testInitWithJSONDictionary_whenBoundRefreshToken_missingSecret_shouldReturnError
{
    NSDictionary *jsonDictionary = @{MSID_BOUND_DEVICE_ID_CACHE_KEY: @"test-device-id",
                                     @"credential_type": @"BoundRefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"home_account_id": @"uid.utid"
                                     };
    NSError *error = nil;
    MSIDBoundRefreshTokenCacheItem *cacheItem = [[MSIDBoundRefreshTokenCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(cacheItem);
}

- (void)testInitWithJSONDictionary_whenBoundRefreshToken_missingDeviceId_shouldReturnError
{
    NSDictionary *jsonDictionary = @{@"credential_type": @"BoundRefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"home_account_id": @"uid.utid"
                                     };
    NSError *error = nil;
    MSIDBoundRefreshTokenCacheItem *cacheItem = [[MSIDBoundRefreshTokenCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(cacheItem);
    XCTAssertNotNil(error);
    XCTAssertTrue([error.description containsString:@"Bound device ID is nil"]);
}

- (void)testIsEqualToItem_whenBoundDeviceIdNilAndEqual_shouldBeEqual
{
    MSIDBoundRefreshTokenCacheItem *item1 = [MSIDBoundRefreshTokenCacheItem new];
    item1.boundDeviceId = nil;
    item1.clientId = DEFAULT_TEST_CLIENT_ID;
    item1.credentialType = MSIDBoundRefreshTokenType;
    item1.secret = DEFAULT_TEST_REFRESH_TOKEN;
    MSIDBoundRefreshTokenCacheItem *item2 = [MSIDBoundRefreshTokenCacheItem new];
    item2.boundDeviceId = nil;
    item2.clientId = DEFAULT_TEST_CLIENT_ID;
    item2.credentialType = MSIDBoundRefreshTokenType;
    item2.secret = DEFAULT_TEST_REFRESH_TOKEN;
    XCTAssertEqualObjects(item1, item2);
}

- (void)testHash_whenBoundDeviceIdIsNil_shouldNotCrash
{
    MSIDBoundRefreshTokenCacheItem *item = [MSIDBoundRefreshTokenCacheItem new];
    item.boundDeviceId = nil;
    XCTAssertNoThrow([item hash]);
}

- (void)testCopyWithZone_shouldCopyBoundDeviceId
{
    MSIDBoundRefreshTokenCacheItem *item = [MSIDBoundRefreshTokenCacheItem new];
    item.boundDeviceId = @"copy-device-id";
    item.secret = DEFAULT_TEST_REFRESH_TOKEN;
    MSIDBoundRefreshTokenCacheItem *copy = [item copy];
    XCTAssertEqualObjects(item.boundDeviceId, copy.boundDeviceId);
    item.boundDeviceId = @"new-device-id";
    XCTAssertFalse(item.boundDeviceId == copy.boundDeviceId); // Should be a copy
}

- (void)testDescription_shouldIncludeBoundDeviceId
{
    MSIDBoundRefreshTokenCacheItem *item = [MSIDBoundRefreshTokenCacheItem new];
    item.boundDeviceId = @"desc-device-id";
    NSString *desc = [item description];
    XCTAssertTrue([desc containsString:@"desc-device-id"]);
}

- (void)testSecureCoding_roundTrip_withNilDeviceId_shouldPreserveNil
{
    MSIDBoundRefreshTokenCacheItem *item = [MSIDBoundRefreshTokenCacheItem new];
    item.boundDeviceId = nil;
    item.clientId = DEFAULT_TEST_CLIENT_ID;
    item.credentialType = MSIDBoundRefreshTokenType;
    item.secret = DEFAULT_TEST_REFRESH_TOKEN;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item requiringSecureCoding:YES error:nil];
    MSIDBoundRefreshTokenCacheItem *decodedItem = [NSKeyedUnarchiver unarchivedObjectOfClass:[MSIDBoundRefreshTokenCacheItem class] fromData:data error:nil];
    XCTAssertNil(decodedItem.boundDeviceId);
}

- (void)testSecureCoding_roundTrip_shouldPreserveDeviceID
{
    MSIDBoundRefreshTokenCacheItem *item = [MSIDBoundRefreshTokenCacheItem new];
    item.boundDeviceId = @"secure-device-id";
    item.clientId = DEFAULT_TEST_CLIENT_ID;
    item.credentialType = MSIDBoundRefreshTokenType;
    item.secret = DEFAULT_TEST_REFRESH_TOKEN;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item requiringSecureCoding:YES error:nil];
    XCTAssertNotNil(data);
    MSIDBoundRefreshTokenCacheItem *decodedItem = [NSKeyedUnarchiver unarchivedObjectOfClass:[MSIDBoundRefreshTokenCacheItem class] fromData:data error:nil];
    XCTAssertEqualObjects(decodedItem.boundDeviceId, @"secure-device-id");
    XCTAssertEqualObjects(decodedItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqual(decodedItem.credentialType, MSIDBoundRefreshTokenType);
    XCTAssertEqualObjects(decodedItem.boundRefreshToken, DEFAULT_TEST_REFRESH_TOKEN);
}

@end
