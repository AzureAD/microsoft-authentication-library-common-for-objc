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
    cacheItem.enrollmentId = @"enrollmentId";

    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    NSDate *extExpiresOn = [NSDate date];

    cacheItem.cachedAt = cachedAt;
    cacheItem.expiresOn = expiresOn;
    cacheItem.extendedExpiresOn = extExpiresOn;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    cacheItem.speInfo = @"2";

    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];

    NSDictionary *expectedDictionary = @{@"credential_type": @"AccessToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"target": DEFAULT_TEST_RESOURCE,
                                         @"cached_at": cachedAtString,
                                         @"expires_on": expiresOnString,
                                         @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                         @"realm": @"contoso.com",
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"extended_expires_on": extExpiresOnString,
                                         @"spe_info": @"2",
                                         @"home_account_id": @"uid.utid",
                                         @"enrollment_id": @"enrollmentId"
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

    NSDictionary *expectedDictionary = @{@"credential_type": @"RefreshToken",
                                         @"client_id": DEFAULT_TEST_CLIENT_ID,
                                         @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                         @"environment": DEFAULT_TEST_ENVIRONMENT,
                                         @"family_id": DEFAULT_TEST_FAMILY_ID,
                                         @"home_account_id": @"uid.utid"
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

    NSString *cachedAtString = [NSString stringWithFormat:@"%ld", (long)[cachedAt timeIntervalSince1970]];
    NSString *expiresOnString = [NSString stringWithFormat:@"%ld", (long)[expiresOn timeIntervalSince1970]];
    NSString *extExpiresOnString = [NSString stringWithFormat:@"%ld", (long)[extExpiresOn timeIntervalSince1970]];

    NSDictionary *jsonDictionary = @{@"credential_type": @"AccessToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"target": DEFAULT_TEST_RESOURCE,
                                     @"cached_at": cachedAtString,
                                     @"expires_on": expiresOnString,
                                     @"extended_expires_on": extExpiresOnString,
                                     @"secret": DEFAULT_TEST_ACCESS_TOKEN,
                                     @"realm": @"contoso.com",
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"extended_expires_on": extExpiresOnString,
                                     @"spe_info": @"2",
                                     @"test": @"test2",
                                     @"home_account_id": @"uid.utid",
                                     @"enrollment_id": @"enrollmentId"
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
}

- (void)testInitWithJSONDictionary_whenRefreshToken_andAllFieldsSet_shouldReturnRefreshTokenCacheItem
{
    NSDictionary *jsonDictionary = @{@"credential_type": @"RefreshToken",
                                     @"client_id": DEFAULT_TEST_CLIENT_ID,
                                     @"secret": DEFAULT_TEST_REFRESH_TOKEN,
                                     @"environment": DEFAULT_TEST_ENVIRONMENT,
                                     @"family_id": DEFAULT_TEST_FAMILY_ID,
                                     @"home_account_id": @"uid.utid"
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
    XCTAssertNil(cacheItem.enrollmentId);
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

@end
