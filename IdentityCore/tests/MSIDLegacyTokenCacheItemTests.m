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
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDClientInfo.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDLegacyTokenCacheItemTests : XCTestCase

@end

@implementation MSIDLegacyTokenCacheItemTests

- (void)testKeyedArchivingSingleResourceToken_whenAllFieldsSet_shouldReturnSameTokenOnDeserialize
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.accessToken = @"at";
    cacheItem.refreshToken = @"rt";
    cacheItem.idToken = @"id";
    cacheItem.oauthTokenType = @"token type";
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    cacheItem.clientId = @"client";
    cacheItem.credentialType = MSIDCredentialTypeLegacySingleResourceToken;
    cacheItem.secret = @"at";
    cacheItem.target = @"resource";
    cacheItem.realm = @"contoso.com";
    cacheItem.environment = @"login.microsoftonline.com";

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];

    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.familyId = @"family";
    cacheItem.uniqueUserId = @"uid.utid";

    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];

    cacheItem.clientInfo = clientInfoObj;

    NSDictionary *additionalInfo = @{@"extended_expires_on": extExpiresOn,
                                     @"spe_info": @"2", @"test": @"test"};

    cacheItem.additionalInfo = additionalInfo;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];

    XCTAssertNotNil(data);

    MSIDLegacyTokenCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertNotNil(newItem);
    XCTAssertEqualObjects(newItem.accessToken, @"at");
    XCTAssertEqualObjects(newItem.refreshToken, @"rt");
    XCTAssertEqualObjects(newItem.idToken, @"id");
    XCTAssertEqualObjects(newItem.oauthTokenType, @"token type");
    NSURL *authorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    XCTAssertEqualObjects(newItem.authority, authorityURL);
    XCTAssertEqualObjects(newItem.clientId, @"client");
    XCTAssertEqual(newItem.credentialType, MSIDCredentialTypeLegacySingleResourceToken);
    XCTAssertEqualObjects(newItem.secret, @"at");
    XCTAssertEqualObjects(newItem.target, @"resource");
    XCTAssertEqualObjects(newItem.realm, @"contoso.com");
    XCTAssertEqualObjects(newItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(newItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(newItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(newItem.familyId, @"family");
    XCTAssertEqualObjects(newItem.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(newItem.clientInfo, clientInfoObj);
    XCTAssertEqualObjects(newItem.additionalInfo, additionalInfo);
}

- (void)testKeyedArchivingAccessToken_whenAllFieldsSet_shouldReturnSameTokenOnDeserialize
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.accessToken = @"at";
    cacheItem.idToken = @"id";
    cacheItem.oauthTokenType = @"token type";
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    cacheItem.clientId = @"client";
    cacheItem.credentialType = MSIDCredentialTypeAccessToken;
    cacheItem.secret = @"at";
    cacheItem.target = @"resource";
    cacheItem.realm = @"contoso.com";
    cacheItem.environment = @"login.microsoftonline.com";

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];

    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.uniqueUserId = @"uid.utid";

    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];

    cacheItem.clientInfo = clientInfoObj;

    NSDictionary *additionalInfo = @{@"extended_expires_on": extExpiresOn,
                                     @"spe_info": @"2", @"test": @"test"};

    cacheItem.additionalInfo = additionalInfo;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];

    XCTAssertNotNil(data);

    MSIDLegacyTokenCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertNotNil(newItem);
    XCTAssertEqualObjects(newItem.accessToken, @"at");
    XCTAssertEqualObjects(newItem.idToken, @"id");
    XCTAssertEqualObjects(newItem.oauthTokenType, @"token type");
    NSURL *authorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    XCTAssertEqualObjects(newItem.authority, authorityURL);
    XCTAssertEqualObjects(newItem.clientId, @"client");
    XCTAssertEqual(newItem.credentialType, MSIDCredentialTypeAccessToken);
    XCTAssertEqualObjects(newItem.secret, @"at");
    XCTAssertEqualObjects(newItem.target, @"resource");
    XCTAssertEqualObjects(newItem.realm, @"contoso.com");
    XCTAssertEqualObjects(newItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(newItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(newItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(newItem.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(newItem.clientInfo, clientInfoObj);
    XCTAssertEqualObjects(newItem.additionalInfo, additionalInfo);
}

- (void)testKeyedArchivingRefreshToken_whenAllFieldsSet_shouldReturnSameTokenOnDeserialize
{
    MSIDLegacyTokenCacheItem *cacheItem = [MSIDLegacyTokenCacheItem new];
    cacheItem.refreshToken = @"rt";
    cacheItem.idToken = @"id";
    cacheItem.oauthTokenType = @"token type";
    cacheItem.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    cacheItem.clientId = @"client";
    cacheItem.credentialType = MSIDCredentialTypeRefreshToken;
    cacheItem.secret = @"rt";
    cacheItem.target = @"resource";
    cacheItem.realm = @"contoso.com";
    cacheItem.environment = @"login.microsoftonline.com";

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];

    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.familyId = @"family";
    cacheItem.uniqueUserId = @"uid.utid";

    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];

    cacheItem.clientInfo = clientInfoObj;

    NSDictionary *additionalInfo = @{@"extended_expires_on": extExpiresOn,
                                     @"spe_info": @"2", @"test": @"test"};

    cacheItem.additionalInfo = additionalInfo;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];

    XCTAssertNotNil(data);

    MSIDLegacyTokenCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertNotNil(newItem);
    XCTAssertEqualObjects(newItem.refreshToken, @"rt");
    XCTAssertEqualObjects(newItem.idToken, @"id");
    XCTAssertEqualObjects(newItem.oauthTokenType, @"token type");
    NSURL *authorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    XCTAssertEqualObjects(newItem.authority, authorityURL);
    XCTAssertEqualObjects(newItem.clientId, @"client");
    XCTAssertEqual(newItem.credentialType, MSIDCredentialTypeRefreshToken);
    XCTAssertEqualObjects(newItem.secret, @"rt");
    XCTAssertEqualObjects(newItem.target, @"resource");
    XCTAssertEqualObjects(newItem.realm, @"contoso.com");
    XCTAssertEqualObjects(newItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(newItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(newItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(newItem.familyId, @"family");
    XCTAssertEqualObjects(newItem.uniqueUserId, @"uid.utid");
    XCTAssertEqualObjects(newItem.clientInfo, clientInfoObj);
    XCTAssertEqualObjects(newItem.additionalInfo, additionalInfo);
}

@end
