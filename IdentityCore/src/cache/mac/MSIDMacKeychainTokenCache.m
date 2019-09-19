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
#import "MSIDLogger+Trace.h"
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
#import "MSIDDefaultCredentialCacheQuery.h"
#import "MSIDConstants.h"

/**
 This Mac cache stores serialized cache credentials in the macOS "login" Keychain.
 There are two types of items stored:
 1) Shared Blob (SSO credentials: Refresh tokens, accounts).
 2) Non-Shared Blob (Access Tokens, Id Tokens, App Metadata, Account Metadata).
 
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
 <access_group>  : e.g. "<team_id>.com.microsoft.officecache"
 <username>      : e.g. "joe@contoso.com"
 
 Below, attributes marked with "*" are primary keys for the keychain.
 For password items, the primary attributes are kSecAttrAccount and kSecAttrService.
 Other secondary attributes do not make items unique, only the primary attributes.
 
 Type 1 (Shared Blob) Keychain Item Attributes
 ============================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>
 *kSecAttrService  “Microsoft Credentials”
  kSecValueData    JSON data (UTF8 encoded) – shared cache items (multiple account and refresh token entries in one keychain item).
 
 Type 1 JSON Data Example:
 {
    "RefreshToken": {
                        "<home_account_id>-<environment>-<credential_type>-<client_id>-<realm>-<target>":
                        {
                            "secret": "secret",
                            "environment": "login.windows.net",
                            "credential_type": "RefreshToken",
                            "last_modification_time": "1562842351.202",
                            "last_modification_app": "com.microsoft.MSALMacTestApp;1493",
                            "client_id": "client_id"
                        }
                    },
    "Account":      {
                        "<home_account_id>-<environment>-<realm>":
                        {
                            "client_info": "client_info",
                            "last_modification_app": "com.microsoft.MSALMacTestApp;1493",
                            "local_account_id": "local_account_id",
                            "home_account_id": "home_account_id",
                            "username": "username",
                            "environment": "login.windows.net",
                            "realm": "realm",
                            "authority_type": "MSSTS",
                            "name": "Cloud IDLAB MAM CA User",
                            "last_modification_time": "1562842342.293"
                        }
                    }
 }

 
 Type 2 (Non-Shared Blob) Keychain Item Attributes
 ================================================================
 ATTRIBUTE         VALUE
 ~~~~~~~~~         ~~~~~~~~~~~~~~~~~~~~~~~~
 *kSecClass        kSecClassGenericPassword
 *kSecAttrAccount  <access_group>-<bundle_id>
 *kSecAttrService  "Microsoft Credentials"
 kSecValueData     JSON data (UTF8 encoded) – shared cache items (multiple account and refresh token entries in one keychain item).
 
 Type 2 JSON Data Example:
 {
 "IdToken":         {
                        "<home_account_id>-<environment>-<credential_type>-<client_id>-<realm>-<target>":
                        {
                            "secret": "secret",
                            "environment": "login.windows.net",
                            "credential_type": "IdToken",
                            "last_modification_time": "1562842342.243",
                            "realm": "realm",
                            "client_id": "client_id",
                            "last_modification_app": "com.microsoft.MSALMacTestApp;1493"
                        }
                    },
 
 "AppMetadata":     {
                        "<environment>-"appmetadata"-<client_id>":
                        {
                            "client_id": "client_id",
                            "family_id": "1",
                            "environment": "environment"
                        }
                    },
 
 "AccessToken":      {
                        "<home_account_id>-<environment>-<credential_type>-<client_id>-<realm>-<target>":
                        {
                            "secret": "secret",
                            "credential_type": "AccessToken",
                            "last_modification_time": "1562842342.227",
                            "expires_on": "1562845942",
                            "target": "target",
                            "cached_at": "1562842342",
                            "last_modification_app": "com.microsoft.MSALMacTestApp;1493",
                            "home_account_id": "home_account_id",
                            "client_id": "client_id",
                            "environment": "login.windows.net",
                            "realm": "realm",
                            "extended_expires_on": "1562845942"
                        }
                    },
 
 "AccountMetadata": {
                        "<home_account_id>-"authority_map"-<client_id>":
                        {
                            "client_id": "client_id",
                            "account_metadata": {
                            "URLMap": {
                                         "https:\/\/login.microsoftonline.com\/common": "https:\/\/login.microsoftonline.com\/<realm>"
                                       }
                            },
                            "home_account_id": "home_account_id"
                        }
                    }
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

/**
Access Control Lists
 
Since MSAL has no knowledge of which applications need to access
our keychain cache, the application developer needs to specify
a list of SecTrustedApplicationRef.  By default, if no such
information was specified, MSAL will assume that the token cache
will only be accessible by the current application.  In that case,
the access control list of Type 1 and Type 3 will be the same.

As stated above, there are two types of keychain items:
 1) Shared Blob (SSO credentials: Refresh tokens, accounts)
 2) Non-Shared Blob (Access Tokens, Id Tokens, App Metadata, Account Metadata).
 
Type 1 Shared Blob (SSO credentials: Refresh tokens, accounts)
=============================================================
SecAccess: {
  SecACL[0] : {
    Description: "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationChangeACL
    }
    TrustedApps: {
       <List of SecTrustedApplicationRef supplied by the caller>
    }
  }
  SecACL[1] : {
    Description "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationEncrypt
    }
    TrustedApps: nil // denotes all applications have access
  }
  SecACL[2] : {
    Description "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationDecrypt
      kSecACLAuthorizationDerive
      kSecACLAuthorizationExportClear
      kSecACLAuthorizationExportWrapped
      kSecACLAuthorizationMAC
      kSecACLAuthorizationSign
    }
    TrustedApps: {
      <List of SecTrustedApplicationRef supplied by the caller>
    }
  }
}

Type 2 Non-Shared Blob (Access Tokens, Id Tokens, App Metadata, Account Metadata).
============================================================
SecAccess: {
  SecACL[0] : {
    Description: "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationChangeACL
    }
    TrustedApps: {
       <SecTrustedApplicationRef denoting the current application>
    }
  }
  SecACL[1] : {
    Description "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationEncrypt
    }
    TrustedApps: nil // denotes all applications have access
  }
  SecACL[2] : {
    Description "Microsoft Credentials"
    Operations: {
      kSecACLAuthorizationDecrypt
      kSecACLAuthorizationDerive
      kSecACLAuthorizationExportClear
      kSecACLAuthorizationExportWrapped
      kSecACLAuthorizationMAC
      kSecACLAuthorizationSign
    }
    TrustedApps: {
      <SecTrustedApplicationRef denoting the current application>
    }
  }
}

References(s):
* Apple Keychain Services Access Control Lists:
 https://developer.apple.com/documentation/security/ksecattraccess?language=objc
*/

