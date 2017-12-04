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
#import "MSIDTokenSerializer.h"
#import "MSIDKeychainUtil.h"
#import "MSIDToken.h"

static NSString *const s_libraryString = @"MSOpenTech.ADAL.1";
static NSString *const s_wipeLibraryString = @"Microsoft.ADAL.WipeAll.1";
static MSIDKeychainTokenCache *_defaultCache = nil;

@implementation MSIDKeychainTokenCache

#pragma mark - Public

+ (NSString *)adalAccessGroup
{
    return @"com.microsoft.adalcache";
}

+ (NSString *)appDefaultAccessGroup
{
    return MSIDKeychainUtil.appDefaultAccessGroup;
}

+ (MSIDKeychainTokenCache *)defaultKeychainCache
{
    if (!_defaultCache)
    {
        _defaultCache = [[MSIDKeychainTokenCache alloc] initWithGroup:MSIDKeychainTokenCache.adalAccessGroup];
    }
    
    return _defaultCache;
}

+ (void)setDefaultKeychainCache:(MSIDKeychainTokenCache *)defaultKeychainCache
{
    if (!defaultKeychainCache)
    {
        return;
    }
    
    _defaultCache = defaultKeychainCache;
}

- (instancetype)initWithGroup:(NSString *)accessGroup
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!accessGroup)
    {
        MSID_LOG_INFO(nil, @"Keychain initialization with nil accessGroup.");
        return nil;
    }
    
    MSID_LOG_INFO(nil, @"Using keychain accessGroup: %@", _PII_NULLIFY(accessGroup));
    MSID_LOG_INFO_PII(nil, @"Using keychain accessGroup: %@", accessGroup);
    
    _accessGroup = accessGroup;
    
    return self;
}

#pragma mark - MSIDTokenCacheDataSource

- (BOOL)setItem:(MSIDToken *)item
        withKey:(MSIDTokenCacheKey *)key
     serializer:(id<MSIDTokenSerializer>)serializer
        context:(id<MSIDRequestContext>)context
          error:(NSError **)error
{
    assert(key);
    assert(serializer);
    
    MSID_LOG_INFO(context, @"Set keychain item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Set keychain item, key info (account: %@ service: %@)", key.account, key.service);
    MSID_LOG_INFO_PII(context, @"Item info %@", item);
    
    if (!key.service || !key.account)
    {
        if (error)
        {
            // TODO: Use proper domain & error code.
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Key is not valid. Make sure service and account are not nil."}];
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }

    NSData *itemData = [serializer serialize:item];
    if (!itemData)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Failed to serialize token item."}];
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    NSMutableDictionary *query = [@{(id)kSecClass : (id)kSecClassGenericPassword} mutableCopy];
    [query setObject:key.service forKey:(id)kSecAttrService];
    [query setObject:key.account forKey:(id)kSecAttrAccount];
    [query setObject:self.accessGroup forKey:(id)kSecAttrAccessGroup];
    // Backward compatibility with ADAL.
    [query setObject:[s_libraryString dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecAttrGeneric];
    // Backward compatibility with MSAL.
    [query setObject:[NSNumber numberWithUnsignedInt:item.tokenType] forKey:(id)kSecAttrType];
    
    MSID_LOG_INFO(context, @"Trying to update keychain item...");
    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)@{(id)kSecValueData : itemData});
    MSID_LOG_INFO(context, @"Keychain update status: %d", status);
    if (status == errSecItemNotFound)
    {
        [query setObject:itemData forKey:(id)kSecValueData];
        [query setObject:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(id)kSecAttrAccessible];
        
        MSID_LOG_INFO(context, @"Trying to add keychain item...");
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_INFO(context, @"Keychain add status: %d", status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:status userInfo:@{NSLocalizedDescriptionKey:@"Failed to set item into keychain."}];
        }
        MSID_LOG_ERROR(context, @"Failed to set item into keychain (status: %d)", status);
    }
    
    return status == errSecSuccess;
}

- (MSIDToken *)itemWithKey:(MSIDTokenCacheKey *)key
                serializer:(id<MSIDTokenSerializer>)serializer
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    MSID_LOG_INFO(context, @"itemWithKey:serializer:context:error:");
    return [self itemsWithKey:key serializer:serializer context:context error:error].firstObject;
}

- (BOOL)removeItemWithKey:(MSIDTokenCacheKey *)key
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    assert(key);
    
    MSID_LOG_INFO(context, @"Remove keychain item, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Remove keychain item, key info (account: %@ service: %@)", key.account, key.service);
    
    if (!key.service || !key.account)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Key is not valid. Make sure service and account are not nil."}];
        }
        MSID_LOG_ERROR(context, @"Remove keychain item with invalid key.");
        return NO;
    }
    
    NSMutableDictionary *query = [@{(id)kSecClass : (id)kSecClassGenericPassword} mutableCopy];
    [query setObject:key.service forKey:(id)kSecAttrService];
    [query setObject:key.account forKey:(id)kSecAttrAccount];
    
    MSID_LOG_INFO(context, @"Trying to delete keychain item...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", status);
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:status userInfo:@{NSLocalizedDescriptionKey:@"Failed to remove item from keychain."}];
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain item (status: %d)", status);
    }
    
    return YES;
}

