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
#import "MSIDKeychainUtil.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDAppMetadataItemSerializer.h"

/**
 This Mac cache stores serialized account and credential objects in the macOS "login" Keychain.
 There are three types of items stored:
 1) Secret shareable artifacts (SSO credentials: Refresh tokens, other global credentials)
 2) Non-secret shareable artifacts (account metadata)
 3) Secret non-shareable artifacts (access tokens, ID tokens)
 
 In addition to the basic account & credential properties, the following definitions are used below:
 <account_id>    :  “<home_account_id>-<environment>”
 <credential_id> : “<credential_type>-<client_id>-<realm>”
 <access_group>  : e.g. "com.microsoft.officecache"
 <username>      : e.g. "joe@contoso.com"
 
 Below, attributes marked with "*" are primary keys for the keychain.
 For password items, the primary attributes are kSecAttrAccount and kSecAttrService.
 Other secondary attributes do not make items unique, only the primary attributes.
 
 Type 1 (Secret shareable artifacts) Keychain Item Attributes
 ============================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>
 *kSecAttrService  “Microsoft Credentials”
 kSecAttrCreator   A hash of <access_group>
 kSecAttrLabel     "Microsoft Credentials"
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
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>-<account_id>
 *kSecAttrService  <realm>
 kSecAttrGeneric   <username>
 kSecAttrCreator   A hash of <access_group>
 kSecAttrLabel     "Microsoft Credentials"
 kSecValueData     JSON data (UTF8 encoded) – account object
 
 Type 2 JSON Data Example:
 {
 "home_account_id": "9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
 "environment": "login.microsoftonline.com",
 "realm": "f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
 "authority_type": "MSSTS",
 "username": "testuser@contoso.com",
 "given_name": "First Name",
 "family_name": "Last Name",
 "name": "Test Username",
 "local_account_id": "9f4880d8-80ba-4c40-97bc-f7a23c703084",
 "alternative_account_id": "alt",
 "test": "test2",
 "test3": "test4"
 }
 
 Type 3 (Secret non-shareable artifacts) Keychain Item Attributes
 ===============================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>-<app_bundle_id>-<account_id>
 *kSecAttrService  <credential_id>-<target>
 kSetAttrGeneric   <credential_id>
 kSecAttrType      Numeric Value: 2001=Access Token 2002=Refresh Token (Phase 1) 2003=IdToken
 kSecAttrCreator   A hash of <access_group>
 kSecAttrLabel     "Microsoft Credentials"
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
 
 Reference(s):
 * Apple Keychain Services: https://developer.apple.com/documentation/security/keychain_services?language=objc
 * Schema:
 https://identitydivision.visualstudio.com/DevEx/_git/AuthLibrariesApiReview?path=%2FUnifiedSchema%2FSchema.md&version=GBdev
 
 */

static NSString *s_defaultKeychainGroup = @"com.microsoft.identity.universalstorage";
static NSString *s_defaultKeychainLabel = @"Microsoft Credentials";
static MSIDMacKeychainTokenCache *s_defaultCache = nil;
static dispatch_queue_t s_synchronizationQueue;

@interface MSIDMacKeychainTokenCache ()

@property (readwrite, nonnull) NSString *keychainGroup;
@property (readwrite, nonnull) NSDictionary *defaultCacheQuery;
@property (readwrite, nonnull) NSString *appIdentifier;

@end

@implementation MSIDMacKeychainTokenCache

#pragma mark - Public

+ (NSString *)defaultKeychainGroup
{
    return s_defaultKeychainGroup;
}

// Set the default keychain group
//
// Errors:
// * @throw - attempt to change the default keychain group after being initialized
//
+ (void)setDefaultKeychainGroup:(NSString *)defaultKeychainGroup
{
    MSID_TRACE;

    if (s_defaultCache)
    {
        MSID_LOG_ERROR(nil, @"Failed to set default keychain group, default keychain cache has already been instantiated.");

        @throw @"Attempting to change the keychain group once AuthenticationContexts have been created or the default keychain cache has been retrieved is invalid. The default keychain group should only be set once for the lifetime of an application.";
    }

    MSID_LOG_INFO(nil, @"Setting default keychain group.");
    MSID_LOG_INFO_PII(nil, @"Setting default keychain group to %@", defaultKeychainGroup);

    if ([defaultKeychainGroup isEqualToString:s_defaultKeychainGroup])
    {
        return;
    }

    if (!defaultKeychainGroup)
    {
        defaultKeychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }

    s_defaultKeychainGroup = [defaultKeychainGroup copy];
}

