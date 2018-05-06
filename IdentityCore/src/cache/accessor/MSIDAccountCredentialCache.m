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
- (nullable NSArray<MSIDTokenCacheItem *> *)getCredentialsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                                                               environment:(nonnull NSString *)environment
                                                                     realm:(nullable NSString *)realm
                                                                  clientId:(nonnull NSString *)clientId
                                                                    target:(nullable NSString *)target
                                                                      type:(MSIDTokenType)type
                                                                   context:(nullable id<MSIDRequestContext>)context
                                                                     error:(NSError * _Nullable * _Nullable)error
{
    assert(uniqueUserId);
    assert(environment);
    assert(clientId);

    MSIDDefaultTokenCacheKey *query = [MSIDDefaultTokenCacheKey queryForCredentialsWithUniqueUserId:uniqueUserId
                                                                                        environment:environment
                                                                                           clientId:clientId
                                                                                              realm:realm
                                                                                             target:target
                                                                                               type:type];

    NSError *cacheError = nil;

    NSArray<MSIDTokenCacheItem *> *results = [_dataSource tokensWithKey:query
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

    /*
     If passed in realm is nil, it means "match all".
     However, because realm is part of generic and service keys,
     if realm is nil, it won't match by clientID and target either, so we need to do additional filtering.
     */

    if (!realm && (type == MSIDTokenTypeIDToken || type == MSIDTokenTypeAccessToken))
    {
        NSMutableArray *filteredResults = [NSMutableArray new];

        for (MSIDTokenCacheItem *item in results)
        {
            if ([item.clientId isEqualToString:clientId]
                && (!item.target || !target || [item.target isEqualToString:target]))
            {
                [filteredResults addObject:item];
            }
        }

        return filteredResults;
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

- (nullable NSArray<MSIDTokenCacheItem *> *)getCredentials:(nonnull MSIDDefaultTokenCacheKey *)query
                                                   context:(nullable id<MSIDRequestContext>)context
                                                     error:(NSError * _Nullable * _Nullable)error
{
    assert(query);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get credentials for query %@", query.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get credentials for query %@", query.piiLogDescription);

    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDTokenCacheItem *> *)getAllCredentialsWithType:(MSIDTokenType)type
                                                              context:(nullable id<MSIDRequestContext>)context
                                                                error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all credentials with type %@", [MSIDTokenTypeHelpers tokenTypeAsString:type]);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllTokensWithType:type];
    return [_dataSource tokensWithKey:key serializer:_serializer context:context error:error];
}


// Reading accounts
- (nullable NSArray<MSIDAccountCacheItem *> *)getAccountsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                                                              environment:(nonnull NSString *)environment
                                                                    realm:(nullable NSString *)realm
                                                                  context:(nullable id<MSIDRequestContext>)context
                                                                    error:(NSError * _Nullable * _Nullable)error
{
    assert(uniqueUserId);
    assert(environment);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get accounts with environment %@, realm %@",environment, realm);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get accounts with environment %@, realm %@, unique user id %@",environment, realm, uniqueUserId);

    MSIDDefaultTokenCacheKey *query = [MSIDDefaultTokenCacheKey queryForAccountsWithUniqueUserId:uniqueUserId
                                                                                     environment:environment
                                                                                           realm:realm];

    return [_dataSource accountsWithKey:query serializer:_serializer context:context error:error];
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

- (nullable NSArray<MSIDAccountCacheItem *> *)getAccounts:(nonnull MSIDDefaultTokenCacheKey *)query
                                                  context:(nullable id<MSIDRequestContext>)context
                                                    error:(NSError * _Nullable * _Nullable)error
{
    assert(query);

    MSID_LOG_VERBOSE(context, @"(Default cache) Get accounts for query %@", query.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Get accounts for query %@", query.piiLogDescription);

    return [_dataSource accountsWithKey:query serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDAccountCacheItem *> *)getAllAccountsWithType:(MSIDAccountType)type
                                                             context:(nullable id<MSIDRequestContext>)context
                                                               error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_VERBOSE(context, @"(Default cache) Get all accounts with type %@", [MSIDAccountTypeHelpers accountTypeAsString:type]);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccountsWithType:MSIDAccountTypeAADV2];
    return [_dataSource accountsWithKey:key serializer:_serializer context:context error:error];
}

// Writing credentials
- (BOOL)saveCredential:(nonnull MSIDTokenCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Saving token %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:credential.tokenType], credential.authority, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Saving token %@ for userID %@ with authority %@, clientID %@,", credential, credential.uniqueUserId, credential.authority, credential.clientId);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForCredentialWithUniqueUserId:credential.uniqueUserId
                                                                                   environment:credential.environment
                                                                                      clientId:credential.clientId
                                                                                         realm:credential.realm
                                                                                        target:credential.target
                                                                                          type:credential.tokenType];

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

    MSID_LOG_VERBOSE(context, @"(Default cache) Saving account with authority %@", account.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Saving account with authority %@, user ID %@", account.authority, account.uniqueUserId);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:account.uniqueUserId
                                                                                  authority:account.authority
                                                                                   username:account.username
                                                                                accountType:account.accountType];

    return [_dataSource saveAccount:account
                                key:key
                         serializer:_serializer
                            context:context
                              error:error];
}

