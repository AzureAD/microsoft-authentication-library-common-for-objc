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
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDPrimaryRefreshToken.h"
#import "MSIDPRTCacheItem.h"
#import "MSIDPrimaryRefreshToken.h"

@interface MSIDPrimaryRefreshTokenTests : XCTestCase

@end

@implementation MSIDPrimaryRefreshTokenTests

- (void)testIsDevicelessPRT_whenOldPRTWithDeviceId_shouldReturnNO
{
    MSIDPrimaryRefreshToken *prt = [self createToken];
    prt.prtProtocolVersion = nil;
    prt.deviceID = @"deviceId";
    
    BOOL result = [prt isDevicelessPRT];
    XCTAssertFalse(result);
}

- (void)testIsDevicelessPRT_whenOldPRTWithoutDeviceId_shouldReturnNO
{
    MSIDPrimaryRefreshToken *prt = [self createToken];
    prt.prtProtocolVersion = nil;
    prt.deviceID = nil;
    
    BOOL result = [prt isDevicelessPRT];
    XCTAssertFalse(result);
}

- (void)testIsDevicelessPRT_whenNewPRTWithDevice_shouldReturnNO
{
    MSIDPrimaryRefreshToken *prt = [self createToken];
    prt.prtProtocolVersion = @"3.0";
    prt.deviceID = @"deviceId";
    
    BOOL result = [prt isDevicelessPRT];
    XCTAssertFalse(result);
}

- (void)testIsDevicelessPRT_whenNewPRTWithoutDevice_shouldReturnYES
{
    MSIDPrimaryRefreshToken *prt = [self createToken];
    prt.prtProtocolVersion = @"3.0";
    prt.deviceID = nil;
    
    BOOL result = [prt isDevicelessPRT];
    XCTAssertTrue(result);
}

- (void)testShouldRefreshToken_whenNoExpiryDate_shouldReturnYES
{
    MSIDPrimaryRefreshToken *token = [self createToken];
    token.expiresOn = nil;
    XCTAssertTrue([token shouldRefreshWithInterval:3600]);
}

- (void)testShouldRefreshToken_whenCloseToExpiry_shouldReturnYES
{
    MSIDPrimaryRefreshToken *token = [self createToken];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:300];
    XCTAssertTrue([token shouldRefreshWithInterval:3600]);
}

- (void)testShouldRefreshToken_whenRecentlyRefreshed_shouldReturnNO
{
    MSIDPrimaryRefreshToken *token = [self createToken];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:10200];
    token.cachedAt = [NSDate date];
    XCTAssertFalse([token shouldRefreshWithInterval:3600]);
}

- (void)testShouldRefreshToken_whenNotRecentlyRefreshed_shouldReturnYES
{
    MSIDPrimaryRefreshToken *token = [self createToken];
    token.expiresOn = [[NSDate date] dateByAddingTimeInterval:10200];
    token.cachedAt = [[NSDate date] dateByAddingTimeInterval:-7200];
    XCTAssertTrue([token shouldRefreshWithInterval:3600]);
}

- (void)testPRTProtocolUpgrade_whenOlderThanMinRequired_shouldUpgradeToMinRequired
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"2.3"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertEqualObjects(prt.prtProtocolVersion, @"3.0");
}

- (void)testPRTProtocolUpgrade_whenNewerThanMinRequired_shouldKeepCurrentVersion
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertEqualObjects(prt.prtProtocolVersion, @"3.8");
}

- (void)testPRTRecovery_whenRecoveryAttemptCountIsIncremented_shouldReturnRecoveryAttemptCount
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8",
                           @"recovery_attempt_count":@"2"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertEqual(prt.recoveryAttemptCount, 2);
}

- (void)testPRTRecovery_whenRecoveryAttemptCountFailedIsPresent_shouldReturnRecoveryAttemptFailed
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8",
                           @"last_recovery_attempt_failed":@"YES"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertTrue(prt.lastRecoveryAttemptFailed);
}

- (void)testPRTRecovery_whenRecoveryAttemptCountFailedIsFalse_shouldReturnRecoveryAttemptFailedNo
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8",
                           @"last_recovery_attempt_failed":@"NO"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertFalse(prt.lastRecoveryAttemptFailed);
}