static NSString *s_defaultKeychainGroup = @"com.microsoft.identity.universalstorage";
static NSString *s_defaultKeychainLabel = @"Microsoft Credentials";
static MSIDMacKeychainTokenCache *s_defaultCache = nil;
static dispatch_queue_t s_synchronizationQueue;
static NSString *kLoginKeychainEmptyKey = @"LoginKeychainEmpty";

@interface MSIDMacKeychainTokenCache ()

@property (readwrite, nonnull) NSString *keychainGroup;
@property (readwrite, nonnull) NSDictionary *defaultCacheQuery;
@property (readwrite, nonnull) NSString *appIdentifier;
@property MSIDMacCredentialStorageItem *appStorageItem;
@property MSIDMacCredentialStorageItem *sharedStorageItem;
@property MSIDCacheItemJsonSerializer *serializer;
@property (readwrite, nonnull) id accessForSharedBlob;
@property (readwrite, nonnull) id accessForNonSharedBlob;

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
    return [self initWithGroup:s_defaultKeychainGroup trustedApplications:nil error:nil];
}

// Initialize with a keychain group
//
// @param keychainGroup Optional. If the application needs to share the cached tokens
// with other applications from the same vendor, the app will need to specify the
// shared group here. If set to 'nil' the main bundle's identifier will be used instead.
//
- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup
                   trustedApplications:(nullable NSArray *)trustedApplications
                                 error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_TRACE;

    self = [super init];
    if (self)
    {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
        if (@available(macOS 10.15, *)) {
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:kLoginKeychainEmptyKey])
            {
                if (error)
                {
                    *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Not creating login keychain for performance optimization on macOS 10.15, because no items where previously found in it", nil, nil, nil, nil, nil);
                }
                
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Not creating login keychain for performance optimization on macOS 10.15, because no items where previously found in it");
                return nil;
            }
        }
