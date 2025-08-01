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
#import "MSIDAccountCacheItem+MSIDAccountMatchers.h"
#import "MSIDDefaultCredentialCacheKey.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDTokenCacheDataSource.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDCacheKey.h"
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAppMetadataCacheKey.h"
#import "MSIDAppMetadataCacheQuery.h"
#import "MSIDExtendedTokenCacheDataSource.h"
#import "MSIDConfiguration.h"
#import "MSIDConstants.h"
#import "MSIDJsonObject.h"
#import "MSIDFlightManager.h"

@interface MSIDAccountCredentialCache()
{
    MSIDCacheItemJsonSerializer *_serializer;
}

@end

static BOOL s_disableFRT = NO;

@implementation MSIDAccountCredentialCache

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDExtendedTokenCacheDataSource>)dataSource
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
                                                                   error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSString *className = NSStringFromClass(self.class);
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) retrieving cached credentials using credential query", className);
    NSError *cacheError = nil;
    
    NSArray<MSIDCredentialCacheItem *> *results = [_dataSource tokensWithKey:cacheQuery
                                                                  serializer:_serializer
                                                                     context:context
                                                                       error:&cacheError];

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) retrieved %ld cached credentials", className, (long)results.count);
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
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) credential query requires exact match with the cached credential items. Performing additional filtering checks.", className);
        for (MSIDCredentialCacheItem *cacheItem in results)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(%@) performing filtering check on cached credential item with the following properties - client ID: %@, target: %@, realm: %@, environment: %@, familyID: %@, homeAccountId: %@, enrollmentId: %@, appKey: %@, applicationIdentifier: %@, tokenType: %@", className, cacheItem.clientId, cacheItem.target, cacheItem.realm, cacheItem.environment, cacheItem.familyId, MSID_PII_LOG_TRACKABLE(cacheItem.homeAccountId), MSID_PII_LOG_MASKABLE(cacheItem.enrollmentId), MSID_PII_LOG_MASKABLE(cacheItem.appKey), MSID_EUII_ONLY_LOG_MASKABLE(cacheItem.applicationIdentifier), cacheItem.tokenType);
            if (shouldMatchAccount
                && ![cacheItem matchesWithHomeAccountId:cacheQuery.homeAccountId
                                           environment:cacheQuery.environment
                                    environmentAliases:cacheQuery.environmentAliases])
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(%@) cached item had mismatching homeAccountID or environment/aliases with the credential query. excluding from the results.", className);
                continue;
            }

            if (![cacheItem matchesWithRealm:cacheQuery.realm
                                    clientId:cacheQuery.clientId
                                    familyId:cacheQuery.familyId
                                      target:cacheQuery.target
                             requestedClaims:cacheQuery.requestedClaims
                              targetMatching:cacheQuery.targetMatchingOptions
                            clientIdMatching:cacheQuery.clientIdMatchingOptions])
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(%@) cached item had mismatching realm/clientId/familyId/target/requestedClaims with the credential query. excluding from the results.", className);
                continue;
            }
            
            [filteredResults addObject:cacheItem];
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) returning %ld filtered credentials", className, (long)filteredResults.count);
        return filteredResults;
    }
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) returning %ld credentials", className, (long)results.count);
    return results;
}

- (nullable MSIDCredentialCacheItem *)getCredential:(nonnull MSIDDefaultCredentialCacheKey *)key
                                       context:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(key);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Get credential for key %@, account %@", key.logDescription, MSID_EUII_ONLY_LOG_MASKABLE(key.account));

    return [_dataSource tokenWithKey:key serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllCredentialsWithType:(MSIDCredentialType)type
                                                              context:(nullable id<MSIDRequestContext>)context
                                                                error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Get all credentials with type %@", [MSIDCredentialTypeHelpers credentialTypeAsString:type]);

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = type;
    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}


