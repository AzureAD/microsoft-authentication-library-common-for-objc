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
#import "MSIDAccountCacheItem.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDTestCacheDataSource.h"

@interface MSIDAccountCredentialsCacheTests : XCTestCase

@property (nonatomic) MSIDAccountCredentialCache *cache;

@end

@implementation MSIDAccountCredentialsCacheTests

#pragma mark - Setup

- (void)setUp
{
    id<MSIDTokenCacheDataSource> dataSource = nil;

#if TARGET_OS_IOS
    dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
#else
    // TODO: this should be replaced with a real macOS datasource instead
    dataSource = [[MSIDTestCacheDataSource alloc] init];
#endif

    self.cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
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

#pragma mark - getCredentialsWithQuery

- (void)testGetCredentialsWithQuery_whenExactMatch_andAccessTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
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
    item.credentialType = MSIDAccessTokenType;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.target = @"user.read user.write";
    item.clientId = @"client";
    item.secret = @"at";
    [self saveItem:item];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
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
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andRefreshTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
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
    item.credentialType = MSIDRefreshTokenType;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.secret = @"rt";
    [self saveItem:item];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";

    XCTAssertTrue(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenExactMatch_andIDTokenQuery_noItemsInCache_shouldReturnEmptyResult
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
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
    item.credentialType = MSIDIDTokenType;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.clientId = @"client";
    item.secret = @"id";
    [self saveItem:item];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";

    XCTAssertTrue(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], item);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.net";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.net";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.net";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.us";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.de";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.de";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.environmentAliases = @[@"login.windows.net", @"login.microsoftonline.com"];

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItemWithUPN:@"user2@upn.com"];
    idToken2.clientId = @"client2";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserIdAndEnvironment_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItemWithUPN:@"user@upn.com"];
    idToken2.environment = @"login.windows.net";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserIdAndEnvironment_shouldNotReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItemWithUPN:@"user@upn.com"];
    idToken2.environment = @"login.windows.net";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.environment = @"login.windows.us";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:@"user@upn.com" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.realm = @"contoso.de";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByRealm_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByRealm_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.realm = @"contoso.de";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByFamilyId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByFamilyId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem:@"family"];
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem:@"family2"];
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByFamilyId_shouldNotReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.familyId = @"family";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.clientId = @"client2";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.clientId = @"client2";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], refreshToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByClientId_shouldReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.clientId = @"client2";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], idToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByTarget_shouldNotReturnItems
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByTarget_shouldNotReturnItems
{
    MSIDCredentialCacheItem *idToken = [self createTestIDTokenCacheItem];
    [self saveItem:idToken];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.target = @"user.read user.write";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsAny_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.dance";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsSubset_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.target = @"user.write";
    query.targetMatchingOptions = SubSet;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByTarget_targetMatchingOptionsIntersect_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.dance user.play";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.target = @"user.write user.sing";
    query.targetMatchingOptions = Intersect;

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], accessToken);
}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchAnythingButByUniqueUserId_shouldReturnItems
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.realm = @"contoso.com";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.clientId = @"client";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.uniqueUserId = @"uid.utid2";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.clientId = @"client";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.environment = @"login.windows.net";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.realm = @"contoso.com";
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.environment = @"login.windows.net";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.environment = @"login.windows.net";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.realm = @"contoso.de";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.target = @"user.read user.write";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.realm = @"contoso.de";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.clientId = @"client";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem:@"family2"];
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.clientId = @"client2";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.target = @"user.read user.write";
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:refreshToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *refreshToken2 = [self createTestRefreshTokenCacheItem];
    refreshToken2.clientId = @"client2";
    [self saveItem:refreshToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:idToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *idToken2 = [self createTestIDTokenCacheItem];
    idToken2.clientId = @"client2";
    [self saveItem:idToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
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
    [self saveItem:accessToken];

    // Save second non-matching token
    MSIDCredentialCacheItem *accessToken2 = [self createTestAccessTokenCacheItem];
    accessToken2.target = @"user.sing";
    [self saveItem:accessToken2];

    // Now query
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.uniqueUserId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.clientId = @"client";

    XCTAssertFalse(query.exactMatch);
    NSError *error = nil;
    NSArray *results = [self.cache getCredentialsWithQuery:query legacyUserId:nil context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    XCTAssertTrue([results containsObject:accessToken]);
    XCTAssertTrue([results containsObject:accessToken2]);
}

#pragma mark - getCredential

- (void)testGetCredentialWithKey_whenAccessTokenKey_noItemsInCache_shouldReturnNil
{
    MSIDCredentialCacheItem *refreshToken = [self createTestRefreshTokenCacheItem];
    [self saveItem:refreshToken];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDAccessTokenType];

    key.realm = @"contoso.com";
    key.target = @"user.read user.write";

    NSError *error = nil;
    MSIDCredentialCacheItem *item = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(item);
}

- (void)testGetCredentialWithKey_whenAccessTokenKey_shouldReturnItem
{
    // First save the token
    MSIDCredentialCacheItem *item = [self createTestAccessTokenCacheItem];
    [self saveItem:item];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDAccessTokenType];

    key.realm = @"contoso.com";
    key.target = @"user.read user.write";

    NSError *error = nil;
    MSIDCredentialCacheItem *resultItem = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(resultItem, item);
}