#endif
        
        self.appStorageItem = [MSIDMacCredentialStorageItem new];
        self.sharedStorageItem = [MSIDMacCredentialStorageItem new];
        self.serializer = [MSIDCacheItemJsonSerializer new];
        
        if (!keychainGroup)
        {
            keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
        }

        MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
        
        if (!keychainUtil.teamId)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to retrieve teamId from keychain.", nil, nil, nil, nil, nil);
            }
            
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to retrieve teamId from keychain.");
            return nil;
        }
        
        // Add team prefix to keychain group if it is missed.
        if (![keychainGroup hasPrefix:keychainUtil.teamId])
        {
            keychainGroup = [keychainUtil accessGroup:keychainGroup];
        }

        self.keychainGroup = keychainGroup;

        if (!self.keychainGroup)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to set keychain access group.", nil, nil, nil, nil, nil);
            }
            
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to set keychain access group.");
            return nil;
        }
        
        NSArray *appList = [self createTrustedAppListWithCurrentApp:error];
        
        if (![appList count])
        {
            return nil;
        }
        
        if (![trustedApplications count])
        {
            trustedApplications = appList;
        }
        
        self.accessForSharedBlob = [self accessCreateWithChangeACL:trustedApplications error:error];
        if (!self.accessForSharedBlob)
        {
            return nil;
        }
        
        self.accessForNonSharedBlob = [self accessCreateWithChangeACL:appList error:error];
        if (!self.accessForNonSharedBlob)
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
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
    [storageItem storeItem:account forKey:key];
    return [self saveStorageItem:storageItem isShared:key.isShared serializer:serializer context:context error:error];
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
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
    NSArray *itemList = [storageItem storedItemsForKey:key];
    return itemList;
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
    return [self removeItemsWithKey:key context:context inBucket:MSID_ACCOUNT_CACHE_TYPE error:error];
}

- (NSArray<MSIDJsonObject *> *)jsonObjectsWithKey:(__unused MSIDCacheKey *)key serializer:(__unused id<MSIDExtendedCacheItemSerializing>)serializer context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    [self createUnimplementedError:error context:context];
    return nil;
}


- (BOOL)saveJsonObject:(__unused MSIDJsonObject *)jsonObject serializer:(__unused id<MSIDExtendedCacheItemSerializing>)serializer key:(__unused MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    [self createUnimplementedError:error context:context];
    return NO;
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
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
    [storageItem storeItem:credential forKey:key];
    return [self saveStorageItem:storageItem isShared:key.isShared serializer:serializer context:context error:error];
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
    NSArray *itemList = @[];
    
    /*
     For refresh tokens, always merge with persistence to get the most recent refresh token as it is shared across apps from same publisher.
     For AT/ID tokens, two apps sharing the same client id can write to the same entry to the keychain. In this case, it is possible that the first app is trying to read a credential which is not currently in its own memory but is written in persistence by the second app sharing the same client id. To find this credential, it is important to merge in memory cache with persistence.
     */
    
    MSIDDefaultCredentialCacheQuery *query = (MSIDDefaultCredentialCacheQuery *)key;
    if ([query isKindOfClass:[MSIDDefaultCredentialCacheQuery class]] && query.matchAnyCredentialType)
    {
        itemList = [self getAllItemsWithKey:key context:context serializer:serializer error:error];
    }
    
    else
    {
        MSIDMacCredentialStorageItem *storageItem = key.isShared ? self.sharedStorageItem : self.appStorageItem;
        
        if (!key.isShared)
        {
            itemList = [storageItem storedItemsForKey:key];
            if ([itemList count])
            {
                return itemList;
            }
        }
        
        storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
        itemList = [storageItem storedItemsForKey:key];
    }
    
    NSMutableArray *tokenItems = [self filterTokenItemsFromKeychainItems:itemList
                                                              serializer:serializer
                                                                 context:context];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Found %lu items.", (unsigned long)tokenItems.count);
    
    return tokenItems;
}

- (NSMutableArray<MSIDCredentialCacheItem *> *)filterTokenItemsFromKeychainItems:(NSArray *)items
                                                                      serializer:(id<MSIDCacheItemSerializing>)serializer
                                                                         context:(id<MSIDRequestContext>)context
{
    NSMutableArray *tokenItems = [[NSMutableArray<MSIDCredentialCacheItem *> alloc] initWithCapacity:items.count];
    
    for (id item in items)
    {
        if ([item isKindOfClass:[MSIDCredentialCacheItem class]])
        {
            [tokenItems addObject:(MSIDCredentialCacheItem *)item];
        }
    }
    
    return tokenItems;
}

/*
 Gets all items
 */