- (NSArray<MSIDToken *> *)itemsWithKey:(MSIDTokenCacheKey *)key
                            serializer:(id<MSIDTokenSerializer>)serializer
                               context:(id<MSIDRequestContext>)context
                                 error:(NSError **)error
{
    
    assert(key);
    assert(serializer);
    
    MSID_LOG_INFO(context, @"Get keychain items, key info (account: %@ service: %@)", _PII_NULLIFY(key.account), _PII_NULLIFY(key.service));
    MSID_LOG_INFO_PII(context, @"Get keychain items, key info (account: %@ service: %@)", key.account, key.service);
    
    NSMutableDictionary *query = [@{(id)kSecClass : (id)kSecClassGenericPassword} mutableCopy];
    if (key.service)
    {
        [query setObject:key.service forKey:(id)kSecAttrService];
    }
    if (key.account)
    {
        [query setObject:key.account forKey:(id)kSecAttrAccount];
    }
    [query setObject:self.accessGroup forKey:(id)kSecAttrAccessGroup];
    [query setObject:@YES forKey:(id)kSecReturnData];
    [query setObject:@YES forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    
    CFTypeRef cfItems = nil;
    MSID_LOG_INFO(context, @"Trying to find keychain items...");
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    MSID_LOG_INFO(context, @"Keychain find status: %d", status);
    
    if (status == errSecItemNotFound)
    {
        return @[];
    }
    else if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:status userInfo:@{NSLocalizedDescriptionKey:@"Failed to get items from keychain."}];
        }
        MSID_LOG_ERROR(context, @"Failed to find keychain item (status: %d)", status);
        return nil;
    }
    
    NSArray *items = CFBridgingRelease(cfItems);
    
    NSMutableArray *tokenItems = [[NSMutableArray<MSIDToken *> alloc] initWithCapacity:items.count];
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDToken *tokenItem = [serializer deserialize:itemData];
        
        if (tokenItem)
        {
            [tokenItems addObject:tokenItem];
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

- (BOOL)saveWipeInfo:(NSDictionary *)wipeInfo
                  context:(id<MSIDRequestContext>)context
               error:(NSError **)error
{
    MSID_LOG_INFO_PII(context, @"Full wipe info: %@", wipeInfo);
    
    NSData *wipeData = [NSKeyedArchiver archivedDataWithRootObject:wipeInfo];
    MSID_LOG_INFO(context, @"Trying to update wipe info...");
    MSID_LOG_INFO_PII(context, @"Wipe query: %@", [self wipeQuery]);
    OSStatus status = SecItemUpdate((CFDictionaryRef)[self wipeQuery], (CFDictionaryRef)@{ (id)kSecValueData:wipeData});
    MSID_LOG_INFO(context, @"Update wipe info status: %d", status);
    if (status == errSecItemNotFound)
    {
        NSMutableDictionary *mutableQuery = [[self wipeQuery] mutableCopy];
        [mutableQuery addEntriesFromDictionary: @{(id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                  (id)kSecValueData : wipeData}];
        MSID_LOG_INFO(context, @"Trying to add wipe info...");
        status = SecItemAdd((CFDictionaryRef)mutableQuery, NULL);
        MSID_LOG_INFO(context, @"Add wipe info status: %d", status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:status userInfo:@{NSLocalizedDescriptionKey:@"Failed to save wipe token data into keychain."}];
        }
        MSID_LOG_ERROR(context, @"Failed to save wipe token data into keychain (status: %d)", status);
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
    MSID_LOG_INFO(context, @"Get wipe info status: %d", status);
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = [[NSError alloc] initWithDomain:@"MSIDErrorDomain" code:status userInfo:@{NSLocalizedDescriptionKey:@"Failed to get a wipe data from keychain."}];
        }
        MSID_LOG_ERROR(context, @"Failed to get a wipe data from keychain (status: %d)", status);
        return nil;
    }
    
    NSDictionary *wipeData = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)(data)];
    CFRelease(data);
    
    return wipeData;
}

#pragma mark - Private

- (NSDictionary *)wipeQuery
{
    static NSDictionary *wipeQuery;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wipeQuery = @{(id)kSecClass : (id)kSecClassGenericPassword,
                       (id)kSecAttrGeneric : [s_wipeLibraryString dataUsingEncoding:NSUTF8StringEncoding],
                       (id)kSecAttrAccessGroup : self.accessGroup,
                       (id)kSecAttrAccount : @"TokenWipe"};
    });
    return wipeQuery;
}

@end
