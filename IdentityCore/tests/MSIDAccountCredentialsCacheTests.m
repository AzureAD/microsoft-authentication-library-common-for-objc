//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAccountCredentialCache.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDTestIdTokenUtil.h"

@interface MSIDAccountCredentialsCacheTests : XCTestCase

@property (nonatomic) MSIDAccountCredentialCache *cache;

@end

@implementation MSIDAccountCredentialsCacheTests

- (void)setUp
{
    MSIDKeychainTokenCache *keychainCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    self.cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:keychainCache];
    [super setUp];
}

- (void)tearDown
{
    [self cleanCache];
    [super tearDown];
}

- (void)cleanCache
{
    BOOL result = [self.cache clearWithContext:nil error:nil];
    XCTAssertTrue(result);
    NSError *error = nil;
    NSArray *allItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allItems);
    XCTAssertEqual([allItems count], 0);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andAccessTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";
    query.target = @"user.read user.write";

    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andAccessTokenQuery_shouldReturnItems
{
    // First save the token
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeAccessToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.target = @"user.read user.write";
    item.clientId = @"client";

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";
    query.target = @"user.read user.write";

    XCTAssertTrue(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andRefreshTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";
    query.target = @"user.read user.write";

    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andRefreshTokenQuery_shouldReturnItems
{
    // First save the token
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeRefreshToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";

    XCTAssertTrue(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andIDTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";
    query.target = @"user.read user.write";

    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andIDTokenQuery_shouldReturnItems
{
    // First save the token
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeIDToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.clientId = @"client";

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";

    XCTAssertTrue(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.us";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.de";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.de";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItemWithUPN:@"user2@upn.com"];
    idToken2.clientId = @"client2";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserIdAndEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItemWithUPN:@"user@upn.com"];
    idToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.realm = @"contoso.de";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByRealm_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.realm = @"contoso.de";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByFamilyId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByFamilyId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem:@"family"];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem:@"family2"];
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByFamilyId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.clientId = @"client2";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.clientId = @"client2";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.clientId = @"client2";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByTarget_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByTarget_shouldNotReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsAny_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.dance";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.target = @"user.sing";
    query.targetMatchingOptions = Any;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsSubset_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.target = @"user.write";
    query.targetMatchingOptions = SubSet;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsIntersect_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.dance user.play";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.target = @"user.write user.sing";
    query.targetMatchingOptions = Intersect;

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchAnythingButByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.realm = @"contoso.com";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByAnythingButUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.clientId = @"client";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:refreshToken]);
    XCTAssertTrue([results containsObject:refreshToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByAnythingButUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.uniqueUserId = @"uid.utid2";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.clientId = @"client";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:idToken]);
    XCTAssertTrue([results containsObject:idToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByAnythingButEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.realm = @"contoso.com";
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByAnythingButEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:refreshToken]);
    XCTAssertTrue([results containsObject:refreshToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByAnythingButEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.net";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:idToken]);
    XCTAssertTrue([results containsObject:idToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByAnythingButRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.realm = @"contoso.de";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByAnythingButRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.realm = @"contoso.de";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:idToken]);
    XCTAssertTrue([results containsObject:idToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByAnythingButFamilyId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem:@"family"];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem:@"family2"];
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:refreshToken]);
    XCTAssertTrue([results containsObject:refreshToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByAnythingButClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.clientId = @"client2";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.target = @"user.read user.write";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByAnythingButClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:refreshToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.clientId = @"client2";
    result = [self.cache saveCredential:refreshToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeRefreshToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:refreshToken]);
    XCTAssertTrue([results containsObject:refreshToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByAnythingButClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:idToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.clientId = @"client2";
    result = [self.cache saveCredential:idToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeIDToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:idToken]);
    XCTAssertTrue([results containsObject:idToken2]);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByAnythingButTarget_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];

    // First save the token
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:accessToken context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    result = [self.cache saveCredential:accessToken2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDCredentialTypeAccessToken;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

/*

 - (nullable NSArray<MSIDCredentialCacheItem *> *)getCredentialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
 legacyUserId:(nullable NSString *)legacyUserId
 context:(nullable id<MSIDRequestContext>)context
 error:(NSError * _Nullable * _Nullable)error;

- (nullable MSIDCredentialCacheItem *)getCredential:(nonnull MSIDDefaultCredentialCacheKey *)key
                                            context:(nullable id<MSIDRequestContext>)context
                                              error:(NSError * _Nullable * _Nullable)error;

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllCredentialsWithType:(MSIDCredentialType)type
                                                                   context:(nullable id<MSIDRequestContext>)context
                                                                     error:(NSError * _Nullable * _Nullable)error;

- (nullable NSArray<MSIDAccountCacheItem *> *)getAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                                                           context:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable * _Nullable)error;

- (nullable MSIDAccountCacheItem *)getAccount:(nonnull MSIDDefaultAccountCacheKey *)key
                                      context:(nullable id<MSIDRequestContext>)context
                                        error:(NSError * _Nullable * _Nullable)error;

- (nullable NSArray<MSIDAccountCacheItem *> *)getAllAccountsWithType:(MSIDAccountType)type
                                                             context:(nullable id<MSIDRequestContext>)context
                                                               error:(NSError * _Nullable * _Nullable)error;

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllItemsWithContext:(nullable id<MSIDRequestContext>)context
                                                                  error:(NSError * _Nullable * _Nullable)error;

- (BOOL)saveCredential:(nonnull MSIDCredentialCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error;

- (BOOL)saveAccount:(nonnull MSIDAccountCacheItem *)account
            context:(nullable id<MSIDRequestContext>)context
              error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeCredetialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
                          context:(nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeCredential:(nonnull MSIDCredentialCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                        context:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable * _Nullable)error;

- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeAllCredentials:(nonnull NSArray<MSIDCredentialCacheItem *> *)credentials
                     context:(nullable id<MSIDRequestContext>)context
                       error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeAllAccounts:(nonnull NSArray<MSIDAccountCacheItem *> *)accounts
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable * _Nullable)error;

- (nullable NSDictionary *)wipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error;

*/

#pragma mark - Helpers

- (MSIDCredentialCacheItem *)createTestAccessTokenCacheItem
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeAccessToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.clientId = @"client";
    item.target = @"user.read user.write";
    item.secret = @"at";
    return item;
}

- (MSIDCredentialCacheItem *)createTestRefreshTokenCacheItem
{
    return [self createTestRefreshTokenCacheItem:nil];
}

- (MSIDCredentialCacheItem *)createTestRefreshTokenCacheItem:(NSString *)familyId
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeRefreshToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.familyId = @"family";
    item.secret = @"rt";
    item.familyId = familyId;
    return item;
}

- (MSIDCredentialCacheItem *)createTestIDTokenCacheItem
{
    return [self createTestIDTokenCacheItemWithUPN:@"user@upn.com"];
}

- (MSIDCredentialCacheItem *)createTestIDTokenCacheItemWithUPN:(NSString *)upn
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDCredentialTypeIDToken;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.realm = @"contoso.com";

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Name" upn:upn tenantId:@"tid"];
    item.secret = idToken;

    return item;
}

@end