- (nullable NSArray<MSIDCredentialCacheItem *> *)getAllItemsWithKey:(MSIDCacheKey *)key
                                                            context:(nullable id<MSIDRequestContext>)context
                                                         serializer:(id<MSIDCacheItemSerializing>)serializer
                                                              error:(NSError * _Nullable * _Nullable)error
{
    NSMutableArray *allTokens = [NSMutableArray new];
    
    MSIDMacCredentialStorageItem *appItem = [self syncStorageItem:NO serializer:serializer context:context error:error];
    [allTokens addObjectsFromArray:[appItem storedItemsForKey:key]];
    
    MSIDMacCredentialStorageItem *sharedItem = [self syncStorageItem:YES serializer:serializer context:context error:error];
    [allTokens addObjectsFromArray:[sharedItem storedItemsForKey:key]];
    
    return allTokens;
}

/*
 Removes all items
 */
- (BOOL)removeAllMatchingTokens:(MSIDCacheKey *)key
                        context:(id<MSIDRequestContext>)context
                     serializer:(id<MSIDCacheItemSerializing>)serializer
                       isShared:(BOOL)isShared
                          error:(NSError * _Nullable * _Nullable)error
{
    BOOL result = YES;
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:isShared serializer:self.serializer context:context error:error];
    [storageItem removeStoredItemForKey:key];
    
    if ([storageItem count])
    {
        result &= [self saveStorageItem:storageItem isShared:isShared serializer:self.serializer context:context error:error];
    }
    else
    {
        result &= [self removeStorageItem:isShared context:context error:error];
    }
    
    return result;
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
    
    MSIDDefaultCredentialCacheQuery *query = (MSIDDefaultCredentialCacheQuery *)key;
    if ([query isKindOfClass:[MSIDDefaultCredentialCacheQuery class]] && query.matchAnyCredentialType)
    {
        /*
         For this particular case, we need to remove tokens from both shared and non-shared blob
         */
        BOOL result = YES;
        result &= [self removeAllMatchingTokens:key context:context serializer:self.serializer isShared:YES error:error];
        result &= [self removeAllMatchingTokens:key context:context serializer:self.serializer isShared:NO error:error];
        return result;
    }
    
    return [self removeAllMatchingTokens:key context:context serializer:self.serializer isShared:key.isShared error:error];
}

- (MSIDMacCredentialStorageItem *)syncStorageItem:(BOOL)isShared
                                       serializer:(id<MSIDCacheItemSerializing>)serializer
                                          context:(id<MSIDRequestContext>)context
                                            error:(NSError **)error
{
    /*
     Sync in memory cache with persistent cache at the time of look up.
     */
    MSIDMacCredentialStorageItem *savedStorageItem = [self queryStorageItem:isShared serializer:serializer context:context error:error];
    MSIDMacCredentialStorageItem *storageItem = isShared ? self.sharedStorageItem : self.appStorageItem;
    
    if (savedStorageItem)
    {
        [storageItem mergeStorageItem:savedStorageItem];
    }
    
    return storageItem;
}

- (BOOL)saveStorageItem:(MSIDMacCredentialStorageItem *)storageItem
               isShared:(BOOL)isShared
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
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize stored item.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to serialize stored item.");
        }
        
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item, item info %@.", MSID_PII_LOG_MASKABLE(storageItem));
    
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    [query addEntriesFromDictionary:[self primaryAttributesForItem:isShared context:context error:error]];
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

- (BOOL)removeStorageItem:(BOOL)isShared
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    [query addEntriesFromDictionary:[self primaryAttributesForItem:isShared context:context error:error]];
    query[(id)kSecAttrService] = s_defaultKeychainLabel;
    
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

- (MSIDMacCredentialStorageItem *)queryStorageItem:(BOOL)isShared
                                        serializer:(id<MSIDCacheItemSerializing>)serializer
                                           context:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSID_TRACE;
    
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
    if (@available(macOS 10.15, *)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kLoginKeychainEmptyKey])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"Skipping login keychain read because it has been previously marked as empty on 10.15");
            return nil;
        }
    }
