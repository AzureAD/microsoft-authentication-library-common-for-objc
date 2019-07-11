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
#import "MSIDAccountType.h"
#import "MSIDCredentialCacheItem.h"
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
#import "MSIDJsonObject.h"
#import "MSIDAccountMetadataCacheKey.h"
#import "MSIDExtendedCacheItemSerializing.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDMacCredentialStorageItem.h"
#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDCacheItemJsonSerializer.h"

/**
 This Mac cache stores serialized account and credential objects in the macOS "login" Keychain.
 There are three types of items stored:
 1) Secret shareable artifacts (SSO credentials: Refresh tokens, other global credentials)
 2) Non-secret shareable artifacts (account)
 3) Secret non-shareable artifacts (access tokens, ID tokens)
 4) Non-secret non-shareable artifacts (app metadata, account metadata)
 
 In addition to the basic account & credential properties, the following definitions are used below:
 <account_id>    :  For account - <home_account_id>-<environment>
                    For app metadata - <environment>
                    For account metadata - <home_account_id>
 
 <service_id>    :  For account - <realm>
                    For app metadata - <"appmetadata">-<client_id>
                    For account metadata - <"authority_map">-<client_id>
 
 <generic_id>    :  For account - <username>
                    For app metadata - <family_id>
                    For account metadata - <nil>
 
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
    "<home_account_id1>-<environment1>-<credential_type1>-<client_id1>-<realm1>-<target1>": {
    credential1 payload
    },
    "<home_account_id2>-<environment2>-<credential_type2>-<client_id2>-<realm2>-<target2>": {
    credential2 payload
    }
 }
 
 Type 2 (Non-secret shareable artifacts) Keychain Item Attributes
 ================================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>-<account_id>
 *kSecAttrService  <service_id>
 kSecAttrGeneric   <generic_id>
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
 *kSecAttrAccount  <access_group>-<app_bundle_id>
 *kSecAttrService  “Microsoft Credentials”
 kSecAttrCreator   A hash of <access_group>
 kSecAttrLabel     "Microsoft Credentials"
 kSecValueData     JSON data (UTF8 encoded) – app credentials (multiple credentials saved in one keychain item)
 
 Type 3 JSON Data Example:
 {
    "<home_account_id1>-<environment1>-<credential_type1>-<client_id1>-<realm1>-<target1>": {
    credential1 payload
    },
    "<home_account_id2>-<environment2>-<credential_type2>-<client_id2>-<realm2>-<target2>": {
    credential2 payload
    }
 }
 
 Type 4 (Non-secret non-shareable artifacts) Keychain Item Attributes
 ================================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>-<app_bundle_id>-<account_id>
 *kSecAttrService  <service_id>
 kSecAttrGeneric   <generic_id>
 kSecAttrCreator   A hash of <access_group>
 kSecAttrLabel     "Microsoft Credentials"
 kSecValueData     JSON data (UTF8 encoded) – app metadata / account metadata object
 
 Type 4 JSON Data Example For App Metadata:
 {
 "client_id": "b6c69a37-df96-4db0-9088-2ab96e1d8215",
 "family_id": "",
 "environment": "login.windows.net"
 }
 
 Type 4 JSON Data Example For Account Metadata:
 {
 "client_id": "b6c69a37-df96-4db0-9088-2ab96e1d8215",
 "account_metadata": {
                    "URLMap": {
                                "https:\/\/login.microsoftonline.com\/common": "https:\/\/login.microsoftonline.com\/f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
                              }
                      },
 "home_account_id": "9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca"
 }
 
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
@property MSIDMacCredentialStorageItem *appStorageItem;
@property MSIDMacCredentialStorageItem *sharedStorageItem;
@property MSIDCacheItemJsonSerializer *serializer;
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to set default keychain group, default keychain cache has already been instantiated.");

        @throw @"Attempting to change the keychain group once AuthenticationContexts have been created or the default keychain cache has been retrieved is invalid. The default keychain group should only be set once for the lifetime of an application.";
    }

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Setting default keychain group to %@", MSID_PII_LOG_MASKABLE(defaultKeychainGroup));

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
        self.appStorageItem = [MSIDMacCredentialStorageItem new];
        self.sharedStorageItem = [MSIDMacCredentialStorageItem new];
        self.serializer = [MSIDCacheItemJsonSerializer new];
        
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
                              NSProcessInfo.processInfo.processIdentifier];

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


        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Init MSIDMacKeychainTokenCache with keychainGroup: %@.", [self keychainGroupLoggingName]);
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
         serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    assert(account);
    assert(serializer);
    [self updateLastModifiedForAccount:account context:context];
    NSData *itemData = [serializer serializeCacheItem:account];

    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize account item.");
        }
        return NO;
    }

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(account));

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
                              serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
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
        [self createError:@"The token cache store for this resource contains more than one user."
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
                                          serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    return [self cacheItemsWithKey:key serializer:serializer cacheItemClass:[MSIDAccountCacheItem class] context:context error:error];
}

// Remove one or more accounts from the keychain that match the key.
//
// Errors:
// * MSIDKeychainErrorDomain/OSStatus: Apple status codes from SecItemDelete()
//
- (BOOL)removeAccountsWithKey:(MSIDCacheKey *)key
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

#pragma mark - Credentials

// Write a credential to the macOS keychain cache.
- (BOOL)saveToken:(MSIDCredentialCacheItem *)credential
              key:(MSIDCacheKey *)key
       serializer:(id<MSIDCacheItemSerializing>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    assert(credential);
    assert(serializer);
    
    [self updateLastModifiedForCredential:credential context:context];
    MSIDMacCredentialStorageItem *storageItem = key.isShared ? self.sharedStorageItem : self.appStorageItem;
    
    /*
     First step merge get latest from persistent cache and merge it with in-memory
     Then write latest latest credential to in memory and write back to persistence
     */
    MSIDMacCredentialStorageItem *savedStorageItem = [self storageItemWithKey:key serializer:serializer context:context error:error];
    
    if (savedStorageItem)
    {
        [storageItem mergeStorageItem:savedStorageItem];
    }
    
    [storageItem storeCredential:credential forKey:(MSIDDefaultCredentialCacheKey *)key];
    return [self saveStorageItem:storageItem key:key serializer:serializer context:context error:error];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, context, @"Failed to save stored credential for key %@.", MSID_PII_LOG_MASKABLE(key));
    return NO;
}