+ (MSIDMacKeychainTokenCache *)defaultKeychainCache
{
    static dispatch_once_t s_once;

    dispatch_once(&s_once, ^{
        s_defaultCache = [MSIDMacKeychainTokenCache new];
    });

    return s_defaultCache;
}

#pragma mark - init

// Initialize with defaultKeychainGroup
- (nonnull instancetype)init
{
    return [self initWithGroup:s_defaultKeychainGroup];
}

// Initialize with a keychain group
//
// @param keychainGroup Optional. If the application needs to share the cached tokens
// with other applications from the same vendor, the app will need to specify the
// shared group here. If set to 'nil' the main bundle's identifier will be used instead.
//
- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup
{
    MSID_TRACE;

    self = [super init];
    if (self)
    {
        if (!keychainGroup)
        {
            keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
        }

        MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
        if (!keychainUtil.teamId) return nil;
        
        // Add team prefix to keychain group if it is missed.
        if (![keychainGroup hasPrefix:keychainUtil.teamId])
        {
            keychainGroup = [keychainUtil accessGroup:keychainGroup];
        }

        self.keychainGroup = keychainGroup;

        if (!self.keychainGroup)
        {
            return nil;
        }

        self.appIdentifier = [NSString stringWithFormat:@"%@;%d", NSBundle.mainBundle.bundleIdentifier,
                              NSProcessInfo.processInfo.processIdentifier];;

        // Note: Apple seems to recommend serializing keychain API calls on macOS in this document:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/working_with_concurrency?language=objc
        // However, it's not entirely clear if this applies to all keychain APIs.
        // Since our applications often perform a large number of cache reads on mulitple threads, it would be preferable to
        // allow concurrent readers, even if writes are serialized. For this reason this is a concurrent queue, and the
        // dispatch queue calls are used. We intend to clarify this behavior with Apple.
        //
        // To protect the underlying keychain API, a single queue is used even if multiple instances of this class are allocated.
        static dispatch_once_t s_once;
        dispatch_once(&s_once, ^{
            s_synchronizationQueue = dispatch_queue_create("com.microsoft.msidmackeychaintokencache", DISPATCH_QUEUE_CONCURRENT);
        });

        self.defaultCacheQuery = @{
                                   // All account items are saved as generic passwords.
                                   (id)kSecClass: (id)kSecClassGenericPassword,
                                   
                                   // Add the access group as it's own field for query filtering.
                                   // Since the attribute is an NSNumber, hash the string.
                                   (id)kSecAttrCreator: [NSNumber numberWithUnsignedInt:(uint32_t)self.keychainGroup.hash],
                                   
                                   // Add a marker for all cache items in the keychain for additional query filtering.
                                   (id)kSecAttrLabel: s_defaultKeychainLabel
                                   
                                   };


        MSID_LOG_INFO(nil, @"Init MSIDMacKeychainTokenCache with keychainGroup: %@", [self keychainGroupLoggingName]);
        MSID_LOG_INFO_PII(nil, @"Init MSIDMacKeychainTokenCache with keychainGroup: %@", self.keychainGroup);
    }

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
    assert(account);
    assert(serializer);
    [self updateLastModifiedForAccount:account context:context];
    NSData *itemData = [serializer serializeAccountCacheItem:account];

    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_ERROR(context, @"Failed to serialize account item.");
        }
        return NO;
    }

    MSID_LOG_INFO_PII(context, @"Saving keychain item, item info %@", account);

    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
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
        [self createError:@"The token cache store for this resource contains more than one user"
                   domain:MSIDErrorDomain errorCode:MSIDErrorCacheMultipleUsers error:error context:context];
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
    NSArray *accountItems = [self itemsWithKey:key context:context error:error];

    if (!accountItems)
    {
        return nil;
    }

    NSMutableArray<MSIDAccountCacheItem *> *accountList = [NSMutableArray new];
    for (NSDictionary *dict in accountItems)
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
    return [self removeItemsWithKey:key context:context error:error];
}

