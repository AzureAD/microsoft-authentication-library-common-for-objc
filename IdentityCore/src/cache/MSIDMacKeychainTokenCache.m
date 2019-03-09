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
kSecValueData     JSON data (UTF8 encoded) – shared credentials (multiple credentials saved in one keychain item)

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

Type 2 (Non-secret shareable artifacts) Keychain Item Attributes
================================================================
ATTRIBUTE         VALUE
~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
kSecClass         kSecClassGenericPassword
kSecAttrAccount   <account_id>
kSecAttrService   <realm>
kSecAttrCreator   'MSAL' (A flag marking our items, see defaultAccountQuery:)
kSecValueData     JSON data (UTF8 encoded) – account object

 Type 2 JSON Data Example:
 {
   "home_account_id": "uid.utid",
   "environment": "login.microsoftonline.com",
   "realm": "Contoso.COM",
   "authority_type": "MSSTS",
   "username": "username",
   "given_name": "First name",
   "family_name": "Last name",
   "name": "test user",
   "local_account_id": "0000004-0000004-000004",
   "alternative_account_id": "alt",
   "test": "test2",
   "test3": "test4"
 }

Type 3 (Secret non-shareable artifacts) Keychain Item Attributes
===============================================================
ATTRIBUTE         VALUE
~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
kSecClass         kSecClassGenericPassword
kSecAttrAccount   <access_group>-<app_bundle_id>-<account_id>
kSecAttrService   <credential_id>-<target>
kSetAttrGeneric   <credential_id>
kSecAttrType      Numeric Value: 2001=Access Token 2002=Refresh Token (Phase 1) 2003=IdToken
kSecValueData     JSON data (UTF8 encoded) – credential object

Error handling:
* Generally this class has three error cases: success, recoverable
  error, and unrecoverable error. Whenever possible, recoverable
  errors should be handled here, locally, without surfacing them
  to the caller. (For example, when writing an account to the
  keychain, the SecItemUpdate() may fail since the item isn't in
  the keychian yet. This is normal, and the code continues using
  SecItemAdd() without returning an error. If this add failed, a
  non-recoverable error would be returned to the caller.) Where
  applicable, macOS keychain OSStatus results are surfaced to the
  caller as MSID-standard NSError objects.

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

- (id)init
{
    self = [super init];
    return self;
}

#pragma mark - Accounts

// Write an account to the macOS keychain cache.
//
// Errors:
// * MSIDErrorDomain/MSIDErrorInternal: invalid key or json deserialization error
// * MSIDKeychainErrorDomain/OSStatus: Apple status codes from SecItemUpdate()/SecItemAdd()
//
- (BOOL)saveAccount:(MSIDAccountCacheItem *)account
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    MSID_TRACE;
    MSID_LOG_INFO(context, @"Set keychain item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set keychain item, key info (account: %@ service: %@)", key.account, key.service);

    if (!key.service)
    {
        NSString *errorMessage = @"Set keychain item with invalid key (service is nil).";
        MSID_LOG_WARN(context, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, (NSInteger)MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    NSData *jsonData = [serializer serializeAccountCacheItem:account];
    if (!jsonData)
    {
        NSString *errorMessage = @"Failed to serialize account to json data.";
        MSID_LOG_WARN(context, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, (NSInteger)MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    NSMutableDictionary *query = [self defaultAccountQuery:key];
    NSMutableDictionary *update = [self defaultAccountUpdate:key];
    update[(id)kSecValueData] = jsonData;
    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)update);
    MSID_LOG_INFO(context, @"Keychain update status: %d", (int)status);

    if (status == errSecItemNotFound)
    {
        [query addEntriesFromDictionary:update];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_INFO(context, @"Keychain add status: %d", (int)status);
    }

    if (status != errSecSuccess)
    {
        NSString *errorMessage = @"Failed to write account to keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    return TRUE;
}

// Read a single account from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
//
// Errors:
// * MSIDErrorDomain/MSIDErrorCacheMultipleUsers: more than one keychain item matched the account key
//
- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSID_TRACE;
    NSArray<MSIDAccountCacheItem *> *items = [self accountsWithKey:key
                                                        serializer:serializer
                                                           context:context
                                                             error:error];

    if (items.count > 1)
    {
        if (error)
        {
            NSString *errorMessage = @"The token cache store for this resource contains more than one user";
            MSID_LOG_WARN(context, @"%@", errorMessage);
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, errorMessage, nil, nil, nil, context.correlationId, nil);
        }

        return nil;
    }

    return items.firstObject;
}