// Remove credentials
- (BOOL)removeCredentialsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                              environment:(nonnull NSString *)environment
                                    realm:(nullable NSString *)realm
                                 clientId:(nonnull NSString *)clientId
                                   target:(nullable NSString *)target
                                     type:(MSIDTokenType)type
                                  context:(nullable id<MSIDRequestContext>)context
                                    error:(NSError * _Nullable * _Nullable)error
{
    assert(uniqueUserId);
    assert(environment);
    assert(clientId);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:type], environment, realm, clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@, unique user ID %@, target %@", [MSIDTokenTypeHelpers tokenTypeAsString:type], environment, realm, clientId, uniqueUserId, target);

    /*
     If passed in realm is nil, it means "match all".
     However, because realm is part of generic and service keys,
     if realm is nil, it won't match by clientID and target either, so we need to do additional filtering.
     */

    if (!realm && (type == MSIDTokenTypeIDToken || type == MSIDTokenTypeAccessToken))
    {
        NSArray<MSIDTokenCacheItem *> *matchedCredentials = [self getCredentialsWithUniqueUserId:uniqueUserId
                                                                                     environment:environment
                                                                                           realm:realm
                                                                                        clientId:clientId
                                                                                          target:target
                                                                                            type:type
                                                                                         context:context
                                                                                           error:error];

        return [self removeAllCredentials:matchedCredentials
                                  context:context
                                    error:error];

    }

    MSIDDefaultTokenCacheKey *query = [MSIDDefaultTokenCacheKey queryForCredentialsWithUniqueUserId:uniqueUserId
                                                                                        environment:environment
                                                                                           clientId:clientId
                                                                                              realm:realm
                                                                                             target:target
                                                                                               type:type];

    return [_dataSource removeItemsWithKey:query context:context error:error];
}

- (BOOL)removeCredential:(nonnull MSIDTokenCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    assert(credential);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credential %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:credential.tokenType], credential.authority, credential.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credential %@ for userID %@ with authority %@, clientID %@,", credential, credential.uniqueUserId, credential.authority, credential.clientId);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForCredentialWithUniqueUserId:credential.uniqueUserId
                                                                                   environment:credential.environment
                                                                                      clientId:credential.clientId
                                                                                         realm:credential.realm
                                                                                        target:credential.target
                                                                                          type:credential.tokenType];

    return [_dataSource removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeCredentials:(nonnull MSIDDefaultTokenCacheKey *)query
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable * _Nullable)error
{
    assert(query);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing credentials with query %@", query.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing credentials with query %@", query.piiLogDescription);

    return [_dataSource removeItemsWithKey:query context:context error:error];
}

// Remove accounts
- (BOOL)removeAccountsWithUniqueUserId:(nonnull NSString *)uniqueUserId
                           environment:(nonnull NSString *)environment
                                 realm:(nullable NSString *)realm
                               context:(nullable id<MSIDRequestContext>)context
                                 error:(NSError * _Nullable * _Nullable)error
{
    assert(uniqueUserId);
    assert(environment);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing accounts with environment %@, realm %@",environment, realm);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing accounts with environment %@, realm %@, unique user id %@",environment, realm, uniqueUserId);

    MSIDDefaultTokenCacheKey *query = [MSIDDefaultTokenCacheKey queryForAccountsWithUniqueUserId:uniqueUserId
                                                                                     environment:environment
                                                                                           realm:realm];

    return [_dataSource removeItemsWithKey:query context:context error:error];
}

- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable * _Nullable)error
{
    assert(account);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing account with authority %@", account.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing account with authority %@, user ID %@, username %@", account.authority, account.uniqueUserId, account.username);

    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:account.uniqueUserId
                                                                                  authority:account.authority
                                                                                   username:account.username
                                                                                accountType:account.accountType];

    return [_dataSource removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeAccounts:(nonnull MSIDDefaultTokenCacheKey *)query
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable * _Nullable)error
{
    assert(query);

    MSID_LOG_VERBOSE(context, @"(Default cache) Removing accounts with query %@", query.logDescription);
    MSID_LOG_VERBOSE_PII(context, @"(Default cache) Removing accounts with query %@", query.piiLogDescription);

    return [_dataSource removeItemsWithKey:query context:context error:error];
}

// Clear all
- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_WARN(context, @"(Default cache) Clearing the whole cache, this method should only be called in tests");
    return [_dataSource removeItemsWithKey:[MSIDTokenCacheKey queryForAllItems] context:context error:error];
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

@end