- (BOOL)saveStorageItem:(MSIDMacCredentialStorageItem *)storageItem
                    key:(MSIDCacheKey *)key
             serializer:(id<MSIDCacheItemSerializing>)serializer
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    assert(storageItem);
    NSData *itemData = [serializer serializeCredentialStorageItem:storageItem];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize stored credential.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize stored credential.");
        }
        
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(storageItem));
    
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    [query addEntriesFromDictionary:[self accountAttributeForKey:key]];
    query[(id)kSecAttrService] = s_defaultKeychainLabel;
    NSMutableDictionary *update = [NSMutableDictionary dictionary];
    update[(id)kSecValueData] = itemData;
    
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)update);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain update status: %d.", (int)status);
        
        if (status == errSecItemNotFound)
        {
            [query addEntriesFromDictionary:update];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain add status: %d.", (int)status);
        }
    });
    
    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to write item to keychain (status: %d).", (int)status);
        [self createError:@"Failed to write item to keychain."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return NO;
    }
    
    return YES;
}


// Read a single credential from the macOS keychain cache.
// If multiple matches are found, return nil and set an error.
- (MSIDCredentialCacheItem *)tokenWithKey:(MSIDCacheKey *)key
                               serializer:(id<MSIDCacheItemSerializing>)serializer
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSID_TRACE;
    NSArray<MSIDCredentialCacheItem *> *items = [self tokensWithKey:key
                                                         serializer:serializer
                                                            context:context
                                                              error:error];
    
    if (items.count > 1)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"The token cache store for this resource contains more than one token.");
        [self createError:@"The token cache store for this resource contains more than one token."
                   domain:MSIDErrorDomain errorCode:MSIDErrorCacheMultipleUsers error:error context:context];
        return nil;
    }

    return items.firstObject;
}

