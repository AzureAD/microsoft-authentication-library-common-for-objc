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
#import "MSIDClientInfo.h"

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

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];
    
    cacheItem.cachedAt = cachedAt;
    cacheItem.expiresOn = expiresOn;
    cacheItem.target = DEFAULT_TEST_RESOURCE;

    NSDictionary *additionalInfo = @{@"ext_expires_on": extExpiresOn,
                                     @"spe_info": @"2"};
    
    cacheItem.additionalInfo = additionalInfo;
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];
    
    NSDictionary *expectedDictionary = @{@"credential_type": @"accesstoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"target": DEFAULT_TEST_RESOURCE,
                                         @"cached_at": cachedAtString,
                                         @"expires_on": expiresOnString,
                                         @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                         @"realm": @"contoso.com",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"ext_expires_on": extExpiresOnString,
                                         @"spe_info": @"2",
                                         @"home_account_id": @"uid.utid"
                                         };
    
    XCTAssertEqualObjects(cacheItem.jsonDictionary, expectedDictionary);
    
}

- (void)testJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnJSONDictionary
{
    MSIDCredentialCacheItem *cacheItem = [MSIDCredentialCacheItem new];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.secret = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.familyId = DEFAULT_TEST_FAMILY_ID;
    cacheItem.homeAccountId = @"uid.utid";
    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];
    cacheItem.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];
    
    NSDictionary *expectedDictionary = @{@"credential_type": @"refreshtoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"family_id": DEFAULT_TEST_FAMILY_ID,
                                         @"home_account_id": @"uid.utid",
                                         @"client_info": clientInfo
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
    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];
    cacheItem.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];
    
    NSDictionary *expectedDictionary = @{@"credential_type": @"idtoken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_ID_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"realm": @"contoso.com",
                                         @"client_info": clientInfo,
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
    
    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];

    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    NSDictionary *jsonDictionary = @{@"credential_type": @"accesstoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"target": DEFAULT_TEST_RESOURCE,
                                     @"cached_at": cachedAtString,
                                     @"expires_on": expiresOnString,
                                     @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                     @"realm": @"contoso.com",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"ext_expires_on": extExpiresOnString,
                                     @"spe_info": @"2",
                                     @"home_account_id": @"uid.utid",
                                     @"client_info": clientInfo
                                     };
    
    NSError *error = nil;
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.environment, DEFAULT_TEST_ENVIRONMENT);
    XCTAssertEqual(cacheItem.credentialType, MSIDAccessTokenType);
    XCTAssertEqualObjects(cacheItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(cacheItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(cacheItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(cacheItem.realm, @"contoso.com");
    XCTAssertEqualObjects(cacheItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(cacheItem.secret, DEFAULT_TEST_ACCESS_TOKEN);
    NSDictionary *additionalInfo = @{@"spe_info": @"2", @"ext_expires_on": extExpiresOn};
    XCTAssertEqualObjects(cacheItem.additionalInfo, additionalInfo);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"uid.utid");

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];
    XCTAssertEqualObjects(cacheItem.clientInfo, clientInfoObj);
}

- (void)testInitWithJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnRefreshTokenCacheItem
{
    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    NSDictionary *jsonDictionary = @{@"credential_type": @"refreshtoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"family_id": DEFAULT_TEST_FAMILY_ID,
                                     @"home_account_id": @"uid.utid",
                                     @"client_info": clientInfo
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

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];
    XCTAssertEqualObjects(cacheItem.clientInfo, clientInfoObj);
}

- (void)testInitWithJSONDictionary_whenIDToken_andAllFieldsSet_shouldReturnIDTokenCacheItem
{
    NSString *clientInfo = [@{ @"uid" : @"uid", @"utid" : @"utid"} msidBase64UrlJson];

    NSDictionary *jsonDictionary = @{@"credential_type": @"idtoken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_ID_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"realm": @"contoso.com",
                                     @"home_account_id": @"uid.utid",
                                     @"client_info": clientInfo
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

    MSIDClientInfo *clientInfoObj = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfo error:nil];
    XCTAssertEqualObjects(cacheItem.clientInfo, clientInfoObj);
}

@end