// Read one or more accounts from the keychain that match the key (see accountItem:matchesKey).
// If not found, return an empty list without setting an error.
//
// Errors:
// * MSIDKeychainErrorDomain/OSStatus: Apple status codes from SecItemCopyMatching()
//
- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    MSID_TRACE;
    NSMutableDictionary *query = [self defaultAccountQuery:key];
    // Per Apple's docs, kSecReturnData can't be combined with kSecMatchLimitAll:
    // https://developer.apple.com/documentation/security/1398306-secitemcopymatching?language=objc
    // For this reason, we retrieve references to the items, then (below) use a second SecItemCopyMatching()
    // to retrieve the data for each, deserializing each into an account object.
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnRef] = @YES;

    CFTypeRef cfItems = nil;
    MSID_LOG_INFO(context, @"Trying to find keychain items...");
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    MSID_LOG_INFO(context, @"Keychain find status: %d", (int)status);

    if (status == errSecItemNotFound)
    {
        return @[];
    }
    else if (status != errSecSuccess)
    {
        NSString *errorMessage = @"Failed to read account from keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }

    NSArray *items = CFBridgingRelease(cfItems);

    query = [self defaultAccountQuery:key];
    // Note: For efficiency, use kSecUseItemList to query the items returned above rather actually querying
    // the keychain again. With this second query we can set a specific kSecMatchLimit which lets us get the data
    // objects.
    query[(id)kSecUseItemList] = items;
    query[(id)kSecMatchLimit] = @(items.count + 1); // always set a limit > 1 so we consistently get an NSArray result
    query[(id)kSecReturnAttributes] = @YES;
    query[(id)kSecReturnData] = @YES;

    CFTypeRef cfItemDicts = nil;
    status = SecItemCopyMatching((CFDictionaryRef)query, &cfItemDicts);
    NSArray *itemDicts = CFBridgingRelease(cfItemDicts);

    NSMutableArray<MSIDAccountCacheItem *> *accountList = [NSMutableArray new];
    for (NSDictionary *dict in itemDicts)
    {
        NSData *jsonData = dict[(id)kSecValueData];
        if (jsonData)
        {
            MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[serializer deserializeAccountCacheItem:jsonData];
            if (account != nil)
            {
                [accountList addObject:account];
            }
            else
            {
                MSID_LOG_WARN(context, @"Failed to deserialize account");
            }
        }
    }
    return accountList;
}

// Remove one or more accounts from the keychain that match the key.
//
// Errors:
// * MSIDKeychainErrorDomain/OSStatus: Apple status codes from SecItemDelete()
//
- (BOOL)removeItemsWithAccountKey:(MSIDCacheKey *)key
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSID_TRACE;
    MSID_LOG_INFO( context, @"Remove keychain items, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Remove keychain items, key info (account: %@ service: %@)", key.account, key.service);

    if (!key)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Key is nil.", nil, nil, nil, context.correlationId, nil);
        }

        return FALSE;
    }

    NSMutableDictionary *query = [self defaultAccountQuery:key];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    MSID_LOG_INFO(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        NSString *errorMessage = @"Failed to remove multiple accounts from keychain";
        MSID_LOG_WARN(context, @"%@ (%d)", errorMessage, status);
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, (NSInteger)status, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return FALSE;
    }

    return TRUE;
}

#pragma mark - Credentials

// Write a credential to the macOS keychain cache.
- (BOOL)saveToken:(__unused MSIDCredentialCacheItem *)item
              key:(__unused MSIDCacheKey *)key
       serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
          context:(__unused id<MSIDRequestContext>)context
            error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return FALSE;
}