// Reading accounts
- (nullable NSArray<MSIDAccountCacheItem *> *)getAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                                                           context:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Get accounts with environment %@, unique user id %@", cacheQuery.environment, MSID_PII_LOG_TRACKABLE(cacheQuery.homeAccountId));

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
                                        error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(key);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Get account for key %@, account %@", key.logDescription, MSID_EUII_ONLY_LOG_MASKABLE(key.account));

    return [_dataSource accountWithKey:key serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDAccountCacheItem *> *)getAllAccountsWithType:(MSIDAccountType)type
                                                             context:(nullable id<MSIDRequestContext>)context
                                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Get all accounts with type %@", [MSIDAccountTypeHelpers accountTypeAsString:type]);

    MSIDDefaultAccountCacheQuery *query = [MSIDDefaultAccountCacheQuery new];
    query.accountType = MSIDAccountTypeMSSTS;

    return [_dataSource accountsWithKey:query serializer:_serializer context:context error:error];
}

- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllItemsWithContext:(nullable id<MSIDRequestContext>)context
                                                             error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Get all items from cache");

    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.matchAnyCredentialType = YES;
    return [_dataSource tokensWithKey:query serializer:_serializer context:context error:error];
}

// Writing credentials
- (BOOL)saveCredential:(nonnull MSIDCredentialCacheItem *)credential
               context:(nullable id<MSIDRequestContext>)context
                 error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(credential);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Saving token %@ for userID %@ with environment %@, realm %@, clientID %@,", MSID_PII_LOG_MASKABLE(credential), MSID_PII_LOG_TRACKABLE(credential.homeAccountId), credential.environment, credential.realm, credential.clientId);
    
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    key.familyId = credential.familyId;
    key.tokenType = credential.tokenType;
    key.realm = credential.realm;
    key.target = credential.target;
    key.applicationIdentifier = credential.applicationIdentifier;
    key.requestedClaims = credential.requestedClaims;

    
    return [_dataSource saveToken:credential
                              key:key
                       serializer:_serializer
                          context:context
                            error:error];
}

// Writing accounts
- (BOOL)saveAccount:(nonnull MSIDAccountCacheItem *)account
            context:(nullable id<MSIDRequestContext>)context
              error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(account);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Saving account %@", MSID_EUII_ONLY_LOG_MASKABLE(account));

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                                                    environment:account.environment
                                                                                          realm:account.realm
                                                                                           type:account.accountType];
    
    MSIDAccountCacheItem *previousAccount = [_dataSource accountWithKey:key serializer:_serializer context:context error:error];
    
    if (previousAccount)
    {
        // Make sure we copy over all the additional fields
        NSMutableDictionary *mergedDictionary = [previousAccount.jsonDictionary mutableCopy];
        [mergedDictionary addEntriesFromDictionary:account.jsonDictionary];
        NSError *accountError;
        account = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:mergedDictionary error:&accountError];
        if (accountError || !account)
        {
            if (error)
            {
                *error = accountError;
            }
            return NO;
        }
    }
    
    key.username = account.username;
    
    return [_dataSource saveAccount:account
                                key:key
                         serializer:_serializer
                            context:context
                              error:error];
}

// Remove credentials
- (BOOL)removeCredentialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
                          context:(nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"(Default cache) Removing credentials with type %@, environment %@, realm %@, clientID %@, unique user ID %@, target %@", [MSIDCredentialTypeHelpers credentialTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId, MSID_PII_LOG_TRACKABLE(cacheQuery.homeAccountId), cacheQuery.target);

    if (cacheQuery.exactMatch)
    {
        return [_dataSource removeTokensWithKey:cacheQuery context:context error:error];
    }

    NSArray<MSIDCredentialCacheItem *> *matchedCredentials = [self getCredentialsWithQuery:cacheQuery context:context error:error];
    
    if (!matchedCredentials) return NO;

    return [self removeAllCredentials:matchedCredentials
                              context:context
                                error:error];
}

