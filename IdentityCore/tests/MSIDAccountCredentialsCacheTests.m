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

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByUniqueUserId_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByUniqueUserId_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironment_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironment_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironment_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByEnvironmentAliases_shouldReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andAccessTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andRefreshTokenQuery_matchByLegacyUserId_shouldNotReturnItems
{

}

- (void)testGetCredentialsWithQuery_whenNotExactMatch_andIDTokenQuery_matchByLegacyUserId_shouldReturnItems
{

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

@end
