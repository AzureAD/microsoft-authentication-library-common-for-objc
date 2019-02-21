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
kSecAttrAccount   <home_account_id>-<environment>-<realm>
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
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:update];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
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
                                 context:(__unused id<MSIDRequestContext>)context
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

    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    NSArray *items;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (void *)&items);
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

    NSMutableArray<MSIDAccountCacheItem *> *accountList = [NSMutableArray new];
    for (NSDictionary *itemDict in items) {
        if ([self accountItem:itemDict matchesKey:key]) {
            // This item matches the key, so try to deserialize it and allocate an account object for it
            NSMutableDictionary *itemQuery = [self defaultAccountQuery:nil];
            itemQuery[(id)kSecAttrAccount] = itemDict[(id)kSecAttrAccount];
            itemQuery[(id)kSecReturnData] = @YES;
            NSData *jsonData;
            status = SecItemCopyMatching((CFDictionaryRef)itemQuery, (void *)&jsonData);
            if (status != errSecSuccess) {
                if (error) {
                    NSString *errorMessage = @"Failed to read account from keychain";
                    MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
                    if (error) {
                        *error = MSIDCreateError(
                            NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
                    }
                }
                continue;
            }
            if (jsonData) {
                MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[serializer deserializeAccountCacheItem:jsonData];
                if (account == nil) {
                    NSString *errorMessage = @"Failed to deserialize account";
                    if (error) {
                        *error = MSIDCreateError(
                            MSIDErrorDomain,
                            (NSInteger)MSIDErrorInternal,
                            errorMessage,
                            nil,
                            nil,
                            nil,
                            context.correlationId,
                            nil);
                    }
                    MSID_LOG_WARN(context, @"%@", errorMessage);
                    continue;
                }
                [accountList addObject:account];
            }
        }
    }

    return accountList;
}

// Remove one or more accounts from the keychain that match the key (see accountItem:matchesKey).
- (BOOL)removeItemsWithAccountKey:(MSIDCacheKey *)key
                          context:(__unused id<MSIDRequestContext>)context
                            error:(NSError **)error {
    MSID_TRACE;
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    NSArray *items;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (void *)&items);

    if (status != errSecSuccess) {
        NSString *errorMessage = @"Failed to remove multiple accounts from keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error) {
            *error = MSIDCreateError(
                NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    NSInteger deleteCount = 0;
    for (NSDictionary *itemDict in items) {
        if ([self accountItem:itemDict matchesKey:key]) {
            // This item actually matches the key, so delete it
            NSMutableDictionary *deleteQuery = [self defaultAccountQuery:nil];
            deleteQuery[(id)kSecAttrAccount] = itemDict[(id)kSecAttrAccount];
            OSStatus delStatus = SecItemDelete((CFDictionaryRef)deleteQuery);
            if (status != errSecSuccess) {
                NSString *errorMessage = @"Failed to remove account from keychain";
                MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, delStatus);
                if (error) {
                    *error = MSIDCreateError(
                        NSOSStatusErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
                }
            }
            ++deleteCount;
        }
    }

    return (deleteCount > 0);
}

#pragma mark - Credentials

// Write an credential to the macOS keychain cache.
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
- (BOOL)clearWithContext:(__unused id<MSIDRequestContext>)context error:(__unused NSError **)error {
    [self createUnimplementedError:error];
    return FALSE;
}

#pragma mark - Utilities

// Get the basic/default keychain query dictionary for account items.
- (NSMutableDictionary *)defaultAccountQuery:(__unused MSIDCacheKey *)key {
    MSID_TRACE;
    NSMutableDictionary *query = [NSMutableDictionary new];

    // Note: this initial implementation follows the cache schema, relying only on the basic key
    // ("<homeAccountId>-<environment>-<realm>"). Additinal macOS-specific extensions
    // are deferred for now until they are required.
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    if (key.account) {
        query[(id)kSecAttrAccount] = key.account; // "<homeAccountId>-<environment>-<realm>"
    }

    return query;
}

// Determine whether the account item matches the cache key.
- (BOOL)accountItem:(NSDictionary *)itemDict matchesKey:(MSIDCacheKey *)key {
    MSID_TRACE;

    // The MSIDCacheKey "account" property for MSIDAccountCacheItems is "<homeAccountId>-<environment>-<realm>".
    // For multiple-account operations, it might be set to just "<homeAccountId>-<environment>-" or "<homeAccountId>--".
    // For comparisons, start by looking for a "--" in key.account. Since <homeAccountId> is required,
    // the double-dash is either at the end ("<homeAccountId>--") or in the middle ("<homeAccountId>--<realm>").
    // In both cases, everything to the left of the double-dash needs to appear at the beginning
    // of the keychain item's kSecAttrAccount attribute. If something appears after the double-dash,
    // it needs to appear at the end of the attribute. If the double-dash isn't present, use
    // the full key.account string for matching.
    NSString *prefix = @"";
    NSString *suffix = @"";

    NSArray<NSString *> *parts = [key.account componentsSeparatedByString:@"--"];
    if (parts.count > 0) {
        prefix = parts[0];
    }
    if (parts.count > 1) {
        suffix = parts[1];
    }

    NSString *accountAttr = itemDict[(id)kSecAttrAccount];
    return (
        ((prefix.length > 0 && [accountAttr hasPrefix:prefix]) && (suffix.length == 0 || [accountAttr hasSuffix:suffix]))
        || [accountAttr isEqualToString:key.account]);
}

// Allocate a "Not Implemented" NSError object.
- (void)createUnimplementedError:(NSError *_Nullable *_Nullable)error {
    if (error) {
        *error = MSIDCreateError(
            MSIDErrorDomain, (NSInteger)MSIDErrorUnsupportedFunctionality, @"Not Implemented", nil, nil, nil, nil, nil);
    }
}

@end