#endif
    
    MSIDMacCredentialStorageItem *storageItem = nil;
    NSMutableDictionary *query = [self.defaultCacheQuery mutableCopy];
    [query addEntriesFromDictionary:[self primaryAttributesForItem:isShared context:context error:error]];
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
    
    BOOL storageItemIsEmpty = NO;
    
    if (status == errSecSuccess)
    {
        NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
        NSData *storageData = [resultDict objectForKey:(id)kSecValueData];
        storageItem = (MSIDMacCredentialStorageItem *)[serializer deserializeCredentialStorageItem:storageData];
        
        if (!storageItem)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to deserialize stored item.", nil, nil, nil, context.correlationId, nil);
                MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to deserialize stored item.");
            }
            
            return nil;
        }
        
        storageItemIsEmpty = !storageItem.count;
    }
    else if (status == errSecItemNotFound)
    {
        storageItemIsEmpty = YES;
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to read stored item from keychain (status: %d).", (int)status);
        [self createError:@"Failed to read stored item from keychain."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
    }
    
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
    if (@available(macOS 10.15, *)) {
        
        // Performance optimization on 10.15. If we've read shared item once and we didn't find it, or it was empty, save a flag into user defaults such as we stop looking into the login keychain altogether
        if (isShared && storageItemIsEmpty)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"Saving a flag to stop looking into login keychain, as it doesn't contain any items");
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kLoginKeychainEmptyKey];
        }
    }
#endif
    
    return storageItem;
}

- (BOOL)removeItemsWithKey:(MSIDCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                  inBucket:(__unused NSString *)bucket
                     error:(NSError **)error
{
    MSID_TRACE;
    
    if (!key || !(key.account || key.service))
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Key is nil or one of the key attributes account or service is nil.");
        [self createError:@"Key is nil or one of the key attributes account or service is nil."
                   domain:MSIDErrorDomain errorCode:MSIDErrorInvalidDeveloperParameter error:error context:context];
        return NO;
    }
    
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:self.serializer context:context error:error];
    [storageItem removeStoredItemForKey:key];
    
    if ([storageItem count])
    {
        return [self saveStorageItem:storageItem isShared:key.isShared serializer:self.serializer context:context error:error];
    }

    return [self removeStorageItem:key.isShared context:context error:error];
}

- (NSDictionary *)primaryAttributesForItem:(BOOL)isShared context:(id<MSIDRequestContext>)context error:(NSError **)error
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    
    if (isShared)
    {
        // Shareable item attributes: <keychainGroup>
        [attributes setObject:self.keychainGroup forKey:(id)kSecAttrAccount];
        [attributes setObject:self.accessForSharedBlob forKey:(id)kSecAttrAccess];
    }
    else
    {
        // Non-Shareable item attributes: <keychainGroup>-<app_bundle_id>
        [attributes setObject:[NSString stringWithFormat:@"%@-%@", self.keychainGroup, [[NSBundle mainBundle] bundleIdentifier]] forKey:(id)kSecAttrAccount];
        [attributes setObject:self.accessForNonSharedBlob forKey:(id)kSecAttrAccess];
    }
    
    return attributes;
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
    
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
    [storageItem storeItem:metadata forKey:key];
    return [self saveStorageItem:storageItem isShared:key.isShared serializer:serializer context:context error:error];
}

// Read MSIDAppMetadataCacheItem (clientId/environment/familyId) items from the macOS keychain cache.
- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(MSIDCacheKey *)key
                                                        serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error
{
    MSIDMacCredentialStorageItem *storageItem = key.isShared ? self.sharedStorageItem : self.appStorageItem;
    NSArray *itemList = [storageItem storedItemsForKey:key];
    
    /*
     Merge in memory with persistence only if not found in memory to cover the case when 2 apps sharing the same clientId can modify the same entry in the keychain.
     */
    if (![itemList count])
    {
        storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
        itemList = [storageItem storedItemsForKey:key];
    }
    
    return itemList;
}

// Remove items with the given Metadata key from the macOS keychain cache.
- (BOOL)removeMetadataItemsWithKey:(__unused MSIDCacheKey *)key
                           context:(__unused id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context inBucket:MSID_APPLICATION_METADATA_CACHE_TYPE error:error];
}

#pragma mark - Account metadata

// TODO: To improve the saving logic here (to not pollute keychain)
- (BOOL)saveAccountMetadata:(MSIDAccountMetadataCacheItem *)item
                        key:(MSIDAccountMetadataCacheKey *)key
                 serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing *)error
{
    MSIDMacCredentialStorageItem *storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
    [storageItem storeItem:item forKey:key];
    return [self saveStorageItem:storageItem isShared:key.isShared serializer:serializer context:context error:error];
}

