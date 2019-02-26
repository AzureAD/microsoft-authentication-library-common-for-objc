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

#import <Foundation/Foundation.h>
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountItemSerializer.h"
#import "MSIDAccountType.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDCredentialItemSerializer.h"
#import "MSIDCredentialType.h"
#import "MSIDError.h"
#import "MSIDJsonSerializer.h"
#import "MSIDLogger+Internal.h"
#import "MSIDLogger.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDUserInformation.h"
#import "NSString+MSIDExtensions.h"

/**
This Mac cache stores serialized account and credential objects in the macOS "login" Keychain.
There are three types of items stored:
  1) Secret shareable artifacts (SSO credentials: Refresh tokens, other global credentials)
  2) Non-secret shareable artifacts (account metadata)
  3) Secret non-shareable artifacts (access tokens, ID tokens)

In addition to the basic account & credential properties, the following definitions are used below:
<account_id>    : “<home_account_id>-<environment>”
<credential_id> : “<credential_type>-<client_id>-<realm>”
<access_group>  : e.g. "com.microsoft.officecache"


Type 1 (Secret shareable artifacts) Keychain Item Attributes
============================================================
ATTRIBUTE         VALUE
~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
kSecClass         kSecClassGenericPassword
kSecAttrAccount   <access_group>
kSecAttrService   “Microsoft Credentials”
kSecValueData     JSON data (UTF8 encoded) – shared credentials objects (multiple credentials saved in one keychain
item)

Type 2 (Non-secret shareable artifacts) Keychain Item Attributes
================================================================
ATTRIBUTE         VALUE
~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
kSecClass         kSecClassGenericPassword
kSecAttrAccount   <home_account_id>-<environment>
kSecAttrService   <realm>
kSecAttrCreator   'MSAL'
kSecValueData     JSON data (UTF8 encoded) – account object

Type 3 (Secret non-shareable artifacts) Keychain Item Attributes
===============================================================
ATTRIBUTE         VALUE
~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
kSecClass         kSecClassGenericPassword
kSecAttrAccount   <access_group>-<app_bundle_id>-<home_account_id>-<environment>
kSecAttrService   <credential_id>-<target>
kSetAttrGeneric   <credential_id>
kSecAttrType      Numeric Value: 2001=Access Token 2002=Refresh Token (Phase 1) 2003=IdToken
kSecValueData     JSON data (UTF8 encoded) – credential object


Type 1 JSON Data Example:
{
  "cache": {
    "credentials": {
      "account_id1": {
        "credential_id1": "credential1 payload",
        "credential_id2": "credential2 payload"
      },
      "account_id2": {
        "credential_id1": "credential1 payload",
        "credential_id2": "credential2 payload"
      }
    }
  }
}

Additional Notes:
* For a given <access_group>, multiple credentials are stored in
  a single Type 1 keychain item.  This is a work-around for a macOS
  keychain limitation related to ACLs (Access Control Lists) and
  is intended to minimize macOS keychain access prompts.  Once
  an application has access to the keychain item it can generally
  access and update credentials without further keychain prompts.

* Reference(s):
  - Apple Keychain Services: https://developer.apple.com/documentation/security/keychain_services?language=objc
  - Schema:
https://identitydivision.visualstudio.com/DevEx/_git/AuthLibrariesApiReview?path=%2FUnifiedSchema%2FSchema.md&version=GBdev

*/

@interface MSIDMacKeychainTokenCache ()
@end

@implementation MSIDMacKeychainTokenCache

#pragma mark - init

- (id)init {
    self = [super init];
    return self;
}

#pragma mark - Accounts