// Read one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
// If not found, return an empty list without setting an error.
- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(MSIDCacheKey *)key
                                           serializer:(id<MSIDCacheItemSerializing>)serializer
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    NSArray<MSIDCredentialCacheItem *> *tokenList = @[];
    

    /*
     Sync in memory cache with persistent cache at the time of look up.
     */
    MSIDMacCredentialStorageItem *savedItem = [self storageItemWithKey:key serializer:serializer context:context error:error];
    MSIDMacCredentialStorageItem *currentItem = key.isShared ? self.sharedStorageItem : self.appStorageItem;
    
    if (!key.isShared)
    {
        /*
         For refresh tokens, always merge with persistence to get the most recent refresh token as it is shared across apps from same publisher.
         For AT/ID tokens, two apps sharing the same client id can write to the same entry to the keychain. In this case, it is possible that the first app is trying to read a credential which is not currently in its own memory but is written in persistence by the second app sharing the same client id. To find this credential, it is important to merge in memory cache with persistence.
         */
        tokenList = [currentItem storedCredentialsForKey:(MSIDDefaultCredentialCacheKey *)key];
        if ([tokenList count])
        {
            return tokenList;
        }
    }
    
    [currentItem mergeStorageItem:savedItem];
    tokenList = [currentItem storedCredentialsForKey:(MSIDDefaultCredentialCacheKey *)key];
    return tokenList;
    
    return tokenList;
}

// Remove one or more credentials from the keychain that match the key (see credentialItem:matchesKey).
- (BOOL)removeTokensWithKey:(MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    MSID_TRACE;
    
    if (!key || !(key.account || key.service))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Key is nil or one of the key attributes account or service is nil.");
        [self createError:@"Key is nil or one of the key attributes account or service is nil."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInvalidDeveloperParameter error:error context:context];
        return NO;
    }
    
    MSIDMacCredentialStorageItem *storageItem = [self storageItemWithKey:key serializer:self.serializer context:context error:error];
    
    if (storageItem)
    {
        [storageItem removeStoredCredentialForKey:(MSIDDefaultCredentialCacheKey *)key];
        return [self saveStorageItem:storageItem key:key serializer:self.serializer context:context error:error];
    }
    
    return YES;
}

- (MSIDMacCredentialStorageItem *)storageItemWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDCacheItemSerializing>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    MSID_TRACE;
    MSIDMacCredentialStorageItem *storageItem = nil;
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    [query addEntriesFromDictionary:[self accountAttributeForKey:key]];
    query[(id)kSecAttrService] = s_defaultKeychainLabel;
    query[(id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
    query[(id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Trying to find keychain items...");
    
    __block CFDictionaryRef result = nil;
    __block OSStatus status;
    
    dispatch_sync(s_synchronizationQueue, ^{
        status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    });
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Keychain find status: %d.", (int)status);
    
    if (status == errSecSuccess)
    {
        NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
        NSData *storageData = [resultDict objectForKey:(id)kSecValueData];
        storageItem = (MSIDMacCredentialStorageItem *)[serializer deserializeCredentialStorageItem:storageData];
        
        if (!storageItem)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to deserialize stored credential.", nil, nil, nil, context.correlationId, nil);
                MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to deserialize stored credential.");
            }
            
            return nil;
        }
    }
    
    else if (status != errSecItemNotFound)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to read stored credential from keychain (status: %d).", (int)status);
        [self createError:@"Failed to read stored credential from keychain."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
    }
    
    return storageItem;
}

- (NSDictionary *)accountAttributeForKey:(MSIDCacheKey *)key
{
    if (key.isShared)
    {
        // Secret shareable item attribute: <keychainGroup>
        return @{ (id)(kSecAttrAccount): self.keychainGroup};
    }
    else
    {
        // Secret non-shareable item attribute: <keychainGroup>-<app_bundle_id>
        return @{ (id)(kSecAttrAccount): [NSString stringWithFormat:@"%@-%@", self.keychainGroup, [[NSBundle mainBundle] bundleIdentifier]]};
    }
}

#pragma mark - App Metadata

// Save MSIDAppMetadataCacheItem (clientId/environment/familyId) in the macOS keychain cache.
- (BOOL)saveAppMetadata:(__unused MSIDAppMetadataCacheItem *)metadata
                    key:(__unused MSIDCacheKey *)key
             serializer:(__unused id<MSIDExtendedCacheItemSerializing>)serializer
                context:(__unused id<MSIDRequestContext>)context
                  error:(__unused NSError **)error
{
    assert(metadata);
    assert(serializer);

    NSData *itemData = [serializer serializeCacheItem:metadata];

    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize app metadata item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize app metadata item.");
        }
        
        return NO;
    }

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(metadata));

    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

