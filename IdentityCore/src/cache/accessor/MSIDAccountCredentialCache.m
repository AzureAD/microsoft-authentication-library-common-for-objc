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

#import "MSIDAccountCredentialCache.h"
#import "MSIDTokenCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDDefaultTokenCacheKey.h"
#import "MSIDJsonSerializer.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDDefaultTokenCacheQuery.h"
#import "MSIDDefaultAccountCacheQuery.h"

@interface MSIDAccountCredentialCache()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_serializer;
}

@end

@implementation MSIDAccountCredentialCache

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];

    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDJsonSerializer alloc] init];
    }

    return self;
}

#pragma mark - Public

// Reading credentials
- (nullable NSArray<MSIDTokenCacheItem *> *)getCredentialsWithQuery:(nonnull MSIDDefaultTokenCacheQuery *)cacheQuery
                                                       legacyUserId:(nullable NSString *)legacyUserId
                                                            context:(nullable id<MSIDRequestContext>)context
                                                              error:(NSError * _Nullable * _Nullable)error
{
    NSError *cacheError = nil;

    NSArray<MSIDTokenCacheItem *> *results = [_dataSource tokensWithKey:cacheQuery
                                                             serializer:_serializer
                                                                context:context
                                                                  error:&cacheError];

    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }

        return nil;
    }

    if (!cacheQuery.exactMatch)
    {
        BOOL shouldMatchAccount = !cacheQuery.uniqueUserId || !cacheQuery.environment;

        NSMutableArray *filteredResults = [NSMutableArray array];

        for (MSIDTokenCacheItem *cacheItem in results)
        {
            if (shouldMatchAccount
                && ![cacheItem matchesWithUniqueUserId:cacheQuery.uniqueUserId environment:cacheQuery.environment])
            {
                continue;
            }

            if (legacyUserId
                && ![cacheItem matchesWithLegacyUserId:legacyUserId environment:cacheQuery.environment])
            {
                continue;
            }

            if (![cacheItem matchesWithRealm:cacheQuery.realm
                                    clientId:cacheQuery.clientId
                                      target:cacheQuery.target
                              targetMatching:cacheQuery.targetMatchingOptions])
            {
                continue;
            }

            [filteredResults addObject:cacheItem];
        }
    }

    return results;
}

- (nullable MSIDTokenCacheItem *)getCredential:(nonnull MSIDDefaultTokenCacheKey *)key
                                       context:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error
{
    assert(key);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get credential for key %@", key.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get credential for key %@", key.piiLogDescription);

    return [_dataSource tokenWithKey:key serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDTokenCacheItem *> *)getAllCredentialsWithType:(MSIDTokenType)type
                                                              context:(nullable id<MSIDRequestContext>)context
                                                                error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all credentials with type %@", [MSIDTokenTypeHelpers tokenTypeAsString:type]);

    MSIDDefaultTokenCacheQuery *query = [MSIDDefaultTokenCacheQuery new];
    query.credentialType = type;
    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}


// Reading accounts
- (nullable NSArray<MSIDAccountCacheItem *> *)getAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                                                           context:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get accounts with environment %@", cacheQuery.environment);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get accounts with environment %@, unique user id %@", cacheQuery.environment, cacheQuery.uniqueUserId);

    return [_dataSource accountsWithKey:cacheQuery serializer:_serializer context:context error:error];
}

- (nullable MSIDAccountCacheItem *)getAccount:(nonnull MSIDDefaultTokenCacheKey *)key
                                      context:(nullable id<MSIDRequestContext>)context
                                        error:(NSError * _Nullable * _Nullable)error
{
    assert(key);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get account for key %@", key.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get account for key %@", key.piiLogDescription);

    return [_dataSource accountWithKey:key serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDAccountCacheItem *> *)getAllAccountsWithType:(MSIDAccountType)type
                                                             context:(nullable id<MSIDRequestContext>)context
                                                               error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all accounts with type %@", [MSIDAccountTypeHelpers accountTypeAsString:type]);

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.accountType = MSIDAccountTypeAADV2;

    return [_dataSource accountsWithKey:query serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDTokenCacheItem *> *)getAllItemsWithContext:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all items from cache");

    MSIDDefaultTokenCacheQuery *query = [MSIDDefaultTokenCacheQuery new];
    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}

// Writing credentials
- (BOOL)saveCredential:(nonnull MSIDTokenCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Saving token %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:credential.tokenType], credential.authority, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Saving token %@ for userID %@ with authority %@, clientID %@,", credential, credential.uniqueUserId, credential.authority, credential.clientId);

    MSIDDefaultTokenCacheKey *key = [[MSIDDefaultTokenCacheKey alloc] initWithUniqueUserId:credential.uniqueUserId
                                                                               environment:credential.authority.msidHostWithPortIfNecessary];

    key.clientId = credential.clientId;
    key.realm = credential.authority.msidTenant;
    key.target = credential.target;
    key.credentialType = credential.tokenType;

    return [_dataSource saveToken:credential
                              key:key
                       serializer:_serializer
                          context:context
                            error:error];
}

