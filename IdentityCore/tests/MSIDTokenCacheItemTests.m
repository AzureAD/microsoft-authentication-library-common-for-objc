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
#import "MSIDTestCacheIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDTokenCacheItemTests : XCTestCase

@end

@implementation MSIDTokenCacheItemTests

#pragma mark - Keyed archiver

- (void)testKeyedArchivingToken_whenAllFieldsSet_shouldReturnSameTokenOnDeserialize
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    cacheItem.uniqueUserId = DEFAULT_TEST_ID_TOKEN_USERNAME;
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.credentialType = MSIDCredentialTypeAccessToken;
    cacheItem.accessToken = DEFAULT_TEST_ACCESS_TOKEN;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.familyId = DEFAULT_TEST_FAMILY_ID;
    cacheItem.oauthTokenType = @"token type";
    
    NSDictionary *additionalInfo = @{@"extended_expires_on": extExpiresOn,
                                     @"spe_info": @"2", @"test": @"test"};
    
    cacheItem.additionalInfo = additionalInfo;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];
    
    XCTAssertNotNil(data);
    
    MSIDCredentialCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, additionalInfo);
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
    XCTAssertEqualObjects(newItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(newItem.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(newItem.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(newItem.idToken, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(newItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(newItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(newItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(newItem.familyId, DEFAULT_TEST_FAMILY_ID);
    XCTAssertEqualObjects(newItem.oauthTokenType, @"token type");
    XCTAssertEqualObjects(newItem.additionalInfo, additionalInfo);
}

#pragma mark - JSON serialization

- (void)testJSONDictionary_whenAccessToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.credentialType = MSIDCredentialTypeAccessToken;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];
    
    cacheItem.cachedAt = cachedAt;
    cacheItem.expiresOn = expiresOn;
    cacheItem.accessToken = DEFAULT_TEST_ACCESS_TOKEN;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    cacheItem.oauthTokenType = @"token type";
    
    NSDictionary *additionalInfo = @{@"extended_expires_on": extExpiresOn,
                                     @"spe_info": @"2"};
    
    cacheItem.additionalInfo = additionalInfo;
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    
    NSDictionary *expectedDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                         @"credential_type": @"accesstoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"target": DEFAULT_TEST_RESOURCE,
                                         @"cached_at": cachedAtString,
                                         @"expires_on": expiresOnString,
                                         @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                         @"realm": @"common",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"id_token": DEFAULT_TEST_ID_TOKEN,
                                         @"access_token_type": @"token type",
                                         @"extended_expires_on": extExpiresOnString,
                                         @"spe_info": @"2"
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
    
}

- (void)testJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.credentialType = MSIDCredentialTypeRefreshToken;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    cacheItem.familyId = DEFAULT_TEST_FAMILY_ID;
    
    NSDictionary *expectedDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                         @"credential_type": @"refreshtoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"id_token": DEFAULT_TEST_ID_TOKEN,
                                         @"family_id": DEFAULT_TEST_FAMILY_ID
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

- (void)testJSONDictionary_whenIDToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.credentialType = MSIDCredentialTypeIDToken;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    
    NSDictionary *expectedDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                         @"credential_type": @"idtoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_ID_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"common"
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

- (void)testJSONDictionary_whenLegacyToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.credentialType = MSIDCredentialTypeLegacySingleResourceToken;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.cachedAt = cachedAt;
    cacheItem.expiresOn = expiresOn;
    cacheItem.accessToken = DEFAULT_TEST_ACCESS_TOKEN;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    
    NSDictionary *expectedDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                         @"credential_type": @"legacysingleresourcetoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"target": DEFAULT_TEST_RESOURCE,
                                         @"cached_at": cachedAtString,
                                         @"expires_on": expiresOnString,
                                         @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                         @"realm": @"common",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"id_token": DEFAULT_TEST_ID_TOKEN,
                                         @"resource_refresh_token": DEFAULT_TEST_REFRESH_TOKEN
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAccessToken_andAllFieldsSet_shouldReturnAccessTokenCacheItem
{
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *cachedAt = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *extExpiresOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    
    NSDictionary *jsonDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                     @"credential_type": @"accesstoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"target": DEFAULT_TEST_RESOURCE,
                                     @"cached_at": cachedAtString,
                                     @"expires_on": expiresOnString,
                                     @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                     @"realm": @"common",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"id_token": DEFAULT_TEST_ID_TOKEN,
                                     @"access_token_type": @"Bearer",
                                     @"extended_expires_on": extExpiresOnString,
                                     @"spe_info": @"2"
                                     };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    NSURL *expectedAuthority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    XCTAssertEqualObjects(cacheItem.authority, expectedAuthority);
    XCTAssertEqual(cacheItem.credentialType, MSIDCredentialTypeAccessToken);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(cacheItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(cacheItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(cacheItem.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(cacheItem.idToken, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(cacheItem.oauthTokenType, @"Bearer");
    NSDictionary *additionalInfo = @{@"spe_info": @"2", @"extended_expires_on": extExpiresOn};
    XCTAssertEqualObjects(cacheItem.additionalInfo, additionalInfo);
}

- (void)testInitWithJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnRefreshTokenCacheItem
{
    NSDictionary *jsonDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                     @"credential_type": @"refreshtoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"id_token": DEFAULT_TEST_ID_TOKEN,
                                     @"family_id": DEFAULT_TEST_FAMILY_ID
                                     };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    NSURL *expectedAuthority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    XCTAssertEqualObjects(cacheItem.authority, expectedAuthority);
    XCTAssertEqual(cacheItem.credentialType, MSIDCredentialTypeRefreshToken);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(cacheItem.idToken, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(cacheItem.familyId, DEFAULT_TEST_FAMILY_ID);
}

- (void)testInitWithJSONDictionary_whenLegacyToken_andAllFieldsSet_shouldReturnLegacyTokenCacheItem
{
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    NSDate *cachedAt = [NSDate dateWithTimeIntervalSince1970:(long)[NSDate date]];
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    
    NSDictionary *jsonDictionary = @{@"authority": DEFAULT_TEST_AUTHORITY,
                                     @"credential_type": @"legacysingleresourcetoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"target": DEFAULT_TEST_RESOURCE,
                                     @"cached_at": cachedAtString,
                                     @"expires_on": expiresOnString,
                                     @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                     @"realm": @"common",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"id_token": DEFAULT_TEST_ID_TOKEN,
                                     @"resource_refresh_token": DEFAULT_TEST_REFRESH_TOKEN
                                     };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    NSURL *expectedAuthority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    XCTAssertEqualObjects(cacheItem.authority, expectedAuthority);
    XCTAssertEqual(cacheItem.credentialType, MSIDCredentialTypeLegacySingleResourceToken);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(cacheItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(cacheItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(cacheItem.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(cacheItem.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(cacheItem.idToken, DEFAULT_TEST_ID_TOKEN);
}

- (void)testInitWithJSONDictionary_whenIDToken_andAllFieldsSet_shouldReturnIDTokenCacheItem
{
    NSDictionary *jsonDictionary = @{@"credential_type": @"idtoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_ID_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"realm": @"common",
                                     };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    NSURL *expectedAuthority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    XCTAssertEqualObjects(cacheItem.authority, expectedAuthority);
    XCTAssertEqual(cacheItem.credentialType, MSIDCredentialTypeIDToken);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.idToken, DEFAULT_TEST_ID_TOKEN);
}

@end