// Read MSIDAppMetadataCacheItem (clientId/environment/familyId) items from the macOS keychain cache.
- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(MSIDCacheKey *)key
                                                        serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error
{
     return [self cacheItemsWithKey:key serializer:serializer cacheItemClass:[MSIDAppMetadataCacheItem class] context:context error:error];
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeMetadataItemsWithKey:(__unused MSIDCacheKey *)key
                           context:(__unused id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (NSArray *)cacheItemsWithKey:(MSIDCacheKey *)key
                    serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                cacheItemClass:(Class)resultClass
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    NSArray *items = [self itemsWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *resultItems = [[NSMutableArray alloc] initWithCapacity:items.count];
    
    for (__unused NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        
        id resultItem = [serializer deserializeCacheItem:itemData ofClass:resultClass];
        
        if (resultItem && [resultItem isKindOfClass:resultClass])
        {
            [resultItems addObject:resultItem];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Failed to deserialize app metadata item.");
        }
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Found %lu items.", (unsigned long)resultItems.count);

    return resultItems;
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeItemsWithMetadataKey:(MSIDCacheKey *)key
                           context:(id<MSIDRequestContext>)context
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

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@, keychainGroup: %@).", MSID_PII_LOG_MASKABLE(account), service, MSID_PII_LOG_MASKABLE(key.generic), key.type, self.keychainGroup);

    NSMutableDictionary *cacheQuery = [self primaryAttributesForKey:key];
    [cacheQuery addEntriesFromDictionary:[self secondaryAttributesForKey:key]];
    
    // Per Apple's docs, kSecReturnData can't be combined with kSecMatchLimitAll:
    // https://developer.apple.com/documentation/security/1398306-secitemcopymatching?language=objc
    // For this reason, we retrieve references to the items, then (below) use a second SecItemCopyMatching()
    // to retrieve the data for each, deserializing each into an account object.
    NSMutableDictionary *query = [cacheQuery mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnRef] = @YES;

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Trying to find keychain items...");
    __block CFTypeRef cfItems = nil;
    __block OSStatus status;
    dispatch_sync(s_synchronizationQueue, ^{
        status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    });
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain find status: %d.", (int)status);

    if (status == errSecItemNotFound)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"item not found.");
        return @[];
    }
    else if (status != errSecSuccess)
    {
        [self createError:@"Failed to read item from keychain."
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
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Set keychain item, key info (account: %@ service: %@, keychainGroup: %@).", MSID_PII_LOG_MASKABLE(account), service, [self keychainGroupLoggingName]);

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
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain update status: %d.", (int)status);

        if (status == errSecItemNotFound)
        {
            [query addEntriesFromDictionary:update];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain add status: %d.", (int)status);
        }
    });

    if (status != errSecSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to write item to keychain (status: %d).", (int)status);
        [self createError:@"Failed to write item to keychain."
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

    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, context, @"Remove keychain items, key info (account: %@ service: %@, keychainGroup: %@).", MSID_PII_LOG_MASKABLE(account), service, [self keychainGroupLoggingName]);

    if (!key || !(key.service || key.account))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Key is nil or one of the key attributes account or service is nil.");
        [self createError:@"Key is nil or one of the key attributes account or service is nil."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInvalidDeveloperParameter error:error context:context];
        return NO;
    }

    NSMutableDictionary *query = [self primaryAttributesForKey:key];
    [query addEntriesFromDictionary:[self secondaryAttributesForKey:key]];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemDelete((CFDictionaryRef)query);
    });
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain delete status: %d.", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to remove multiple items from keychain (status: %d).", (int)status);
        [self createError:@"Failed to remove multiple items from keychain."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return NO;
    }

    return YES;
}