// Remove credentials
- (BOOL)removeExpiredAccessTokensCredentialsWithQuery:(nonnull MSIDDefaultCredentialCacheQuery *)cacheQuery
                          context:(nullable id<MSIDRequestContext>)context
                            error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(cacheQuery);
    cacheQuery.targetMatchingOptions = MSIDAny;
    cacheQuery.matchAnyCredentialType = NO;
    NSDate *currentDataAndTime = [NSDate date];
    NSMutableArray *resultsToDelete = [NSMutableArray array];
    NSString *className = NSStringFromClass(self.class);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"(Default cache) Removing expired credentials with type %@, environment %@, realm %@, clientID %@, unique user ID %@", [MSIDCredentialTypeHelpers credentialTypeAsString:cacheQuery.credentialType], cacheQuery.environment, cacheQuery.realm, cacheQuery.clientId, MSID_PII_LOG_TRACKABLE(cacheQuery.homeAccountId));

    if (cacheQuery.exactMatch)
    {
        return NO;
    }
    
    if (cacheQuery.credentialType != MSIDAccessTokenType)
    {
        return NO;
    }

    NSArray<MSIDCredentialCacheItem *> *matchedCredentials = [self getCredentialsWithQuery:cacheQuery context:context error:error];
    
    if (!matchedCredentials) return NO;
    
    // Check for expiry here to leave only expired ones in matchedCredentials
    for (MSIDCredentialCacheItem *cacheItem in matchedCredentials)
    {
        NSComparisonResult result = [currentDataAndTime compare:[cacheItem expiresOn]];
        if (result == NSOrderedDescending)
        {
            [resultsToDelete addObject:cacheItem];
        }
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"(%@) removing %ld expired AT cached credentials", className, (long)resultsToDelete.count);
    
    return [self removeAllCredentials:resultsToDelete
                              context:context
                                error:error];
}

- (BOOL)removeCredential:(nonnull MSIDCredentialCacheItem *)credential
                 context:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(credential);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"(Default cache) Removing credential %@ for userID %@ with environment %@, realm %@, clientID %@,", MSID_PII_LOG_MASKABLE(credential), MSID_PII_LOG_TRACKABLE(credential.homeAccountId), credential.environment, credential.realm, credential.clientId);

    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:credential.homeAccountId
                                                                                          environment:credential.environment
                                                                                             clientId:credential.clientId
                                                                                       credentialType:credential.credentialType];
    
    
    key.familyId = credential.familyId;
    key.realm = credential.realm;
    key.target = credential.target;
    key.applicationIdentifier = credential.applicationIdentifier;
    key.appKey = credential.appKey;
    key.tokenType = credential.tokenType;
    key.requestedClaims = credential.requestedClaims;
    
    BOOL result = [_dataSource removeTokensWithKey:key context:context error:error];
    
    if (result && (credential.credentialType == MSIDRefreshTokenType || credential.credentialType == MSIDFamilyRefreshTokenType))
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    
    return result;
}

// Remove accounts
- (BOOL)removeAccountsWithQuery:(nonnull MSIDDefaultAccountCacheQuery *)cacheQuery
                        context:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(cacheQuery);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Removing accounts with environment %@, realm %@, unique user id %@", cacheQuery.environment, cacheQuery.realm, MSID_PII_LOG_TRACKABLE(cacheQuery.homeAccountId));

    if (cacheQuery.exactMatch)
    {
        return [_dataSource removeAccountsWithKey:cacheQuery context:context error:error];
    }

    NSArray<MSIDAccountCacheItem *> *matchedAccounts = [self getAccountsWithQuery:cacheQuery context:context error:error];

    return [self removeAllAccounts:matchedAccounts context:context error:error];
}

- (BOOL)removeAccount:(nonnull MSIDAccountCacheItem *)account
              context:(nullable id<MSIDRequestContext>)context
                error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(account);

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"(Default cache) Removing account with environment %@, user ID %@, username %@", account.environment, MSID_PII_LOG_TRACKABLE(account.homeAccountId), MSID_PII_LOG_EMAIL(account.username));

    MSIDDefaultAccountCacheKey *key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:account.homeAccountId
                                                                                    environment:account.environment
                                                                                          realm:account.realm
                                                                                           type:account.accountType];
    
    return [_dataSource removeAccountsWithKey:key context:context error:error];
}

// Clear all
- (BOOL)clearWithContext:(nullable id<MSIDRequestContext>)context
                   error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"(Default cache) Clearing the whole cache, this method should only be called in tests");
    return [_dataSource clearWithContext:context error:error];
}

- (BOOL)removeAllCredentials:(nonnull NSArray<MSIDCredentialCacheItem *> *)credentials
                     context:(nullable id<MSIDRequestContext>)context
                       error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(credentials);

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Removing multiple credentials");

    BOOL result = YES;

    for (MSIDCredentialCacheItem *item in credentials)
    {
        result &= [self removeCredential:item context:context error:error];
    }

    return result;
}

