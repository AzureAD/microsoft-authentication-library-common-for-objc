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
#import "MSIDTokenCacheKey.h"
#import "MSIDTokenItemSerializer.h"
#import "MSIDAccountItemSerializer.h"
#import "MSIDKeychainUtil.h"
#import "MSIDCacheItem.h"
#import "MSIDError.h"
#import "MSIDRefreshToken.h"

static NSString *const s_wipeLibraryString = @"Microsoft.ADAL.WipeAll.1";
static MSIDKeychainTokenCache *s_defaultCache = nil;
static NSString *s_defaultKeychainGroup = @"com.microsoft.adalcache";

@interface MSIDKeychainTokenCache ()

@property (nonnull) NSString *keychainGroup;

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
    
    if (defaultKeychainGroup == s_defaultKeychainGroup)
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
    
    _keychainGroup = [MSIDKeychainUtil accessGroup:keychainGroup];
    
    if (!_keychainGroup)
    {
        return nil;
    }
    
    MSID_LOG_INFO(nil, @"Using keychainGroup: %@", _PII_NULLIFY(_keychainGroup));
    MSID_LOG_INFO_PII(nil, @"Using keychainGroup: %@", _keychainGroup);
    
    return self;
}

#pragma mark - Tokens

- (BOOL)saveToken:(MSIDTokenCacheItem *)item
              key:(MSIDTokenCacheKey *)key
       serializer:(id<MSIDTokenItemSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    assert(item);
    assert(serializer);
    
    NSData *itemData = [serializer serialize:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize token item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (MSIDTokenCacheItem *)tokenWithKey:(MSIDTokenCacheKey *)key
                          serializer:(id<MSIDTokenItemSerializer>)serializer
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    MSID_LOG_INFO(context, @"itemWithKey:serializer:context:error:");
    NSArray<MSIDTokenCacheItem *> *items = [self tokensWithKey:key serializer:serializer context:context error:error];
    
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

- (NSArray<MSIDTokenCacheItem *> *)tokensWithKey:(MSIDTokenCacheKey *)key
                                      serializer:(id<MSIDTokenItemSerializer>)serializer
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error
{
    NSArray *items = [self itemsWithWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *tokenItems = [[NSMutableArray<MSIDTokenCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDTokenCacheItem *tokenItem = [serializer deserialize:itemData];
        
        if (tokenItem)
        {
            // Delete tombstones generated from previous versions of ADAL.
            if (tokenItem.refreshToken isEqualToString:@"<tombstone>"])
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
    MSID_LOG_INFO_PII(context, @"Items info %@", tokenItems);
    
    return tokenItems;
}

#pragma mark - Accounts

- (BOOL)saveAccount:(MSIDAccountCacheItem *)item
                key:(MSIDTokenCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    assert(item);
    assert(serializer);
    
    NSData *itemData = [serializer serialize:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (MSIDAccountCacheItem *)accountWithKey:(MSIDTokenCacheKey *)key
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

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDTokenCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    NSArray *items = [self itemsWithWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *accountItems = [[NSMutableArray<MSIDAccountCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDAccountCacheItem *accountItem = [serializer deserialize:itemData];
        
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
    MSID_LOG_INFO_PII(context, @"Items info %@", accountItems);
    
    return accountItems;
}

#pragma mark - Removal

- (BOOL)removeItemsWithKey:(MSIDTokenCacheKey *)key
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
    
    NSMutableDictionary *query = [self defaultQuery];
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
    if (key.type)
    {
        [query setObject:key.type forKey:(id)kSecAttrType];
    }
    
    MSID_LOG_INFO(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(NSOSStatusErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);
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
    MSID_LOG_INFO_PII(context, @"Wipe query: %@", [self wipeQuery]);
    OSStatus status = SecItemUpdate((CFDictionaryRef)[self wipeQuery], (CFDictionaryRef)@{ (id)kSecValueData:wipeData});
    MSID_LOG_INFO(context, @"Update wipe info status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        NSMutableDictionary *mutableQuery = [[self wipeQuery] mutableCopy];
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
            *error = MSIDCreateError(NSOSStatusErrorDomain, status, @"Failed to save wipe token data into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to save wipe token data into keychain (status: %d)", (int)status);
        return NO;
    }
    
    return YES;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error;
{
    NSMutableDictionary *query = [[self wipeQuery] mutableCopy];
    [query setObject:@YES forKey:(id)kSecReturnData];
    
    CFTypeRef data = nil;
    MSID_LOG_INFO(context, @"Trying to get wipe info...");
    MSID_LOG_INFO_PII(context, @"Wipe query: %@", [self wipeQuery]);
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &data);
    MSID_LOG_INFO(context, @"Get wipe info status: %d", (int)status);
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(NSOSStatusErrorDomain, status, @"Failed to get a wipe data from keychain.", nil, nil, nil, context.correlationId, nil);
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
    
    NSMutableDictionary *deleteQuery = [self defaultQuery];
    [deleteQuery setObject:service forKey:(id)kSecAttrService];
    [deleteQuery setObject:account forKey:(id)kSecAttrAccount];
    
    MSID_LOG_INFO(context, @"Trying to delete tombstone item...");
    OSStatus status = SecItemDelete((CFDictionaryRef)deleteQuery);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);
}

- (NSDictionary *)wipeQuery
{
    static NSDictionary *wipeQuery;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wipeQuery = @{(id)kSecClass : (id)kSecClassGenericPassword,
                       (id)kSecAttrGeneric : [s_wipeLibraryString dataUsingEncoding:NSUTF8StringEncoding],
                       (id)kSecAttrAccessGroup : self.keychainGroup,
                       (id)kSecAttrAccount : @"TokenWipe"};
    });
    return wipeQuery;
}

- (NSMutableDictionary *)defaultQuery
{
    static NSDictionary *query;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        query = @{(id)kSecClass : (id)kSecClassGenericPassword,
                  (id)kSecAttrAccessGroup : self.keychainGroup};
    });
    return [query mutableCopy];
}

#pragma mark - Helpers

- (NSArray *)itemsWithWithKey:(MSIDTokenCacheKey *)key
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    assert(serializer);
    
    MSID_LOG_INFO(context, @"Get keychain items, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Get keychain items, key info (account: %@ service: %@)", key.account, key.service);
    
    NSMutableDictionary *query = [self defaultQuery];
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
    if (key.type)
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
            *error = MSIDCreateError(NSOSStatusErrorDomain, status, @"Failed to get items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to find keychain item (status: %d)", (int)status);
        return nil;
    }
    
    NSArray *items = CFBridgingRelease(cfItems);
    return items;
}

- (BOOL)saveData:(NSData *)itemData
             key:(MSIDTokenCacheKey *)key
         context:(id<MSIDRequestContext>)context
           error:(NSError **)error
{
    assert(key);
    
    MSID_LOG_INFO(context, @"Set keychain item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set keychain item, key info (account: %@ service: %@)", key.account, key.service);
    MSID_LOG_INFO_PII(context, @"Item info %@", item);
    
    if (!key.service || !key.account || !key.generic)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure service, account and generic fields are not nil.", nil, nil, nil, context.correlationId, nil);
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
    
    NSMutableDictionary *query = [self defaultQuery];
    [query setObject:key.service forKey:(id)kSecAttrService];
    [query setObject:key.account forKey:(id)kSecAttrAccount];
    [query setObject:key.generic forKey:(id)kSecAttrGeneric];
    
    if (key.type)
    {
        [query setObject:key.type forKey:(id)kSecAttrType];
    }
    
    MSID_LOG_INFO(context, @"Trying to update keychain item...");
    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)@{(id)kSecValueData : itemData});
    MSID_LOG_INFO(context, @"Keychain update status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        [query setObject:itemData forKey:(id)kSecValueData];
        [query setObject:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(id)kSecAttrAccessible];
        
        MSID_LOG_INFO(context, @"Trying to add keychain item...");
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_INFO(context, @"Keychain add status: %d", (int)status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(NSOSStatusErrorDomain, status, @"Failed to set item into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to set item into keychain (status: %d)", (int)status);
    }
    
    return status == errSecSuccess;
}


@end