- (MSIDAccountMetadataCacheItem *)accountMetadataWithKey:(MSIDAccountMetadataCacheKey *)key
                                              serializer:(id<MSIDExtendedCacheItemSerializing>)serializer
                                                 context:(id<MSIDRequestContext>)context
                                                   error:(NSError *__autoreleasing *)error
{
    MSIDMacCredentialStorageItem *storageItem = key.isShared ? self.sharedStorageItem : self.appStorageItem;
    NSArray *itemList = [storageItem storedItemsForKey:key];
    
    /*
     Merge in memory with persistence only if not found in memory to cover the case when 2 apps sharing the same clientId can modify the same entry in the keychain.
     */
    if (![itemList count])
    {
        storageItem = [self syncStorageItem:key.isShared serializer:serializer context:context error:error];
        itemList = [storageItem storedItemsForKey:key];
    }
    
    if (itemList.count > 1)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Multiple account metadata entries found in the cache.");
        [self createError:@"Multiple account metadata entries found in the cache."
                   domain:MSIDErrorDomain errorCode:MSIDErrorCacheMultipleUsers error:error context:context];
        return nil;
    }
    
    return itemList.firstObject;
    
}

- (BOOL)removeAccountMetadataForKey:(MSIDCacheKey *)key context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    return [self removeItemsWithKey:key context:context inBucket:MSID_ACCOUNT_METADATA_CACHE_TYPE error:error];
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

#pragma mark - Access Control Lists

- (NSArray *)createTrustedAppListWithCurrentApp:(NSError **)error
{
    SecTrustedApplicationRef trustedApplication = nil;
    OSStatus status = SecTrustedApplicationCreateFromPath(nil, &trustedApplication);
    if (status != errSecSuccess)
    {
        [self createError:@"Failed to create SecTrustedApplicationRef for current application. Please make sure the app you're running is properly signed and keychain access group is configured."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:nil];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create SecTrustedApplicationRef for current application. Please make sure the app you're running is properly signed and keychain access group is configured (status: %d).", (int)status);
        return nil;
    }
    
    NSArray *trustedApplications = @[(__bridge_transfer id)trustedApplication];
    return trustedApplications;
}

- (id)accessCreateWithChangeACL:(NSArray<id> *)trustedApplications error:(NSError **)error
{
    SecAccessRef access;
    OSStatus status = SecAccessCreate((__bridge CFStringRef)s_defaultKeychainLabel, (__bridge CFArrayRef)trustedApplications, &access);
    
    if (status != errSecSuccess)
    {
        [self createError:@"Failed to create SecAccessRef for current application. Please make sure the app you're running is properly signed and keychain access group is configured."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:nil];
         MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create SecAccessRef for current application. Please make sure the app you're running is properly signed and keychain access group is configured (status: %d).", (int)status);
        return nil;
    }
    
    if (![self accessSetACLTrustedApplications:access
                           aclAuthorizationTag:kSecACLAuthorizationDecrypt
                           trustedApplications:trustedApplications
                                       context:nil
                                         error:error])
    {
        CFReleaseNull(access);
        return nil;
    }
    
    return CFBridgingRelease(access);
}

- (BOOL)accessSetACLTrustedApplications:(SecAccessRef)access
                     aclAuthorizationTag:(CFStringRef)aclAuthorizationTag
                     trustedApplications:(NSArray<id> *)trustedApplications
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    NSArray *acls = (__bridge_transfer NSArray*)SecAccessCopyMatchingACLList(access, aclAuthorizationTag);
    OSStatus status;
    CFStringRef description = nil;
    CFArrayRef oldtrustedAppList = nil;
    SecKeychainPromptSelector selector;
    
    // TODO: handle case where tag is not found?
    for (id acl in acls)
    {
        status = SecACLCopyContents((__bridge SecACLRef)acl, &oldtrustedAppList, &description, &selector);
        
        if (status != errSecSuccess)
        {
            [self createError:@"Failed to get contents from ACL. Please make sure the app you're running is properly signed and keychain access group is configured." domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
             MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to get contents from ACL. Please make sure the app you're running is properly signed and keychain access group is configured(status: %d).", (int)status);
            return NO;
        }
        
        status = SecACLSetContents((__bridge SecACLRef)acl, (__bridge CFArrayRef)trustedApplications, description, selector);
        
        if (status != errSecSuccess)
        {
            [self createError:@"Failed to set contents for ACL. Please make sure the app you're running is properly signed and keychain access group is configured." domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to set contents for ACL. Please make sure the app you're running is properly signed and keychain access group is configured (status: %d).", (int)status);
            CFReleaseNull(oldtrustedAppList);
            CFReleaseNull(description);
            return NO;
        }
    }
    
    CFReleaseNull(oldtrustedAppList);
    CFReleaseNull(description);
    return YES;
}

#pragma mark - Utilities

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