- (BOOL)removeAllAccounts:(nonnull NSArray<MSIDAccountCacheItem *> *)accounts
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(accounts);

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Removing multiple accounts");

    BOOL result = YES;

    for (MSIDAccountCacheItem *item in accounts)
    {
        result &= [self removeAccount:item context:context error:error];
    }

    return result;
}

- (nullable NSDictionary *)wipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [_dataSource wipeInfo:context error:error];
}

- (BOOL)saveWipeInfoWithContext:(nullable id<MSIDRequestContext>)context
                          error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [_dataSource saveWipeInfoWithContext:context error:error];
}

// Writing metadata
- (BOOL)saveAppMetadata:(nonnull MSIDAppMetadataCacheItem *)metadata
                context:(nullable id<MSIDRequestContext>)context
                  error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(metadata);
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Saving app's metadata %@", MSID_PII_LOG_MASKABLE(metadata));
    
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
                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(appMetadata);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Removing app metadata with clientId %@, environment %@", appMetadata.clientId, appMetadata.environment);
    
    MSIDAppMetadataCacheKey *key = [[MSIDAppMetadataCacheKey alloc] initWithClientId:appMetadata.clientId
                                                                         environment:appMetadata.environment
                                                                            familyId:appMetadata.familyId
                                                                         generalType:MSIDAppMetadataType];
    
    return [_dataSource removeMetadataItemsWithKey:key context:context error:error];
}

- (nullable NSArray<MSIDAppMetadataCacheItem *> *)getAppMetadataEntriesWithQuery:(nonnull MSIDAppMetadataCacheQuery *)cacheQuery
                                                                         context:(nullable id<MSIDRequestContext>)context
                                                                           error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    assert(cacheQuery);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"(Default cache) Get app metadata entries with clientId %@, environment %@", cacheQuery.clientId, cacheQuery.environment);
    
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