- (void)testGetCredentialWithKey_whenRefreshTokenKey_noItemsInCache_shouldReturnNil
{
    MSIDCredentialCacheItem *accessToken = [self createTestAccessTokenCacheItem];
    [self saveItem:accessToken];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDRefreshTokenType];

    NSError *error = nil;
    MSIDCredentialCacheItem *item = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(item);
}

- (void)testGetCredentialWithKey_whenRefreshTokenKey_andClientId_shouldReturnItem
{
    // First save the token
    MSIDCredentialCacheItem *item = [self createTestRefreshTokenCacheItem];
    [self saveItem:item];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDRefreshTokenType];

    NSError *error = nil;
    MSIDCredentialCacheItem *resultItem = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(resultItem, item);
}

- (void)testGetCredentialWithKey_whenRefreshTokenKey_andFamilyId_shouldReturnItems
{
    // First save the token
    MSIDCredentialCacheItem *item = [self createTestRefreshTokenCacheItem:@"family"];
    [self saveItem:item];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDRefreshTokenType];

    key.familyId = @"family";

    NSError *error = nil;
    MSIDCredentialCacheItem *resultItem = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(resultItem, item);
}

- (void)testGetCredentialWithKey_whenIDTokenQuery_noItemsInCache_shouldReturnNil
{
    // First save the token
    MSIDCredentialCacheItem *item = [self createTestRefreshTokenCacheItem];
    [self saveItem:item];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDIDTokenType];
    key.realm = @"contoso.com";

    NSError *error = nil;
    MSIDCredentialCacheItem *resultItem = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(resultItem);
}

- (void)testGetCredentialWithkey_whenIDTokenKey_shouldReturnItem
{
    // First save the token
    MSIDCredentialCacheItem *item = [self createTestIDTokenCacheItem];
    [self saveItem:item];

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDIDTokenType];
    key.realm = @"contoso.com";

    NSError *error = nil;
    MSIDCredentialCacheItem *resultItem = [self.cache getCredential:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(resultItem, item);
}

#pragma mark - getAllCredentialsWithType

- (void)testGetAllCredentialsWithType_whenAccessTokenType_noItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDAccessTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllCredentialsWithType_whenAccessTokenType_andItemsInCache_shouldReturnItems
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDAccessTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], [self createTestAccessTokenCacheItem]);
}

- (void)testGetAllCredentialsWithType_whenRefreshTokenType_noItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDRefreshTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllCredentialsWithType_whenRefreshTokenType_andItemsInCache_shouldReturnItems
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDRefreshTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], [self createTestRefreshTokenCacheItem]);
}

- (void)testGetAllCredentialsWithType_whenIDTokenType_noItemsInCache_shouldReturnEmptyResult
{
    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDIDTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 0);
}

- (void)testGetAllCredentialsWithType_whenIDTokenType_andItemsInCache_shouldReturnItems
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    NSArray *results = [self.cache getAllCredentialsWithType:MSIDIDTokenType context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertEqual([results count], 1);
    XCTAssertEqualObjects(results[0], [self createTestIDTokenCacheItem]);
}

