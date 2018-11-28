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
#import "MSIDCredentialCacheItem.h"
#import "MSIDCredentialCacheItem+MSIDBaseToken.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDDefaultCredentialCacheKey.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDCacheKey.h"
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDAppMetaDataCacheItem.h"
#import "MSIDAppMetadataCacheKey.h"
#import "MSIDAppMetadataCacheQuery.h"

@interface MSIDAccountCredentialCache()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDCacheItemJsonSerializer *_serializer;
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
        _serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    }

    return self;
}

#pragma mark - Public

// Reading credentials
- (nullable NSArray<MSIDCredentialCacheItem *> *)getCredentialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
                                                                 context:(nullable id<MSIDRequestContext>)context
                                                                   error:(NSError * _Nullable * _Nullable)error
{
    NSError *cacheError = nil;

    NSArray<MSIDCredentialCacheItem *> *results = [_dataSource tokensWithKey:cacheQuery
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
        BOOL shouldMatchAccount = !cacheQuery.homeAccountId || !cacheQuery.environment;

        NSMutableArray *filteredResults = [NSMutableArray array];

        for (MSIDCredentialCacheItem *cacheItem in results)
        {
            if (shouldMatchAccount
                && ![cacheItem matchesWithHomeAccountId:cacheQuery.homeAccountId
                                           environment:cacheQuery.environment
                                    environmentAliases:cacheQuery.environmentAliases])
            {
                continue;
            }

            if (![cacheItem matchesWithRealm:cacheQuery.realm
                                    clientId:cacheQuery.clientId
                                    familyId:cacheQuery.familyId
                                      target:cacheQuery.target
                              targetMatching:cacheQuery.targetMatchingOptions
                            clientIdMatching:cacheQuery.clientIdMatchingOptions])
            {
                continue;
            }

            [filteredResults addObject:cacheItem];
        }

        return filteredResults;
    }

    return results;
}

- (nullable MSIDCredentialCacheItem *)getCredential:(nonnull MSIDDefaultCredentialCacheKey *)key
                                       context:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error
{
    assert(key);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get credential for key %@", key.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get credential for key %@", key.piiLogDescription);

    return [_dataSource tokenWithKey:key serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllCredentialsWithType:(MSIDCredentialType)type
                                                              context:(nullable id<MSIDRequestContext>)context
                                                                error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all credentials with type %@", [MSIDCredentialTypeHelpers credentialTypeAsString:type]);

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
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
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get accounts with environment %@, unique user id %@", cacheQuery.environment, cacheQuery.homeAccountId);

    NSArray<MSIDAccountCacheItem *> *cacheItems = [_dataSource accountsWithKey:cacheQuery serializer:_serializer context:context error:error];

    if (!cacheQuery.exactMatch)
    {
        NSMutableArray<MSIDAccountCacheItem *> *filteredResults = [NSMutableArray array];

        BOOL shouldMatchAccount = !cacheQuery.homeAccountId || !cacheQuery.environment;

        for (MSIDAccountCacheItem *cacheItem in cacheItems)
        {
            if (shouldMatchAccount
                && ![cacheItem matchesWithHomeAccountId:cacheQuery.homeAccountId
                                           environment:cacheQuery.environment
                                    environmentAliases:cacheQuery.environmentAliases])
            {
                continue;
            }

            [filteredResults addObject:cacheItem];
        }

        return filteredResults;
    }

    return cacheItems;
}

- (nullable MSIDAccountCacheItem *)getAccount:(nonnull MSIDDefaultCredentialCacheKey *)key
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
    query.accountType = MSIDAccountTypeMSSTS;

    return [_dataSource accountsWithKey:query serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllItemsWithContext:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all items from cache");

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.matchAnyCredentialType = YES;
    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}

// Writing credentials
- (BOOL)saveCredential:(nonnull MSIDCredentialCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Saving token %@ with environment %@, realm %@, clientID %@", [MSIDCredentialTypeHelpers credentialTypeAsString:credential.credentialType], credential.environment, credential.realm, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Saving token %@ for userID %@ with environment %@, realm %@, clientID %@,", credential, credential.homeAccountId, credential.environment, credential.environment, credential.clientId);

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                         environment:credential.environment
                                                                                            clientId:credential.clientId
                                                                                      credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

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

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                                                    environment:account.environment
                                                                                          realm:account.realm
                                                                                           type:account.accountType];

    key.username = account.username;

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
- (BOOL)removeCredetialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
                          context:(nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@", [MSIDCredentialTypeHelpers credentialTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@, unique user ID %@, target %@", [MSIDCredentialTypeHelpers credentialTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId, cacheQuery.homeAccountId, cacheQuery.target);

    if (cacheQuery.exactMatch)
    {
        return [_dataSource removeItemsWithKey:cacheQuery context:context error:error];
    }

    NSArray<MSIDCredentialCacheItem *> *matchedCredentials = [self getCredentialsWithQuery:cacheQuery context:context error:error];

    return [self removeAllCredentials:matchedCredentials
                              context:context
                                error:error];
}

- (BOOL)removeCredential:(nonnull MSIDCredentialCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credential %@ with environment %@, realm %@, clientID %@", [MSIDCredentialTypeHelpers credentialTypeAsString:credential.credentialType], credential.environment, credential.realm, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credential %@ for userID %@ with environment %@, realm %@, clientID %@,", credential, credential.homeAccountId, credential.environment, credential.realm, credential.clientId);

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                         environment:credential.environment
                                                                                            clientId:credential.clientId
                                                                                      credentialType:credential.credentialType];

    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;

    BOOL result = [_dataSource removeItemsWithKey:key context:context error:error];

    if (result && credential.credentialType == MSIDRefreshTokenType)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }

    return result;
}