- (MSIDIsFRTEnabledStatus)checkFRTEnabled:(nullable id<MSIDRequestContext>)context
                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    // This block will be used to check feature flags and update FRT settings if needed, depending on the current status
    // of the keychain item, avoiding an unnecessary read or update if status is the same
    MSIDIsFRTEnabledStatus (^checkFeatureFlagsAndReturn)(MSIDIsFRTEnabledStatus) = ^MSIDIsFRTEnabledStatus(MSIDIsFRTEnabledStatus status)
    {
        
        // Check if FRT is enabled by feature flight, possible values:
        // - MSID_FRT_STATUS_ENABLED => "on": FRT will be enabled
        // - MSID_FRT_STATUS_DISABLED => "off": FRT will be disabled
        // - nil, empty or any other value: no change to FRT
        MSIDFlightManager *flightManager = [MSIDFlightManager sharedInstance];
        NSString *flagEnableFRT = [flightManager stringForKey:MSID_FLIGHT_CLIENT_SFRT_STATUS];
        BOOL shouldEnableFRT = [MSID_FRT_STATUS_ENABLED isEqualToString:flagEnableFRT];
        BOOL shouldDisableFRT = [MSID_FRT_STATUS_DISABLED isEqualToString:flagEnableFRT];
        
        if ([NSString msidIsStringNilOrBlank:flagEnableFRT] || (!shouldEnableFRT && !shouldDisableFRT))
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"FRT flight set to keep current status: %ld", (long)status);
            return status;
        }
        MSIDIsFRTEnabledStatus newStatus = status;
        NSError *updateError = nil;
        
        switch (status)
        {
                // No entry in cache
            case MSIDIsFRTEnabledStatusNotEnabled:
                if (shouldEnableFRT)
                {
                    [self updateFRTSettings:YES context:context error:&updateError];
                    newStatus = MSIDIsFRTEnabledStatusEnabled;
                }
                break;
                
                // Deserialization error, try to enable/disable if needed
            case MSIDIsFRTEnabledStatusDisabledByDeserializationError:
                if (shouldEnableFRT)
                {
                    [self updateFRTSettings:YES context:context error:&updateError];
                    newStatus = MSIDIsFRTEnabledStatusEnabled;
                }
                else if (shouldDisableFRT)
                {
                    [self updateFRTSettings:NO context:context error:&updateError];
                    newStatus = MSIDIsFRTEnabledStatusDisabledByKeychainItem;
                }
                break;
                
                // FRT is currently enabled, check to see if should be disabled
            case MSIDIsFRTEnabledStatusEnabled:
                if (shouldDisableFRT)
                {
                    [self updateFRTSettings:NO context:context error:&updateError];
                    newStatus = MSIDIsFRTEnabledStatusDisabledByKeychainItem;
                    
                    if (updateError)
                    {
                        // Even if there was an error updating the item, we should still return Disabled so that the feature is not active.
                        status = MSIDIsFRTEnabledStatusDisabledByKeychainItem;
                    }
                }
                break;
                
            // FRT is disabled, check to see if should be enabled
            case MSIDIsFRTEnabledStatusDisabledByKeychainItem:
                if (shouldEnableFRT)
                {
                    [self updateFRTSettings:YES context:context error:&updateError];
                    newStatus = MSIDIsFRTEnabledStatusEnabled;
                }
                break;
                
                // Error reading keychain item, do not update settings
            case MSIDIsFRTEnabledStatusDisabledByKeychainError:
                break;
                
                // Feature is disabled by client app, do nothing with keychain item
            case MSIDIsFRTEnabledStatusDisabledByClientApp:
                break;
        }
        
        if (updateError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Error when trying to update FRT settings, error: %@", updateError);
            newStatus = status;
        }
        
        return newStatus;
    };
    
    // Check if FRT is disabled by client
    if (s_disableFRT)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"FRT disabled by MSAL client app, returning NO");
        return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusDisabledByClientApp);
    }
    
    NSError *readError = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [_dataSource jsonObjectsWithKey:[MSIDAccountCredentialCache checkFRTCacheKey]
                                                                  serializer:[MSIDCacheItemJsonSerializer new]
                                                                     context:context
                                                                       error:&readError];
    
    if (readError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to retrieve FRT cache entry, error: %@", readError);
        if (error)
        {
            *error = readError;
        }
        return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusDisabledByKeychainError);
    }
    
    if (![jsonObjects count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"No FRT cache entry found, returning NO");
        return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusNotEnabled);
    }
    
    NSDictionary *dict = [jsonObjects[0] jsonDictionary];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]] || [dict objectForKey:MSID_USE_SINGLE_FRT_KEY] == nil)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to deserialize FRT cache entry, returning NO");
        return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusDisabledByDeserializationError);
    }
    
    if ([dict msidBoolObjectForKey:MSID_USE_SINGLE_FRT_KEY])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"FRT is enabled");
        return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusEnabled);
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"FRT is disabled");
    return checkFeatureFlagsAndReturn(MSIDIsFRTEnabledStatusDisabledByKeychainItem);
}

- (void)updateFRTSettings:(BOOL)enableFRT
                  context:(nullable id<MSIDRequestContext>)context
                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Updating UseSingleFRT Item with enableFRT:%@", enableFRT ? @"YES" : @"NO");
    
    NSDictionary *settings = @{MSID_USE_SINGLE_FRT_KEY: @(enableFRT)};
    
    NSError *saveError = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:settings error:&saveError];

    [_dataSource saveJsonObject:jsonObject
                     serializer:[MSIDCacheItemJsonSerializer new]
                            key:[MSIDAccountCredentialCache checkFRTCacheKey]
                        context:context
                          error:&saveError];
    
    if (saveError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to save FRT cache entry, error: %@", saveError);
        if (error)
        {
            *error = saveError;
        }
    }
}

+ (void)setDisableFRT:(BOOL)disableFRT
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"DisableFRT has been explicitly set by client to: %@", disableFRT ? @"YES" : @"NO");
    s_disableFRT = disableFRT;
}

+ (MSIDCacheKey *)checkFRTCacheKey
{
    static MSIDCacheKey *cacheKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheKey = [[MSIDCacheKey alloc] initWithAccount:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                 service:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                 generic:nil
                                                    type:nil];
    });
    return cacheKey;
}

@end
