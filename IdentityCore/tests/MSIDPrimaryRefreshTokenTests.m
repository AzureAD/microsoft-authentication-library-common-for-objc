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