// Remove accounts
- (BOOL)removeAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                        context:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing accounts with environment %@, realm %@", cacheQuery.environment, cacheQuery.realm);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing accounts with environment %@, realm %@, unique user id %@", cacheQuery.environment, cacheQuery.realm, cacheQuery.homeAccountId);

    if (cacheQuery.exactMatch)
    {
        return [_dataSource removeItemsWithKey:cacheQuery context:context error:error];
    }

    NSArray<MSIDAccountCacheItem *> *matchedAccounts = [self getAccountsWithQuery:cacheQuery context:context error:error];

    return [self removeAllAccounts:matchedAccounts context:context error:error];
}

- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable * _Nullable)error
{
    assert(account);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing account with environment %@", account.environment);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing account with environment %@, user ID %@, username %@", account.environment, account.homeAccountId, account.username);

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                                                   environment:account.environment
                                                                                         realm:account.realm
                                                                                          type:account.accountType];

    return [_dataSource removeItemsWithKey:key context:context error:error];
}

// Clear all
- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_WARN(context, @"(Default cache) Clearing the whole cache, this method should only be called in tests");
    return [_dataSource clearWithContext:context error:error];
}

- (BOOL)removeAllCredentials:(nonnull NSArray<MSIDCredentialCacheItem *> *)credentials
                     context:(nullable id<MSIDRequestContext>)context
                       error:(NSError * _Nullable * _Nullable)error
{
    assert(credentials);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing multiple credentials");

    BOOL result = YES;

    for (MSIDCredentialCacheItem *item in credentials)
    {
        result &= [self removeCredential:item context:context error:error];
    }

    return result;
}

- (BOOL)removeAllAccounts:(nonnull NSArray<MSIDAccountCacheItem *> *)accounts
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable * _Nullable)error
{
    assert(accounts);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing multiple accounts");

    BOOL result = YES;

    for (MSIDAccountCacheItem *item in accounts)
    {
        result &= [self removeAccount:item context:context error:error];
    }

    return result;
}

- (nullable NSDictionary *)wipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable * _Nullable)error
{
    return [_dataSource wipeInfo:context error:error];
}

- (BOOL)saveWipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable * _Nullable)error
{
    return [_dataSource saveWipeInfoWithContext:context error:error];
}

// Writing metadata
- (BOOL)saveAppMetadata:(nonnull MSIDAppMetadataCacheItem *)metadata
                context:(nullable id<MSIDRequestContext>)context
                  error:(NSError * _Nullable * _Nullable)error
{
    assert(metadata);
    
    MSID_LOG_VERBOSE(context, @"Saving app's metadata with clientId %@", metadata.clientId);
    MSID_LOG_VERBOSE_PII(context, @"Saving app's metadata %@", metadata);
    
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:metadata.clientId
                                                                         environment:metadata.environment
                                                                            familyId:metadata.familyId
                                                                         generalType:MSIDAppMetadataType];

    return [_dataSource saveAppMetadata:metadata
                                    key:key
                             serializer:_serializer
                                context:context
                                  error:error];
}

- (BOOL)removeAppMetadata:(nonnull MSIDAppMetadataCacheItem *)appMetadata
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable * _Nullable)error
{
    assert(appMetadata);
    
    MSID_LOG_VERBOSE(context, @"(Default cache) Removing app metadata with clientId %@, environment %@", appMetadata.clientId, appMetadata.environment);
    
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata.clientId
                                                                         environment:appMetadata.environment
                                                                            familyId:appMetadata.familyId
                                                                         generalType:MSIDAppMetadataType];
    
    return [_dataSource removeItemsWithKey:key context:context error:error];
}

- (nullable NSArray<MSIDAppMetadataCacheItem *> *)getAppMetadataEntriesWithQuery:(nonnull MSIDAppMetadataCacheQuery *)cacheQuery
                                                                         context:(nullable id<MSIDRequestContext>)context
                                                                           error:(NSError * _Nullable * _Nullable)error
{
    assert(cacheQuery);
    
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get app metadata entries with clientId %@, environment %@", cacheQuery.clientId, cacheQuery.environment);
    
    NSArray<MSIDAppMetadataCacheItem *> *cacheItems = [_dataSource appMetadataEntriesWithKey:cacheQuery serializer:_serializer context:context error:error];
    
    if (!cacheQuery.exactMatch)
    {
        NSMutableArray<MSIDAppMetadataCacheItem *> *filteredResults = [NSMutableArray array];
        
        BOOL shouldMatchMetadata = cacheQuery.clientId || cacheQuery.environment || [cacheQuery.environmentAliases count];
        
        if (shouldMatchMetadata)
        {
            for (MSIDAppMetadataCacheItem *cacheItem in cacheItems)
            {
                if (shouldMatchMetadata
                    && ![cacheItem matchesWithClientId:cacheQuery.clientId
                                           environment:cacheQuery.environment
                                    environmentAliases:cacheQuery.environmentAliases])
                {
                    continue;
                }
                
                [filteredResults addObject:cacheItem];
            }
            
            return filteredResults;
        }
    }
    
    return cacheItems;
}

@end
