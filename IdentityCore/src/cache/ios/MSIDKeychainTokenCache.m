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

#import "MSIDKeychainTokenCache.h"
#import "MSIDCacheKey.h"
#import "MSIDCredentialItemSerializer.h"
#import "MSIDAccountItemSerializer.h"
#import "MSIDKeychainUtil.h"
#import "MSIDError.h"
#import "MSIDRefreshToken.h"

static NSString *const s_wipeLibraryString = @"Microsoft.ADAL.WipeAll.1";
static MSIDKeychainTokenCache *s_defaultCache = nil;
static NSString *s_defaultKeychainGroup = @"com.microsoft.adalcache";

@interface MSIDKeychainTokenCache ()

@property (readwrite, nonnull) NSString *keychainGroup;
@property (readwrite, nonnull) NSDictionary *defaultKeychainQuery;
@property (readwrite, nonnull) NSDictionary *defaultWipeQuery;

@end

@implementation MSIDKeychainTokenCache

#pragma mark - Public

+ (NSString *)defaultKeychainGroup
{
    return s_defaultKeychainGroup;
}

+ (void)setDefaultKeychainGroup:(NSString *)defaultKeychainGroup
{
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

+ (MSIDKeychainTokenCache *)defaultKeychainCache
{
    static dispatch_once_t s_once;
    
    dispatch_once(&s_once, ^{
        s_defaultCache = [[MSIDKeychainTokenCache alloc] init];
    });
    
    return s_defaultCache;
}

- (nonnull instancetype)init
{
    return [self initWithGroup:s_defaultKeychainGroup];
}

- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!keychainGroup)
    {
        keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    if (!MSIDKeychainUtil.teamId) return nil;
    
    // Add team prefix to keychain group if it is missed.
    if (![keychainGroup hasPrefix:MSIDKeychainUtil.teamId])
    {
        keychainGroup = [MSIDKeychainUtil accessGroup:keychainGroup];
    }
    
    _keychainGroup = keychainGroup;
    
    if (!_keychainGroup)
    {
        return nil;
    }
    
    self.defaultKeychainQuery = [@{(id)kSecClass : (id)kSecClassGenericPassword,
                                   (id)kSecAttrAccessGroup : self.keychainGroup} mutableCopy];
    
    self.defaultWipeQuery = @{(id)kSecClass : (id)kSecClassGenericPassword,
                              (id)kSecAttrGeneric : [s_wipeLibraryString dataUsingEncoding:NSUTF8StringEncoding],
                              (id)kSecAttrAccessGroup : self.keychainGroup,
                              (id)kSecAttrAccount : @"TokenWipe"};
    
    MSID_LOG_INFO(nil, @"Using keychainGroup: %@", _PII_NULLIFY(_keychainGroup));
    MSID_LOG_INFO_PII(nil, @"Using keychainGroup: %@", _keychainGroup);
    
    return self;
}

#pragma mark - Tokens