#pragma mark - Credentials

// Write a credential to the macOS keychain cache.
- (BOOL)saveToken:(__unused MSIDCredentialCacheItem *)credential
              key:(__unused MSIDCacheKey *)key
       serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
          context:(__unused id<MSIDRequestContext>)context
            error:(__unused NSError **)error
{
    assert(credential);
    assert(serializer);
    [self updateLastModifiedForCredential:credential context:context];
    NSData *itemData = [serializer serializeCredentialCacheItem:credential];

    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_ERROR(context, @"Failed to serialize account item.");
        }
        
        return NO;
    }

    MSID_LOG_INFO_PII(context, @"Saving keychain item, item info %@", credential);

    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

// Read a single credential from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
- (MSIDCredentialCacheItem *)tokenWithKey:(__unused MSIDCacheKey *)key
                               serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                  context:(__unused id<MSIDRequestContext>)context
                                    error:(__unused NSError **)error
{
    MSID_TRACE;
    NSArray<MSIDCredentialCacheItem *> *items = [self tokensWithKey:key
                                                         serializer:serializer
                                                            context:context
                                                              error:error];
    
    if (items.count > 1)
    {
        MSID_LOG_ERROR(context, @"The token cache store for this resource contains more than one token");
        [self createError:@"The token cache store for this resource contains more than one token"
                   domain:MSIDErrorDomain errorCode:MSIDErrorCacheMultipleUsers error:error context:context];
        return nil;
    }

    return items.firstObject;
}

// Read one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
// If not found, return an empty list without setting an error.
- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(__unused MSIDCacheKey *)key
                                           serializer:(__unused id<MSIDCredentialItemSerializer>)serializer
                                              context:(__unused id<MSIDRequestContext>)context
                                                error:(__unused NSError **)error
{
    NSArray *tokenItems = [self itemsWithKey:key context:context error:error];

    if (!tokenItems)
    {
        return nil;
    }

    NSMutableArray<MSIDCredentialCacheItem *> *tokenList = [NSMutableArray new];
    for (NSDictionary *dict in tokenItems)
    {
        NSData *jsonData = dict[(id)kSecValueData];
        if (jsonData)
        {
            MSIDCredentialCacheItem *cacheItem = (MSIDCredentialCacheItem *)[serializer deserializeCredentialCacheItem:jsonData];
            if (cacheItem != nil)
            {
                [tokenList addObject:cacheItem];
            }
            else
            {
                MSID_LOG_WARN(context, @"Failed to deserialize account");
            }
        }
    }
    return tokenList;
}