- (void)testSaveCredential_whenAccessToken_shouldReturnYES
{
    MSIDCredentialCacheItem *item = [self createTestAccessTokenCacheItem];

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testSaveCredential_whenRefreshToken_shouldReturnYES
{
    MSIDCredentialCacheItem *item = [self createTestRefreshTokenCacheItem];

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testSaveCredential_whenIDToken_shouldReturnYES
{
    MSIDCredentialCacheItem *item = [self createTestIDTokenCacheItem];

    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testSaveAccount_whenAccountPresent_shouldReturnYES
{
    MSIDAccountCacheItem *item = [self createTestAccountCacheItem];

    NSError *error = nil;
    BOOL result = [self.cache saveAccount:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)testClearWithContext_whenMultipleCredentialsAndAccountsPresent_shouldReturnYESAndClearAllCache
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];
    [self saveAccount:[self createTestAccountCacheItem]];

    NSError *error = nil;
    NSArray *allItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([allItems count] == 3);

    NSArray *allAccounts = [self.cache getAccountsWithQuery:[MSIDDefaultAccountCacheQuery new] context:nil error:&error];
    XCTAssertTrue([allAccounts count] == 1);

    BOOL result = [self.cache clearWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    allItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([allItems count] == 0);

    allAccounts = [self.cache getAccountsWithQuery:[MSIDDefaultAccountCacheQuery new] context:nil error:&error];
    XCTAssertTrue([allAccounts count] == 0);

}

- (void)testGetAllCredentialItems_whenMultipleCredentialsPresent_shouldReturnItems
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];
    [self saveAccount:[self createTestAccountCacheItem]];

    NSError *error = nil;
    NSArray *allItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([allItems count] == 3);
    XCTAssertTrue([allItems containsObject:[self createTestIDTokenCacheItem]]);
    XCTAssertTrue([allItems containsObject:[self createTestRefreshTokenCacheItem]]);
    XCTAssertTrue([allItems containsObject:[self createTestAccessTokenCacheItem]]);
}

#pragma mark - getAccount

- (void)testGetAccountWithKey_whenNoItemsInCache_shouldReturnNil
{
    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                   environment:@"login.microsoftonline.com"
                                                                                         realm:@"contoso.com"
                                                                                          type:MSIDAccountTypeMSSTS];

    NSError *error = nil;
    MSIDAccountCacheItem *resultItem = [self.cache getAccount:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNil(resultItem);
}

- (void)testAccountWithkey_whenItemsInCache_shouldReturnItem
{
    // First save the token
    MSIDAccountCacheItem *item = [self createTestAccountCacheItem];
    [self saveAccount:item];

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithUniqueUserId:@"uid.utid"
                                                                                   environment:@"login.microsoftonline.com"
                                                                                         realm:@"contoso.com"
                                                                                          type:MSIDAccountTypeMSSTS];

    NSError *error = nil;
    MSIDAccountCacheItem *resultItem = [self.cache getAccount:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(resultItem, item);
}

#pragma mark - getAllAccountsWithType

- (void)testGetAllAccountsOfType_whenAADV2Type_shouldReturnItem
{
    MSIDAccountCacheItem *item = [self createTestAccountCacheItem];
    [self saveAccount:item];

    MSIDAccountCacheItem *item2 = [self createTestAccountCacheItem];
    item2.accountType = MSIDAccountTypeMSA;
    item2.uniqueUserId = @"uid.utid2";
    [self saveAccount:item2];

    NSError *error = nil;
    NSArray *results = [self.cache getAllAccountsWithType:MSIDAccountTypeMSSTS context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], item);
}

#pragma mark - removeAccount

- (void)testRemoveAccount_whenMultipleAccounts_shouldRemoveCorrectAccount
{
    MSIDAccountCacheItem *item = [self createTestAccountCacheItem];
    [self saveAccount:item];

    MSIDAccountCacheItem *item2 = [self createTestAccountCacheItem];
    item2.accountType = MSIDAccountTypeMSA;
    item2.uniqueUserId = @"uid.utid2";
    [self saveAccount:item2];

    NSError *error = nil;
    BOOL removeResult = [self.cache removeAccount:item2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(removeResult);

    NSArray *results = [self.cache getAllAccountsWithType:MSIDAccountTypeMSSTS context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], item);
}

#pragma mark - removeAllCredentials