// Read a single credential from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
- (MSIDCredentialCacheItem *)tokenWithKey:(__unused MSIDCacheKey *)key
                               serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                  context:(__unused id<MSIDRequestContext>)context
                                    error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return nil;
}

// Read one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
// If not found, return an empty list without setting an error.
- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(__unused MSIDCacheKey *)key
                                           serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                              context:(__unused id<MSIDRequestContext>)context
                                                error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return nil;
}

// Remove one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
- (BOOL)removeItemsWithTokenKey:(__unused MSIDCacheKey *)key
                        context:(__unused id<MSIDRequestContext>)context
                          error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return FALSE;
}

#pragma mark - App Metadata

// Save MSIDAppMetadataCacheItem (clientId/environment/familyId) in the macOS keychain cache.
- (BOOL)saveAppMetadata:(__unused MSIDAppMetadataCacheItem *)item
                    key:(__unused MSIDCacheKey *)key
             serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                context:(__unused id<MSIDRequestContext>)context
                  error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return FALSE;
}

// Read MSIDAppMetadataCacheItem (clientId/environment/familyId) items from the macOS keychain cache.
- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(__unused MSIDCacheKey *)key
                                                        serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                                                           context:(__unused id<MSIDRequestContext>)context
                                                             error:(__unused NSError **)error
{
    [self createUnimplementedError:error context:context];
    return nil;
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeItemsWithMetadataKey:(__unused MSIDCacheKey *)key
                           context:(__unused id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    [self createUnimplementedError:error context:context];
    return FALSE;
}

#pragma mark - Wipe Info

// Saves information about the app which most-recently removed a token.
- (BOOL)saveWipeInfoWithContext:(__unused id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    [self createUnimplementedError:error context:context];
    return FALSE;
}

// Read information about the app which most-recently removed a token.
- (NSDictionary *)wipeInfo:(__unused id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    [self createUnimplementedError:error context:context];
    return nil;
}

#pragma mark - clear

// A test-only method that deletes all items from the cache for the given context.
- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_TRACE;
    MSID_LOG_WARN(context, @"Clearing the whole context. This should only be executed in tests");

    // for now, this just deletes all accounts
    return [self removeItemsWithAccountKey:[MSIDCacheKey new] context:context error:error];
}

#pragma mark - Utilities

// Get the basic/default keychain query dictionary for account items.
- (NSMutableDictionary *)defaultAccountQuery:(MSIDCacheKey *)key
{
    MSID_TRACE;
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;

    if (key.account.length > 0)
    {
        query[(id)kSecAttrAccount] = key.account; // <homeAccountId>-<environment>
    }
    if (key.service.length > 0)
    {
        query[(id)kSecAttrService] = key.service; // <realm>
    }

    // Add a marker for our cache items in the keychain.
    // It avoids keychain errors, in particular with clearWithContext.
    // This property is a FourCC integer, not a string:
    query[(id)kSecAttrCreator] = [NSNumber numberWithUnsignedInt:'MSAL'];
    // Note: Would something like this be better?
    // query[(id)kSecAttrSecurityDomain] = @"com.microsoft.msalcache";

    return query;
}

// Get the basic/default keychain update dictionary for account items.
// These are not _primary_ keys, but if they're present in the key object we
// want to set them when adding/updating.
- (NSMutableDictionary *)defaultAccountUpdate:(MSIDCacheKey *)key
{
    MSID_TRACE;
    NSMutableDictionary *update = [NSMutableDictionary new];

    if (key.generic.length > 0)
    {
        update[(id)kSecAttrGeneric] = key.generic;
    }
    if (key.type != nil)
    {
        update[(id)kSecAttrType] = key.type;
    }

    return update;
}

// Allocate a "Not Implemented" NSError object.
- (void)createUnimplementedError:(NSError *_Nullable *_Nullable)error
                         context:(id<MSIDRequestContext>)context
{
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, (NSInteger)MSIDErrorUnsupportedFunctionality, @"Not Implemented", nil, nil, nil, context.correlationId, nil);
    }
}

@end