- (BOOL)saveToken:(MSIDCredentialCacheItem *)item
              key:(MSIDCacheKey *)key
       serializer:(id<MSIDCredentialItemSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    assert(item);
    assert(serializer);

    if (!key.generic)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure generic field is not nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }
    
    NSData *itemData = [serializer serializeCredentialCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize token item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    MSID_LOG_INFO_PII(context, @"Save keychain item, item info %@", item);
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (MSIDCredentialCacheItem *)tokenWithKey:(MSIDCacheKey *)key
                               serializer:(id<MSIDCredentialItemSerializer>)serializer
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSID_LOG_INFO(context, @"itemWithKey:serializer:context:error:");
    NSArray<MSIDCredentialCacheItem *> *items = [self tokensWithKey:key serializer:serializer context:context error:error];
    
    if (items.count > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"The token cache store for this resource contains more than one user.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return items.firstObject;
}

- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(MSIDCacheKey *)key
                                           serializer:(id<MSIDCredentialItemSerializer>)serializer
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    NSArray *items = [self itemsWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *tokenItems = [[NSMutableArray<MSIDCredentialCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDCredentialCacheItem *tokenItem = [serializer deserializeCredentialCacheItem:itemData];
        
        if (tokenItem)
        {
            // Delete tombstones generated from previous versions of ADAL.
            if ([tokenItem isTombstone])
            {
                [self deleteTombstoneWithService:attrs[(id)kSecAttrService]
                                         account:attrs[(id)kSecAttrAccount]
                                         context:context];
            }
            else
            {
                [tokenItems addObject:tokenItem];
            }
        }
        else
        {
            MSID_LOG_ERROR(context, @"Failed to deserialize token item.");
        }
    }
    
    MSID_LOG_INFO(context, @"Found %lu items.", (unsigned long)tokenItems.count);
    MSID_LOG_VERBOSE_PII(context, @"Items info %@", tokenItems);
    
    return tokenItems;
}

#pragma mark - Accounts

- (BOOL)saveAccount:(MSIDAccountCacheItem *)item
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    assert(item);
    assert(serializer);
    
    NSData *itemData = [serializer serializeAccountCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    MSID_LOG_INFO_PII(context, @"Save keychain item, item info %@", item);
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSID_LOG_INFO(context, @"itemWithKey:serializer:context:error:");
    NSArray<MSIDAccountCacheItem *> *items = [self accountsWithKey:key serializer:serializer context:context error:error];
    
    if (items.count > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"The token cache store for this resource contains more than one user.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return items.firstObject;
}

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    NSArray *items = [self itemsWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *accountItems = [[NSMutableArray<MSIDAccountCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDAccountCacheItem *accountItem = [serializer deserializeAccountCacheItem:itemData];
        
        if (accountItem)
        {
            [accountItems addObject:accountItem];
        }
        else
        {
            MSID_LOG_ERROR(context, @"Failed to deserialize account item.");
        }
    }
    
    MSID_LOG_INFO(context, @"Found %lu items.", (unsigned long)accountItems.count);
    MSID_LOG_VERBOSE_PII(context, @"Items info %@", accountItems);
    
    return accountItems;
}

#pragma mark - Removal

- (BOOL)removeItemsWithKey:(MSIDCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    MSID_LOG_INFO(context, @"Remove keychain items, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Remove keychain items, key info (account: %@ service: %@)", key.account, key.service);
    
    if (!key)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Key is nil.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    if (key.service)
    {
        [query setObject:key.service forKey:(id)kSecAttrService];
    }
    if (key.account)
    {
        [query setObject:key.account forKey:(id)kSecAttrAccount];
    }
    if (key.generic)
    {
        [query setObject:key.generic forKey:(id)kSecAttrGeneric];
    }
    if (key.type != nil)
    {
        [query setObject:key.type forKey:(id)kSecAttrType];
    }
    
    MSID_LOG_INFO(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);
    
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);
        
        return NO;
    }
        
    return YES;
}

#pragma mark - Wipe

- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSDictionary *wipeInfo = @{ @"bundleId" : [[NSBundle mainBundle] bundleIdentifier],
                                @"wipeTime" : [NSDate date]
                                };

    MSID_LOG_INFO_PII(context, @"Full wipe info: %@", wipeInfo);
    
    NSData *wipeData = [NSKeyedArchiver archivedDataWithRootObject:wipeInfo];
    MSID_LOG_INFO(context, @"Trying to update wipe info...");
    MSID_LOG_INFO_PII(context, @"Wipe query: %@", self.defaultWipeQuery);
    OSStatus status = SecItemUpdate((CFDictionaryRef)self.defaultWipeQuery, (CFDictionaryRef)@{ (id)kSecValueData:wipeData});
    MSID_LOG_INFO(context, @"Update wipe info status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        NSMutableDictionary *mutableQuery = [self.defaultWipeQuery mutableCopy];
        [mutableQuery addEntriesFromDictionary: @{(id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                  (id)kSecValueData : wipeData}];
        MSID_LOG_INFO(context, @"Trying to add wipe info...");
        status = SecItemAdd((CFDictionaryRef)mutableQuery, NULL);
        MSID_LOG_INFO(context, @"Add wipe info status: %d", (int)status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to save wipe token data into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to save wipe token data into keychain (status: %d)", (int)status);
        return NO;
    }
    
    return YES;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error;
{
    NSMutableDictionary *query = [self.defaultWipeQuery mutableCopy];
    [query setObject:@YES forKey:(id)kSecReturnData];
    //For compatibility, remove kSecAttrService to be able to read wipeInfo written by old ADAL
    [query removeObjectForKey:(id)kSecAttrService];
    
    CFTypeRef data = nil;
    MSID_LOG_INFO(context, @"Trying to get wipe info...");
    MSID_LOG_INFO_PII(context, @"Wipe query: %@", self.defaultWipeQuery);
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &data);
    MSID_LOG_INFO(context, @"Get wipe info status: %d", (int)status);
    
    if (status != errSecSuccess)
    {
        if (error && status != errSecItemNotFound)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to get a wipe data from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to get a wipe data from keychain (status: %d)", (int)status);
        return nil;
    }
    
    NSDictionary *wipeData = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)(data)];
    CFRelease(data);
    
    return wipeData;
}

#pragma mark - Private

- (void)deleteTombstoneWithService:(NSString *)service account:(NSString *)account context:(id<MSIDRequestContext>)context
{
    if (!service || !account)
    {
        return;
    }
    
    NSMutableDictionary *deleteQuery = [self.defaultKeychainQuery mutableCopy];
    [deleteQuery setObject:service forKey:(id)kSecAttrService];
    [deleteQuery setObject:account forKey:(id)kSecAttrAccount];
    
    MSID_LOG_INFO(context, @"Trying to delete tombstone item...");
    OSStatus status = SecItemDelete((CFDictionaryRef)deleteQuery);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);
}