- (void)testRemoveAllCredentials_whenMultipleCredentialsInList_shouldRemove
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;

    MSIDCredentialCacheItem *item2 = [self createTestIDTokenCacheItem];
    item2.uniqueUserId = @"uid.utid2";
    [self saveItem:item2];

    MSIDCredentialCacheItem *item3 = [self createTestRefreshTokenCacheItem];
    item3.uniqueUserId = @"uid.utid2";
    [self saveItem:item3];

    MSIDCredentialCacheItem *item4 = [self createTestAccessTokenCacheItem];
    item4.uniqueUserId = @"uid.utid2";
    [self saveItem:item4];

    NSArray *removalArray = @[item2, item3, item4];

    BOOL result = [self.cache removeAllCredentials:removalArray context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allCredentials = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allCredentials);
    XCTAssertTrue([allCredentials count] == 3);
    XCTAssertTrue([allCredentials containsObject:[self createTestIDTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestRefreshTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestAccessTokenCacheItem]]);
}

- (void)testRemoveAllCredentials_whenEmptyCredentialsList_shouldNotRemove
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    BOOL result = [self.cache removeAllCredentials:[NSArray array] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allCredentials = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allCredentials);
    XCTAssertTrue([allCredentials count] == 3);
    XCTAssertTrue([allCredentials containsObject:[self createTestIDTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestRefreshTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestAccessTokenCacheItem]]);
}

#pragma mark - removeAllAccounts

- (void)testRemoveAllAccounts_whenMultipleAccountsInList_shouldRemove
{
    [self saveAccount:[self createTestAccountCacheItem]];

    NSError *error = nil;

    MSIDAccountCacheItem *item2 = [self createTestAccountCacheItem];
    item2.uniqueUserId = @"uid.utid2";
    [self saveAccount:item2];

    NSArray *removalArray = @[item2];

    BOOL result = [self.cache removeAllAccounts:removalArray context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allAccounts = [self.cache getAllAccountsWithType:MSIDAccountTypeMSSTS context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertTrue([allAccounts count] == 1);
    XCTAssertEqualObjects(allAccounts[0], [self createTestAccountCacheItem]);
}

- (void)testRemoveAllAccounts_whenEmptyAccountsList_shouldNotRemove
{
    [self saveAccount:[self createTestAccountCacheItem]];

    NSError *error = nil;

    MSIDAccountCacheItem *item2 = [self createTestAccountCacheItem];
    item2.uniqueUserId = @"uid.utid2";
    [self saveAccount:item2];

    BOOL result = [self.cache removeAllAccounts:[NSArray array] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allAccounts = [self.cache getAllAccountsWithType:MSIDAccountTypeMSSTS context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertTrue([allAccounts count] == 2);
}

#pragma mark - removeCredential

- (void)testRemoveCredential_whenMultipleCredentialsInCache_andRemoveRefreshToken_shouldRemoveRefreshTokenAndIDTokens
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    BOOL result = [self.cache removeCredential:[self createTestRefreshTokenCacheItem] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allCredentials = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allCredentials);
    XCTAssertTrue([allCredentials count] == 1);
    XCTAssertTrue([allCredentials containsObject:[self createTestAccessTokenCacheItem]]);
}

- (void)testRemoveCredential_whenMultipleCredentialsInCache_andRemoveAccessToken_shouldRemoveAccessToken
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    BOOL result = [self.cache removeCredential:[self createTestAccessTokenCacheItem] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allCredentials = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allCredentials);
    XCTAssertTrue([allCredentials count] == 2);
    XCTAssertTrue([allCredentials containsObject:[self createTestIDTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestRefreshTokenCacheItem]]);
}

- (void)testRemoveCredential_whenMultipleCredentialsInCache_andRemoveIDToken_shouldRemoveIDToken
{
    [self saveItem:[self createTestIDTokenCacheItem]];
    [self saveItem:[self createTestRefreshTokenCacheItem]];
    [self saveItem:[self createTestAccessTokenCacheItem]];

    NSError *error = nil;
    BOOL result = [self.cache removeCredential:[self createTestIDTokenCacheItem] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    NSArray *allCredentials = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allCredentials);
    XCTAssertTrue([allCredentials count] == 2);
    XCTAssertTrue([allCredentials containsObject:[self createTestAccessTokenCacheItem]]);
    XCTAssertTrue([allCredentials containsObject:[self createTestRefreshTokenCacheItem]]);
}

#pragma mark - getAccountsWithQuery

- (void)testGetAccountsWithQuery_whenQueryIsExactMatch_shouldReturnAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.uniqueUserId = @"uid.utid2";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.uniqueUserId = @"uid.utid2";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    XCTAssertTrue(query.exactMatch);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], account2);
}