// Remove one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
- (BOOL)removeItemsWithTokenKey:(__unused MSIDCacheKey *)key
                        context:(__unused id<MSIDRequestContext>)context
                          error:(__unused NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

#pragma mark - App Metadata

// Save MSIDAppMetadataCacheItem (clientId/environment/familyId) in the macOS keychain cache.
- (BOOL)saveAppMetadata:(__unused MSIDAppMetadataCacheItem *)metadata
                    key:(__unused MSIDCacheKey *)key
             serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                context:(__unused id<MSIDRequestContext>)context
                  error:(__unused NSError **)error
{
    assert(metadata);
    assert(serializer);

    NSData *itemData = [serializer serializeAppMetadataCacheItem:metadata];

    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize app metadata item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize app metadata item.");
        return NO;
    }

    MSID_LOG_INFO_PII(context, @"Saving keychain item, item info %@", metadata);

    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

// Read MSIDAppMetadataCacheItem (clientId/environment/familyId) items from the macOS keychain cache.
- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(__unused MSIDCacheKey *)key
                                                        serializer:(__unused id<MSIDAppMetadataItemSerializer>)serializer
                                                           context:(__unused id<MSIDRequestContext>)context
                                                             error:(__unused NSError **)error
{
    NSArray *items = [self itemsWithKey:key context:context error:error];

    if (!items)
    {
        return nil;
    }

    NSMutableArray *appMetadataitems = [[NSMutableArray<MSIDAppMetadataCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDAppMetadataCacheItem *appMetadata = [serializer deserializeAppMetadataCacheItem:itemData];
        
        if (appMetadata)
        {
            [appMetadataitems addObject:appMetadata];
        }
        else
        {
            MSID_LOG_INFO(context, @"Failed to deserialize app metadata item.");
        }
    }

    MSID_LOG_VERBOSE(context, @"Found %lu items.", (unsigned long)appMetadataitems.count);

    return appMetadataitems;
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeItemsWithMetadataKey:(__unused MSIDCacheKey *)key
                           context:(__unused id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (NSArray *)itemsWithKey:(MSIDCacheKey *)key
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    MSID_TRACE;
    NSString *account = key.account;
    NSString *service = key.service;

    MSID_LOG_VERBOSE(context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@, keychainGroup: %@)", _PII_NULLIFY(account), service, _PII_NULLIFY(key.generic), key.type, [self keychainGroupLoggingName]);
    MSID_LOG_VERBOSE_PII(context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@, keychainGroup: %@)", account, service, key.generic, key.type, self.keychainGroup);

    NSMutableDictionary *cacheQuery = [self primaryAttributesForKey:key];
    [cacheQuery addEntriesFromDictionary:[self secondaryAttributesForKey:key]];
    
    // Per Apple's docs, kSecReturnData can't be combined with kSecMatchLimitAll:
    // https://developer.apple.com/documentation/security/1398306-secitemcopymatching?language=objc
    // For this reason, we retrieve references to the items, then (below) use a second SecItemCopyMatching()
    // to retrieve the data for each, deserializing each into an account object.
    NSMutableDictionary *query = [cacheQuery mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnRef] = @YES;

    MSID_LOG_INFO(context, @"Trying to find keychain items...");
    __block CFTypeRef cfItems = nil;
    __block OSStatus status;
    dispatch_sync(s_synchronizationQueue, ^{
        status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    });
    MSID_LOG_INFO(context, @"Keychain find status: %d", (int)status);

    if (status == errSecItemNotFound)
    {
        MSID_LOG_INFO(context, @"item not found");
        return @[];
    }
    else if (status != errSecSuccess)
    {
        [self createError:@"Failed to read item from keychain"
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return nil;
    }

    NSArray *items = CFBridgingRelease(cfItems);
    
    // Note: For efficiency, use kSecUseItemList to query the items returned above rather actually querying
    // the keychain again. With this second query we can set a specific kSecMatchLimit which lets us get the data
    // objects.
    query = [cacheQuery mutableCopy];
    query[(id)kSecUseItemList] = items;
    query[(id)kSecMatchLimit] = @(items.count + 1); // always set a limit > 1 so we consistently get an NSArray result
    query[(id)kSecReturnAttributes] = @YES;
    query[(id)kSecReturnData] = @YES;

    __block CFTypeRef cfItemDicts = nil;
    dispatch_sync(s_synchronizationQueue, ^{
        status = SecItemCopyMatching((CFDictionaryRef)query, &cfItemDicts);
    });
    NSArray *itemDicts = CFBridgingRelease(cfItemDicts);
    return itemDicts;
}

- (BOOL)saveData:(NSData *)itemData
             key:(MSIDCacheKey *)key
         context:(id<MSIDRequestContext>)context
           error:(NSError **)error
{
    NSString *service = key.service;
    NSString *account = key.account;

    MSID_TRACE;
    MSID_LOG_VERBOSE(context, @"Set keychain item, key info (account: %@ service: %@, keychainGroup: %@)", _PII_NULLIFY(account), _PII_NULLIFY(service), [self keychainGroupLoggingName]);
    MSID_LOG_VERBOSE_PII(context, @"Set keychain item, key info (account: %@ service: %@, keychainGroup: %@)", account, service, self.keychainGroup);

    if (!service.length)
    {
        [self createError:@"Set keychain item with invalid key (service is nil)."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInternal error:error context:context];
        return NO;
    }

    if (!account.length)
    {
        [self createError:@"Set keychain item with invalid key (account is nil)."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInternal error:error context:context];
        return NO;
    }

    if (!itemData)
    {
        [self createError:@"Failed to serialize item to json data."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInternal error:error context:context];
        return NO;
    }

    NSMutableDictionary *query = [self primaryAttributesForKey:key];
    NSMutableDictionary *update = [self secondaryAttributesForKey:key];
    update[(id)kSecValueData] = itemData;
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)update);
        MSID_LOG_INFO(context, @"Keychain update status: %d", (int)status);

        if (status == errSecItemNotFound)
        {
            [query addEntriesFromDictionary:update];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
            MSID_LOG_INFO(context, @"Keychain add status: %d", (int)status);
        }
    });

    if (status != errSecSuccess)
    {
        MSID_LOG_ERROR(context, @"Failed to write item to keychain (status: %d)", (int)status);
        [self createError:@"Failed to write item to keychain"
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return NO;
    }

    return YES;
}

- (BOOL)removeItemsWithKey:(MSIDCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    MSID_TRACE;
    NSString *account = key.account;
    NSString *service = key.service;

    MSID_LOG_VERBOSE(context, @"Remove keychain items, key info (account: %@ service: %@, keychainGroup: %@)", _PII_NULLIFY(account), _PII_NULLIFY(service), [self keychainGroupLoggingName]);
    MSID_LOG_VERBOSE_PII(context, @"Remove keychain items, key info (account: %@ service: %@, keychainGroup: %@)", account, service, self.keychainGroup);

    if (!key || !(key.service || key.account))
    {
        MSID_LOG_ERROR(context, @"Key is nil or one of the key attributes account or service is nil.");
        [self createError:@"Key is nil or one of the key attributes account or service is nil."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInvalidDeveloperParameter error:error context:context];
        return NO;
    }

    NSMutableDictionary *query = [self primaryAttributesForKey:key];
    [query addEntriesFromDictionary:[self secondaryAttributesForKey:key]];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;

    MSID_LOG_INFO(context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemDelete((CFDictionaryRef)query);
    });
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        MSID_LOG_ERROR(context, @"Failed to remove multiple items from keychain (status: %d)", (int)status);
        [self createError:@"Failed to remove multiple items from keychain"
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return NO;
    }

    return YES;
}