#pragma mark - Helpers

- (NSArray *)itemsWithKey:(MSIDCacheKey *)key
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{    
    MSID_LOG_INFO(context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@)", _PII_NULLIFY(key.account), key.service, _PII_NULLIFY(key.generic), key.type);
    MSID_LOG_INFO_PII(context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@)", key.account, key.service, key.generic, key.type);
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    if (key.service)
    {
        [query setObject:key.service forKey:(id)kSecAttrService];
    }
    if (key.account)
    {
        [query setObject:key.account forKey:(id)kSecAttrAccount];
    }
    if (key.generic)
    {
        [query setObject:key.generic forKey:(id)kSecAttrGeneric];
    }
    if (key.type != nil)
    {
        [query setObject:key.type forKey:(id)kSecAttrType];
    }
    
    [query setObject:@YES forKey:(id)kSecReturnData];
    [query setObject:@YES forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    
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
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to get items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to find keychain item (status: %d)", (int)status);
        return nil;
    }
    
    NSArray *items = CFBridgingRelease(cfItems);
    return items;
}

- (BOOL)saveData:(NSData *)itemData
             key:(MSIDCacheKey *)key
         context:(id<MSIDRequestContext>)context
           error:(NSError **)error
{
    assert(key);
    
    MSID_LOG_INFO(context, @"Set keychain item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set keychain item, key info (account: %@ service: %@)", key.account, key.service);
    
    if (!key.service)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure service field is not nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize token item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    [query setObject:key.service forKey:(id)kSecAttrService];
    [query setObject:(key.account ? key.account : @"") forKey:(id)kSecAttrAccount];
    
    if (key.type != nil)
    {
        [query setObject:key.type forKey:(id)kSecAttrType];
    }
    
    MSID_LOG_INFO(context, @"Trying to update keychain item...");

    NSMutableDictionary *updateDictionary = [@{(id)kSecValueData : itemData} mutableCopy];

    if (key.generic)
    {
        updateDictionary[(id)kSecAttrGeneric] = key.generic;
    }

    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)updateDictionary);
    MSID_LOG_INFO(context, @"Keychain update status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        [query setObject:itemData forKey:(id)kSecValueData];

        if (key.generic)
        {
            [query setObject:key.generic forKey:(id)kSecAttrGeneric];
        }

        [query setObject:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(id)kSecAttrAccessible];
        
        MSID_LOG_INFO(context, @"Trying to add keychain item...");
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_INFO(context, @"Keychain add status: %d", (int)status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to set item into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to set item into keychain (status: %d)", (int)status);
    }
    
    return status == errSecSuccess;
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_LOG_WARN(context, @"Clearing the whole context. This should only be executed in tests");

    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    MSID_LOG_INFO(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);

        return NO;
    }

    return YES;
}

@end