- (void)testPRTRecovery_whenRecoveryAttemptCountFailedNotPresent_shouldReturnRecoveryAttemptFailedNo
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertFalse(prt.lastRecoveryAttemptFailed);
}

- (void)testPRTRecovery_whenRecoveryAttemptCountNotPresent_shouldReturnRecoveryAttemptCountZero
{
    NSDictionary *json = @{@"client_id": @"broker_client",
                           @"credential_type": @"PrimaryRefreshToken",
                           @"environment": @"login.microsoftonline.com",
                           @"home_account_id": @"uid.utid",
                           @"secret": @"my_primary_refresh_token",
                           @"session_key": @"2dMbNp4jXgjAy7Prjfa0Wm8nfFAGPHH2wJ1VaIVlNlU",
                           @"prt_protocol_version": @"3.8"
                           };
    MSIDPRTCacheItem *prtCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:json error:nil];
    MSIDPrimaryRefreshToken *prt = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:prtCacheItem];
    
    XCTAssertEqual(prt.recoveryAttemptCount, 0);
}

- (void)testSerializeDeserialize_whenExternalKeyTypeIsSetToNonDefault_shouldReturnCorrectInfo
{
    // Create MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT = [self createToken];
    primaryRT.externalKeyLocationType = MSIDExternalPRTKeyLocationTypeSSO;
    primaryRT.sessionKey = nil;
    
    // Convert MSIDPrimaryRefreshToken to cache item
    MSIDPRTCacheItem *cacheItem = (MSIDPRTCacheItem *) primaryRT.tokenCacheItem;
    XCTAssertEqual(cacheItem.externalKeyLocationType, primaryRT.externalKeyLocationType);
    
    // Convert cache item to JSON
    NSDictionary *serializedCacheItem = [cacheItem jsonDictionary];
    XCTAssertEqualObjects(serializedCacheItem[MSID_PRT_EXTERNAL_KEY_TYPE_CACHE_KEY], @"2");
    
    // Convert JSON back to cache item
    NSError *error;
    MSIDPRTCacheItem *deserializedCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:serializedCacheItem error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(deserializedCacheItem);
    XCTAssertEqual(deserializedCacheItem.externalKeyLocationType, primaryRT.externalKeyLocationType);
    
    // Convert cache item to archived data
    NSData *encodedCacheItem = [NSKeyedArchiver archivedDataWithRootObject:deserializedCacheItem requiringSecureCoding:YES error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(encodedCacheItem);
    
    // Convert archived data back to cache item
    MSIDPRTCacheItem *deserializedCacheItem2 = [NSKeyedUnarchiver unarchivedObjectOfClass:[MSIDPRTCacheItem  class] fromData:encodedCacheItem error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(deserializedCacheItem2);
    XCTAssertEqual(deserializedCacheItem2.externalKeyLocationType, primaryRT.externalKeyLocationType);
    
    // Convert deserialized cache data back to MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT2 = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:deserializedCacheItem];
    XCTAssertEqual(primaryRT2.externalKeyLocationType, primaryRT.externalKeyLocationType);
}

- (void)testSerializeDeserialize_shouldReturnCorrectInfoForRecovery
{
    //  Recovery count 1 and recovery attempt failed value is NO
    // Create MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT = [self createToken];
    primaryRT.recoveryAttemptCount = 1;
    primaryRT.lastRecoveryAttemptFailed = NO;
    
    // Convert MSIDPrimaryRefreshToken to cache item
    MSIDPRTCacheItem *cacheItem = (MSIDPRTCacheItem *) primaryRT.tokenCacheItem;
    
    // Convert cache item to JSON
    NSDictionary *serializedCacheItem = [cacheItem jsonDictionary];
    XCTAssertEqualObjects(serializedCacheItem[MSID_RECOVERY_ATTEMPT_COUNT_CACHE_KEY], @"1");
    XCTAssertEqualObjects(serializedCacheItem[MSID_LAST_RECOVERY_ATTEMPT_FAILED_CACHE_KEY], @"0");
    
    // Convert JSON back to cache item
    NSError *error;
    MSIDPRTCacheItem *deserializedCacheItem = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:serializedCacheItem error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(deserializedCacheItem);
    XCTAssertEqualObjects(deserializedCacheItem.recoveryAttemptCount, @"1");
    XCTAssertEqualObjects(deserializedCacheItem.lastRecoveryAttemptFailed, @"0");
    
    // Convert deserialized cache data back to MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT2 = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:deserializedCacheItem];
    XCTAssertEqual(primaryRT2.recoveryAttemptCount, 1);
    XCTAssertFalse(primaryRT2.lastRecoveryAttemptFailed);
    
    
    //  Recovery count 2 and recovery attempt failed value is YES
    // Create MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT3 = [self createToken];
    primaryRT3.recoveryAttemptCount = 2;
    primaryRT3.lastRecoveryAttemptFailed = YES;
    
    // Convert MSIDPrimaryRefreshToken to cache item
    MSIDPRTCacheItem *cacheItem3 = (MSIDPRTCacheItem *) primaryRT3.tokenCacheItem;
    
    // Convert cache item to JSON
    NSDictionary *serializedCacheItem3 = [cacheItem3 jsonDictionary];
    XCTAssertEqualObjects(serializedCacheItem3[MSID_RECOVERY_ATTEMPT_COUNT_CACHE_KEY], @"2");
    XCTAssertEqualObjects(serializedCacheItem3[MSID_LAST_RECOVERY_ATTEMPT_FAILED_CACHE_KEY], @"1");
    
    // Convert JSON back to cache item
    NSError *error3;
    MSIDPRTCacheItem *deserializedCacheItem3 = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:serializedCacheItem3 error:&error3];
    XCTAssertNil(error3);
    XCTAssertNotNil(deserializedCacheItem3);
    XCTAssertEqualObjects(deserializedCacheItem3.recoveryAttemptCount, @"2");
    XCTAssertEqualObjects(deserializedCacheItem3.lastRecoveryAttemptFailed, @"1");
    
    // Convert deserialized cache data back to MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT4 = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:deserializedCacheItem3];
    XCTAssertEqual(primaryRT4.recoveryAttemptCount, 2);
    XCTAssertTrue(primaryRT4.lastRecoveryAttemptFailed);
    
    
    // NO Recovery count and recovery attempt failed values are set
    // Create MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT5 = [self createToken];
    
    // Convert MSIDPrimaryRefreshToken to cache item
    MSIDPRTCacheItem *cacheItem4 = (MSIDPRTCacheItem *) primaryRT5.tokenCacheItem;
    
    // Convert cache item to JSON
    NSDictionary *serializedCacheItem4 = [cacheItem4 jsonDictionary];
    XCTAssertEqualObjects(serializedCacheItem4[MSID_RECOVERY_ATTEMPT_COUNT_CACHE_KEY], @"0");
    XCTAssertEqualObjects(serializedCacheItem4[MSID_LAST_RECOVERY_ATTEMPT_FAILED_CACHE_KEY], @"0");
    
    // Convert JSON back to cache item
    NSError *error4;
    MSIDPRTCacheItem *deserializedCacheItem4 = [[MSIDPRTCacheItem alloc] initWithJSONDictionary:serializedCacheItem4 error:&error3];
    XCTAssertNil(error4);
    XCTAssertNotNil(deserializedCacheItem4);
    XCTAssertEqualObjects(deserializedCacheItem4.recoveryAttemptCount, @"0");
    XCTAssertEqualObjects(deserializedCacheItem4.lastRecoveryAttemptFailed, @"0");
    
    // Convert deserialized cache data back to MSIDPrimaryRefreshToken
    MSIDPrimaryRefreshToken *primaryRT6 = [[MSIDPrimaryRefreshToken alloc] initWithTokenCacheItem:deserializedCacheItem4];
    XCTAssertEqual(primaryRT6.recoveryAttemptCount, 0);
    XCTAssertFalse(primaryRT6.lastRecoveryAttemptFailed);
}

#pragma mark - Private

- (MSIDPrimaryRefreshToken *)createToken
{
    MSIDPrimaryRefreshToken *token = [MSIDPrimaryRefreshToken new];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"some clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.idToken = @"idtoken";
    token.refreshToken = @"refreshtoken";
    token.familyId = @"1";
    token.sessionKey = [@"sessionKey" dataUsingEncoding:NSUTF8StringEncoding];
    return token;
}

@end