// Writing accounts
- (BOOL)saveAccount:(nonnull MSIDAccountCacheItem *)account
            context:(nullable id<MSIDRequestContext>)context
              error:(NSError * _Nullable * _Nullable)error
{
    assert(account);

    MSID_LOG_VERBOSE(context, @"(Default cache) Saving account with environment %@", account.environment);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Saving account %@", account);

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithUniqueUserId:account.uniqueUserId environment:account.environment];

    key.username = account.username;
    key.accountType = account.accountType;

    // Get previous account, so we don't loose any fields
    MSIDAccountCacheItem *previousAccount = [_dataSource accountWithKey:key serializer:_serializer context:context error:error];

    if (previousAccount)
    {
        // Make sure we copy over all the additional fields
        [account updateFieldsFromAccount:previousAccount];
    }

    return [_dataSource saveAccount:account
                                key:key
                         serializer:_serializer
                            context:context
                              error:error];
}

// Remove credentials
- (BOOL)removeCredetialsWithQuery:(nonnull MSIDDefaultTokenCacheQuery *)cacheQuery
                          context:(nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@, unique user ID %@, target %@", [MSIDTokenTypeHelpers tokenTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId, cacheQuery.uniqueUserId, cacheQuery.target);

    if (cacheQuery.exactMatch)
    {
        return [_dataSource removeItemsWithKey:cacheQuery context:context error:error];
    }

    NSArray<MSIDTokenCacheItem *> *matchedCredentials = [self getCredentialsWithQuery:cacheQuery legacyUserId:nil context:context error:error];

    return [self removeAllCredentials:matchedCredentials
                              context:context
                                error:error];
}

- (BOOL)removeCredential:(nonnull MSIDTokenCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credential %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:credential.tokenType], credential.authority, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credential %@ for userID %@ with authority %@, clientID %@,", credential, credential.uniqueUserId, credential.authority, credential.clientId);

    MSIDDefaultTokenCacheKey *key = [[MSIDDefaultTokenCacheKey alloc] initWithUniqueUserId:credential.uniqueUserId
                                                                               environment:credential.authority.msidHostWithPortIfNecessary];

    key.clientId = credential.clientId;
    key.realm = credential.authority.msidTenant;
    key.target = credential.target;
    key.credentialType = credential.tokenType;

    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];

    if (result && credential.tokenType == MSIDTokenTypeRefreshToken)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];

        MSIDDefaultTokenCacheQuery *query = [MSIDDefaultTokenCacheQuery new];
        query.uniqueUserId = credential.uniqueUserId;
        query.environment = credential.authority.msidHostWithPortIfNecessary;
        query.clientId = credential.clientId;
        query.credentialType = MSIDTokenTypeIDToken;

        return [self removeCredetialsWithQuery:query context:context error:error];
    }

    return result;
}

// Remove accounts
- (BOOL)removeAccountsWithQuery:(nonnull MSIDDefaultTokenCacheQuery *)cacheQuery
                        context:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing accounts with environment %@, realm %@", cacheQuery.environment, cacheQuery.realm);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing accounts with environment %@, realm %@, unique user id %@", cacheQuery.environment, cacheQuery.realm, cacheQuery.uniqueUserId);

    return [_dataSource removeItemsWithKey:cacheQuery context:context error:error];
}

- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable * _Nullable)error
{
    assert(account);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing account with environment %@", account.environment);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing account with environment %@, user ID %@, username %@", account.environment, account.uniqueUserId, account.username);

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithUniqueUserId:account.uniqueUserId environment:account.environment];

    key.username = account.username;
    key.accountType = account.accountType;

    return [_dataSource removeItemsWithKey:key context:context error:error];
}

// Clear all
- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_WARN(context, @"(Default cache) Clearing the whole cache, this method should only be called in tests");
    MSIDDefaultTokenCacheQuery *query = [MSIDDefaultTokenCacheQuery new];
    return [_dataSource removeItemsWithKey:query context:context error:error];
}

- (BOOL)removeAllCredentials:(nonnull NSArray<MSIDTokenCacheItem *> *)credentials
                     context:(nullable id<MSIDRequestContext>)context
                       error:(NSError * _Nullable * _Nullable)error
{
    assert(credentials);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing multiple credentials");

    BOOL result = YES;

    for (MSIDTokenCacheItem *item in credentials)
    {
        result &= [self removeCredential:item context:context error:error];
    }

    return result;
}

- (nullable NSDictionary *)wipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error
{
    return [_dataSource wipeInfo:context error:error];
}

@end