- (void)testGetAccountsWithQuery_whenQueryNotExactMatch_andMatchingByUniqueUserId_shouldReturnAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.uniqueUserId = @"uid.utid2";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.uniqueUserId = @"uid.utid2";
    XCTAssertFalse(query.exactMatch);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], account2);
}

- (void)testGetAccountsWithQuery_whenQueryNotExactMatch_andMatchingByEnvironment_shouldReturnAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.environment = @"login.windows.net";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.environment = @"login.windows.net";
    XCTAssertFalse(query.exactMatch);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], account2);
}

- (void)testGetAccountsWithQuery_whenQueryNotExactMatch_andMatchingByEnvironmentAliases_shouldReturnAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.environment = @"login.windows.net";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.environmentAliases = @[@"login.microsoftonline.us", @"login.windows.net"];
    XCTAssertFalse(query.exactMatch);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], account2);
}

- (void)testGetAccountsWithQuery_whenQueryNotExactMatch_andMatchingByRealm_shouldReturnAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.realm = @"contoso2.com";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.realm = @"contoso2.com";
    XCTAssertFalse(query.exactMatch);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);
    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], account2);
}

#pragma mark - removeAccountsWithQuery

- (void)testRemoveAccountsWithQuery_whenQueryIsExactMatch_shouldRemoveAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.uniqueUserId = @"uid.utid2";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.uniqueUserId = @"uid.utid2";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    XCTAssertTrue(query.exactMatch);

    BOOL result = [self.cache removeAccountsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    MSIDDefaultAccountCacheQuery *allItemsQuery = [MSIDDefaultAccountCacheQuery new];

    NSArray *results = [self.cache getAccountsWithQuery:allItemsQuery context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);

    XCTAssertTrue([results count] == 1);
    XCTAssertEqualObjects(results[0], [self createTestAccountCacheItem]);
}