#pragma mark - Account metadata
- (MSIDAccountMetadataCacheItem *)accountMetadataWithKey:(MSIDAccountMetadataCacheKey *)key serializer:(id<MSIDAccountMetadataCacheItemSerializer>)serializer context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    // TODO: Need to implement this
    return nil;
}

- (BOOL)saveAccountMetadata:(MSIDAccountMetadataCacheItem *)item key:(MSIDAccountMetadataCacheKey *)key serializer:(id<MSIDAccountMetadataCacheItemSerializer>)serializer context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    // TODO: Need to implement this
    return NO;
}

#pragma mark - Wipe Info

// Saves information about the app which most-recently removed a token.
- (BOOL)saveWipeInfoWithContext:(__unused id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    [self createUnimplementedError:error context:context];
    return NO;
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
    MSID_LOG_WARN(context, @"Clearing the whole context. This should only be executed in tests");
    
    // Delete all accounts for the keychainGroup
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    MSID_LOG_VERBOSE(context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemDelete((CFDictionaryRef)query);
    });
    MSID_LOG_VERBOSE(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);
        }
        return NO;
    }

    return YES;
}

#pragma mark - Utilities

// Get the basic/default keychain query dictionary for keychain items.
// To support searching, the key properties may be partially or fully empty.

- (NSMutableDictionary *)primaryAttributesForKey:(MSIDCacheKey *)key
{
    MSID_TRACE;
    NSString *account = key.account;
    NSString *service = key.service;
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    if (account.length > 0)
    {
        if (key.isShared)
        {
            // Shared item attribute: <keychainGroup>-<homeAccountId>-<environment>
            query[(id)kSecAttrAccount] = [NSString stringWithFormat:@"%@-%@", self.keychainGroup, account];
        }
        else
        {
            // Secret item attribute: <keychainGroup>-<app_bundle_id>-<homeAccountId>-<environment>
            query[(id)kSecAttrAccount] = [NSString stringWithFormat:@"%@-%@-%@", self.keychainGroup,[[NSBundle mainBundle] bundleIdentifier], account];
        }
    }
    if (service.length > 0)
    {
        query[(id)kSecAttrService] = service;
    }
    
    return query;
}