#pragma mark - JSON Object

- (NSArray<MSIDJsonObject *> *)jsonObjectsWithKey:(MSIDCacheKey *)key
                                       serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                          context:(id<MSIDRequestContext>)context
                                            error:(NSError **)error
{
    return [self cacheItemsWithKey:key serializer:serializer cacheItemClass:[MSIDJsonObject class] context:context error:error];
}

- (BOOL)saveJsonObject:(MSIDJsonObject *)jsonObject
            serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                   key:(MSIDCacheKey *)key
               context:(id<MSIDRequestContext>)context
                 error:(NSError **)error
{
    assert(jsonObject);
    assert(serializer);
    
    NSData *itemData = [serializer serializeCacheItem:jsonObject];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize token item.");
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(jsonObject));
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

#pragma mark - Account metadata

- (MSIDAccountMetadataCacheItem *)accountMetadataWithKey:(MSIDAccountMetadataCacheKey *)key
                                              serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                                 context:(id<MSIDRequestContext>)context
                                                   error:(NSError *__autoreleasing *)error
{
    NSArray<MSIDAccountMetadataCacheItem *> *items =  [self cacheItemsWithKey:key
                                                                   serializer:serializer
                                                               cacheItemClass:[MSIDAccountMetadataCacheItem class]
                                                                      context:context error:error];
    
    if (items.count > 1)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Multiple account metadata entries found in the cache.");
        [self createError:@"Multiple account metadata entries found in the cache."
                   domain:MSIDErrorDomain errorCode:MSIDErrorCacheMultipleUsers error:error context:context];
        return nil;
    }
    
    return items.firstObject;
    
}

// TODO: To improve the saving logic here (to not pollute keychain)
- (BOOL)saveAccountMetadata:(MSIDAccountMetadataCacheItem *)item
                        key:(MSIDAccountMetadataCacheKey *)key
                 serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing *)error
{
    assert(item);
    assert(serializer);
    
    NSData *itemData = [serializer serializeCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account metadata item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize account metadata item.");
        }
        
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(item));
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (BOOL)removeAccountMetadataForKey:(MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

#pragma mark - Wipe Info

// Saves information about the app which most-recently removed a token.
- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    [self createUnimplementedError:error context:context];
    return NO;
}

// Read information about the app which most-recently removed a token.
- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
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
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Clearing the whole context. This should only be executed in tests.");
    
    // Delete all accounts for the keychainGroup
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(s_synchronizationQueue, ^{
        status = SecItemDelete((CFDictionaryRef)query);
    });
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Keychain delete status: %d.", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to delete keychain items (status: %d).", (int)status);
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
            /*
             For account - key.account = <home_account_id>-<environment>
             For app metadata, key.account = <environment>
             For account metadata, key.account = <home_account_id>
             */
            query[(id)kSecAttrAccount] = [NSString stringWithFormat:@"%@-%@-%@", self.keychainGroup, [[NSBundle mainBundle] bundleIdentifier], account];
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
    [self createError:@"Not Implemented." domain:MSIDErrorDomain errorCode:MSIDErrorUnsupportedFunctionality error:error context:context];
}

// Allocate an NEError, logging a warning.
- (void) createError:(NSString*)message
              domain:(NSErrorDomain)domain
           errorCode:(NSInteger)code
               error:(NSError *_Nullable *_Nullable)error
             context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"%@", message);
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
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Set keychain item for recently-modified item (delta %0.3f) app:%@.",
                              timeDifference, lastModificationApp);
                return YES;
            }
        }
    }
    return NO;
}

@end