// Write an account to the macOS keychain cache.
- (BOOL)saveAccount:(MSIDAccountCacheItem *)account
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error {
    MSID_TRACE;
    MSID_LOG_INFO(
        context,
        @"Set keychain item, key info (account: %@ service: %@)",
        _PII_NULLIFY(key.account),
        _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set keychain item, key info (account: %@ service: %@)", key.account, key.service);

    NSData *jsonData = [serializer serializeAccountCacheItem:account];
    if (!jsonData) {
        NSString *errorMessage = @"Failed to serialize account to json data.";
        MSID_LOG_WARN(context, @"%@", errorMessage);
        if (error) {
            *error = MSIDCreateError(
                MSIDErrorDomain, (NSInteger)MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    NSMutableDictionary *query = [[self defaultAccountQuery:key] mutableCopy];
    NSDictionary *update = @{(id)kSecValueData: jsonData};

    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)update);
    MSID_LOG_INFO(context, @"Keychain update status: %d", (int)status);

    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:update];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_INFO(context, @"Keychain add status: %d", (int)status);
    }

    if (status != errSecSuccess) {
        NSString *errorMessage = @"Failed to write account to keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error) {
            *error = MSIDCreateError(
                NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    return TRUE;
}

// Read a single account from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error {
    MSID_TRACE;

    NSArray<MSIDAccountCacheItem *> *items = [self accountsWithKey:key
                                                        serializer:serializer
                                                           context:context
                                                             error:error];

    if (items.count > 1) {
        if (error) {
            NSString *errorMessage = @"The token cache store for this resource contains more than one user";
            MSID_LOG_WARN(context, @"%@", errorMessage);
            *error = MSIDCreateError(
                MSIDErrorDomain, MSIDErrorCacheMultipleUsers, errorMessage, nil, nil, nil, context.correlationId, nil);
        }

        return nil;
    }

    return items.firstObject;
}

// Read one or more accounts from the keychain that match the key (see accountItem:matchesKey).
// If not found, return an empty list without setting an error.
- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error {
    MSID_TRACE;

    NSMutableDictionary *query = [[self defaultAccountQuery:key] mutableCopy];
    // Per Apple's docs, kSecReturnData can't be combined with kSecMatchLimitAll:
    // https://developer.apple.com/documentation/security/1398306-secitemcopymatching?language=objc
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnRef] = @YES;

    CFTypeRef cfItems = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    NSArray *items = CFBridgingRelease(cfItems);
    if (status == errSecItemNotFound) {
        return @[];
    } else if (status != errSecSuccess) {
        NSString *errorMessage = @"Failed to read account from keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error) {
            *error = MSIDCreateError(
                NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }

    NSMutableDictionary *query2 = [[self defaultAccountQuery:key] mutableCopy];
    // Note: For efficiency, use kSecUseItemList to query the items returned above rather actually querying
    // the keychain again. With this second query we can set a specific kSecMatchLimit which lets us get the data
    // objects.
    query2[(id)kSecUseItemList] = items;
    query2[(id)kSecMatchLimit] = @(items.count + 1); // always set a limit > 1 so we consistently get an NSArray result
    query2[(id)kSecReturnAttributes] = @YES;
    query2[(id)kSecReturnData] = @YES;

    CFTypeRef cfItemDicts = nil;
    status = SecItemCopyMatching((CFDictionaryRef)query2, &cfItemDicts);
    NSArray *itemDicts = CFBridgingRelease(cfItemDicts);

    NSMutableArray<MSIDAccountCacheItem *> *accountList = [NSMutableArray new];
    for (NSDictionary *dict in itemDicts) {
        NSData *jsonData = dict[(id)kSecValueData];
        if (jsonData) {
            MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[serializer deserializeAccountCacheItem:jsonData];
            if (account == nil) {
                NSString *errorMessage = @"Failed to deserialize account";
                if (error) {
                    *error = MSIDCreateError(
                        MSIDErrorDomain, (NSInteger)MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
                }
                MSID_LOG_WARN(context, @"%@", errorMessage);
                continue;
            }
            [accountList addObject:account];
        }
    }
    return accountList;
}

// Remove one or more accounts from the keychain that match the key.
- (BOOL)removeItemsWithAccountKey:(MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError **)error {
    MSID_TRACE;
    MSID_LOG_INFO(
        context,
        @"Remove keychain items, key info (account: %@ service: %@)",
        _PII_NULLIFY(key.account),
        _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Remove keychain items, key info (account: %@ service: %@)", key.account, key.service);

    NSMutableDictionary *query = [[self defaultAccountQuery:key] mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    OSStatus status = SecItemDelete((CFDictionaryRef)query);

    if (status != errSecSuccess) {
        NSString *errorMessage = @"Failed to remove multiple accounts from keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error) {
            *error = MSIDCreateError(
                NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    return (status == errSecSuccess);
}

#pragma mark - Credentials

// Write a credential to the macOS keychain cache.
- (BOOL)saveToken:(__unused MSIDCredentialCacheItem *)item
              key:(__unused MSIDCacheKey *)key
       serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
          context:(__unused id<MSIDRequestContext>)context
            error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

// Read a single credential from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
- (MSIDCredentialCacheItem *)tokenWithKey:(__unused MSIDCacheKey *)key
                               serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                  context:(__unused id<MSIDRequestContext>)context
                                    error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return nil;
}

// Read one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
// If not found, return an empty list without setting an error.
- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(__unused MSIDCacheKey *)key
                                           serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                              context:(__unused id<MSIDRequestContext>)context
                                                error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return nil;
}

// Remove one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
- (BOOL)removeItemsWithTokenKey:(__unused MSIDCacheKey *)key
                        context:(__unused id<MSIDRequestContext>)context
                          error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

#pragma mark - App Metadata

// Save MSIDAppMetadataCacheItem (clientId/environment/familyId) in the macOS keychain cache.
- (BOOL)saveAppMetadata:(__unused MSIDAppMetadataCacheItem *)item
                    key:(__unused MSIDCacheKey *)key
             serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                context:(__unused id<MSIDRequestContext>)context
                  error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

// Read MSIDAppMetadataCacheItem (clientId/environment/familyId) items from the macOS keychain cache.
- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(__unused MSIDCacheKey *)key
                                                        serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                                                           context:(__unused id<MSIDRequestContext>)context
                                                             error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return nil;
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeItemsWithMetadataKey:(__unused MSIDCacheKey *)key
                           context:(__unused id<MSIDRequestContext>)context
                             error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

#pragma mark - Wipe Info

// Saves information about the app which most-recently removed a token.
- (BOOL)saveWipeInfoWithContext:(__unused id<MSIDRequestContext>)context error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

// Read information about the app which most-recently removed a token.
- (NSDictionary *)wipeInfo:(__unused id<MSIDRequestContext>)context error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return nil;
}

#pragma mark - clear

// A test-only method that deletes all items from the cache for the given context.
- (BOOL)clearWithContext:(id<MSIDRequestContext>)context error:(NSError **)error {
    MSID_TRACE;
    MSID_LOG_WARN(context, @"Clearing the whole context. This should only be executed in tests");

    NSMutableDictionary *query = [[self defaultAccountQuery:nil] mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound) {
        NSString *errorMessage = @"Failed to remove items from keychain.";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error) {
            *error = MSIDCreateError(
                MSIDKeychainErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    return TRUE;
}

#pragma mark - Utilities

// Get the basic/default keychain query dictionary for account items.
- (NSMutableDictionary *)defaultAccountQuery:(__unused MSIDCacheKey *)key {
    MSID_TRACE;
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;

    // Add a marker for our cache items in the keychain
    query[(id)kSecAttrCreator] = [NSNumber numberWithUnsignedInt:'MSAL'];
    // Note: Would this be better?
    // query[(id)kSecAttrSecurityDomain] = @"com.microsoft.msalcache";

    if (key.account.length > 0) {
        query[(id)kSecAttrAccount] = key.account; // <homeAccountId>-<environment>
    }
    if (key.service.length > 0) {
        query[(id)kSecAttrService] = key.service; // <realm>
    }
    // MSIDDefaultAccountCacheKey forces 0 to be kAccountTypePrefix (1000), so look at this later:
    // if (key.type != 0) {
    //    query[(id)kSecAttrType] = key.type;
    //}

    return query;
}

// Allocate a "Not Implemented" NSError object.
- (void)createUnimplementedError:(NSError *_Nullable *_Nullable)error {
    if (error) {
        *error = MSIDCreateError(
            MSIDErrorDomain, (NSInteger)MSIDErrorUnsupportedFunctionality, @"Not Implemented", nil, nil, nil, nil, nil);
    }
}

@end