// Get the basic/default keychain update dictionary for account items.
// These are not _primary_ keys, but if they're present in the key object we
// want to set them when adding/updating.
- (NSMutableDictionary *)secondaryAttributesForKey:(MSIDCacheKey *)key
{
    MSID_TRACE;
    NSMutableDictionary *query = [NSMutableDictionary new];
    
    if (key.generic.length > 0)
    {
        query[(id)kSecAttrGeneric] = key.generic;
    }
    if (key.type != nil)
    {
        query[(id)kSecAttrType] = key.type;
    }
    
    return query;
}

// Allocate a "Not Implemented" NSError object.
- (void)createUnimplementedError:(NSError *_Nullable *_Nullable)error
                         context:(id<MSIDRequestContext>)context
{
    [self createError:@"Not Implemented" domain:MSIDErrorDomain errorCode:MSIDErrorUnsupportedFunctionality error:error context:context];
}

// Allocate an NEError, logging a warning.
- (void) createError:(NSString*)message
              domain:(NSErrorDomain)domain
           errorCode:(NSInteger)code
               error:(NSError *_Nullable *_Nullable)error
             context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WARN(context, @"%@", message);
    if (error)
    {
        *error = MSIDCreateError(domain, code, message, nil, nil, nil, context.correlationId, nil);
    }
}

- (NSString *)keychainGroupLoggingName
{
    if ([self.keychainGroup containsString:s_defaultKeychainGroup])
    {
        return s_defaultKeychainLabel;
    }
    
    return _PII_NULLIFY(self.keychainGroup);
}

// Update the lastModification properties for an account object
- (void)updateLastModifiedForAccount:(MSIDAccountCacheItem *)account
                             context:(nullable id<MSIDRequestContext>)context
{
    [self checkIfRecentlyModifiedItem:context
                                 time:account.lastModificationTime
                                  app:account.lastModificationApp];
    account.lastModificationApp = _appIdentifier;
    account.lastModificationTime = [NSDate date];
}

// Update the lastModification properties for a credential object
- (void)updateLastModifiedForCredential:(MSIDCredentialCacheItem *)credential
                                context:(nullable id<MSIDRequestContext>)context
{
    [self checkIfRecentlyModifiedItem:context
                                 time:credential.lastModificationTime
                                  app:credential.lastModificationApp];
    credential.lastModificationApp = _appIdentifier;
    credential.lastModificationTime = [NSDate date];
}

// If this item was modified a moment ago by another process, report a *potential* collision
- (BOOL)checkIfRecentlyModifiedItem:(nullable id<MSIDRequestContext>)context
                               time:(NSDate *)lastModificationTime
                                app:(NSString *)lastModificationApp
{
    if (lastModificationTime && lastModificationApp)
    {
        // Only check if the previous modification was by another process
        if ([_appIdentifier isEqualToString:lastModificationApp] == NO)
        {
            NSTimeInterval timeDifference = [lastModificationTime timeIntervalSinceNow];
            if (fabs(timeDifference) < 0.1) // less than 1/10th of a second ago
            {
                MSID_LOG_WARN(context, @"Set keychain item for recently-modified item (delta %0.3f) app:%@",
                              timeDifference, lastModificationApp);
                return YES;
            }
        }
    }
    return NO;
}

@end