- (void)testRemoveAccountsWithQuery_whenQueryIsNotExactMatch_shouldRemoveMatchedAccount
{
    [self saveAccount:[self createTestAccountCacheItem]];

    MSIDAccountCacheItem *account2 = [self createTestAccountCacheItem];
    account2.uniqueUserId = @"uid.utid2";

    [self saveAccount:account2];

    NSError *error = nil;

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    XCTAssertFalse(query.exactMatch);

    BOOL result = [self.cache removeAccountsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *results = [self.cache getAccountsWithQuery:query context:nil error:&error];
    XCTAssertNotNil(results);
    XCTAssertNil(error);

    XCTAssertTrue([results count] == 0);
}

#pragma mark - removeCredetialsWithQuery

- (void)testRemoveCredetialsWithQuery_whenQueryIsExactMatch_andAccessTokensQuery_shouldRemoveItem
{
    [self saveItem:[self createTestAccessTokenCacheItem]];

    MSIDCredentialCacheItem *token2 = [self createTestAccessTokenCacheItem];
    token2.uniqueUserId = @"uid.utid2";
    [self saveItem:token2];

    [self saveItem:[self createTestRefreshTokenCacheItem]];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.realm = @"contoso.com";
    query.uniqueUserId = @"uid.utid2";
    query.environment = @"login.microsoftonline.com";
    query.target = @"user.read user.write";
    query.clientId = @"client";
    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    BOOL result = [self.cache removeCredetialsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainignItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(remainignItems);
    XCTAssertTrue([remainignItems count] == 2);
    XCTAssertTrue([remainignItems containsObject:[self createTestAccessTokenCacheItem]]);
    XCTAssertTrue([remainignItems containsObject:[self createTestRefreshTokenCacheItem]]);
}

- (void)testRemoveCredetialsWithQuery_whenQueryIsExactMatch_andRefreshTokensQuery_shouldRemoveItem
{
    [self saveItem:[self createTestRefreshTokenCacheItem]];

    MSIDCredentialCacheItem *token2 = [self createTestRefreshTokenCacheItem];
    token2.uniqueUserId = @"uid.utid2";
    [self saveItem:token2];

    [self saveItem:[self createTestIDTokenCacheItem]];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.uniqueUserId = @"uid.utid2";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    BOOL result = [self.cache removeCredetialsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainignItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(remainignItems);
    XCTAssertTrue([remainignItems count] == 2);
    XCTAssertTrue([remainignItems containsObject:[self createTestRefreshTokenCacheItem]]);
    XCTAssertTrue([remainignItems containsObject:[self createTestIDTokenCacheItem]]);
}

- (void)testRemoveCredetialsWithQuery_whenQueryIsExactMatch_andIDTokensQuery_shouldRemoveItem
{
    [self saveItem:[self createTestIDTokenCacheItem]];

    MSIDCredentialCacheItem *token2 = [self createTestIDTokenCacheItem];
    token2.uniqueUserId = @"uid.utid2";
    [self saveItem:token2];

    [self saveItem:[self createTestRefreshTokenCacheItem]];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.uniqueUserId = @"uid.utid2";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.realm = @"contoso.com";
    XCTAssertTrue(query.exactMatch);

    NSError *error = nil;
    BOOL result = [self.cache removeCredetialsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainignItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(remainignItems);
    XCTAssertTrue([remainignItems count] == 2);
    XCTAssertTrue([remainignItems containsObject:[self createTestRefreshTokenCacheItem]]);
    XCTAssertTrue([remainignItems containsObject:[self createTestIDTokenCacheItem]]);
}

- (void)testRemoveCredetialsWithQuery_whenQueryIsNotExactMatch_andAccessTokensQuery_shouldRemoveAllItems
{
    [self saveItem:[self createTestAccessTokenCacheItem]];

    MSIDCredentialCacheItem *token2 = [self createTestAccessTokenCacheItem];
    token2.uniqueUserId = @"uid.utid2";
    [self saveItem:token2];

    [self saveItem:[self createTestRefreshTokenCacheItem]];

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.matchAnyCredentialType = YES;
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    XCTAssertFalse(query.exactMatch);

    NSError *error = nil;
    BOOL result = [self.cache removeCredetialsWithQuery:query context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSArray *remainignItems = [self.cache getAllItemsWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(remainignItems);
    XCTAssertTrue([remainignItems count] == 0);
}

#pragma mark - wipeInfoWithContext

#if TARGET_OS_IOS
- (void)testWipeInfoWithContext_whenNoWipeInfo_shouldReturnNil
{
    NSError *error = nil;
    NSDictionary *wipeInfo = [self.cache wipeInfoWithContext:nil error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, errSecItemNotFound);
    XCTAssertNil(wipeInfo);
}

- (void)testWipeInfoWithContext_whenWipeInfoPresent_shouldReturnWipeInfo
{
    MSIDKeychainTokenCache *keychainCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    NSError *error = nil;
    BOOL result = [keychainCache saveWipeInfoWithContext:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSDictionary *wipeInfo = [self.cache wipeInfoWithContext:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(wipeInfo);
    XCTAssertNotNil(wipeInfo[@"bundleId"]);
    XCTAssertNotNil(wipeInfo[@"wipeTime"]);
}
#endif

#pragma mark - Helpers

- (void)saveItem:(MSIDCredentialCacheItem *)item
{
    NSError *error = nil;
    BOOL result = [self.cache saveCredential:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (void)saveAccount:(MSIDAccountCacheItem *)item
{
    NSError *error = nil;
    BOOL result = [self.cache saveAccount:item context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
}

- (MSIDAccountCacheItem *)createTestAccountCacheItem
{
    MSIDAccountCacheItem *item = [MSIDAccountCacheItem new];
    item.accountType = MSIDAccountTypeMSSTS;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.realm = @"contoso.com";
    item.givenName = @"test user";
    item.legacyUserId = @"test 2";

    return item;
}

- (MSIDCredentialCacheItem *)createTestAccessTokenCacheItem
{
    MSIDCredentialCacheItem *item = [MSIDCredentialCacheItem new];
    item.credentialType = MSIDAccessTokenType;
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
    item.credentialType = MSIDRefreshTokenType;
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
    item.credentialType = MSIDIDTokenType;
    item.uniqueUserId = @"uid.utid";
    item.environment = @"login.microsoftonline.com";
    item.clientId = @"client";
    item.realm = @"contoso.com";

    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"Name" upn:upn tenantId:@"tid"];
    item.secret = idToken;

    return item;
}

@end
