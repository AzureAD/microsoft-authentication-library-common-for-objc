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

#import "MSIDMacACLKeychainAccessor.h"
#import "MSIDLogger+Trace.h"
#import "MSIDLogger+Internal.h"
#import "MSIDKeychainUtil.h"

static dispatch_queue_t s_customizedSynchronizationQueue;
static dispatch_queue_t s_defaultSynchronizationQueue;

@interface MSIDMacACLKeychainAccessor ()

@property (atomic, readwrite, nonnull) id accessControlForSharedItems;
@property (atomic, readwrite, nonnull) id accessControlForNonSharedItems;

@end

@implementation MSIDMacACLKeychainAccessor

#pragma mark - Init

- (nullable instancetype)initWithTrustedApplications:(nullable NSArray *)trustedApplications
                                         accessLabel:(nonnull NSString *)accessLabel
                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    MSID_TRACE;

    self = [super init];
    if (self)
    {
        NSArray *appList = [self createTrustedAppListWithCurrentApp:error];
        
        if (![appList count])
        {
            return nil;
        }
        
        NSMutableArray *allTrustedApps = [NSMutableArray new];
        [allTrustedApps addObjectsFromArray:trustedApplications];
        [allTrustedApps addObjectsFromArray:appList];
        
        self.accessControlForSharedItems = [self accessCreateWithChangeACL:allTrustedApps accessLabel:accessLabel error:error];
        if (!self.accessControlForSharedItems)
        {
            return nil;
        }
        
        self.accessControlForNonSharedItems = [self accessCreateWithChangeACL:appList accessLabel:accessLabel error:error];
        if (!self.accessControlForNonSharedItems)
        {
            return nil;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Init MSIDMacACLPersistentTokenCache");
    }

    return self;
}

+ (void)setSynchronizationQueue:(dispatch_queue_t)synchronizationQueue
{
    @synchronized(self)
    {
        if (s_customizedSynchronizationQueue)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to set customized synchronization queue, customized synchronization queue has already been set already.");
            return;
        }
        
        static dispatch_once_t s_once;
        dispatch_once(&s_once, ^{
            s_customizedSynchronizationQueue = synchronizationQueue;
        });
    }
}

+ (dispatch_queue_t)synchronizationQueue
{
    
    if (s_customizedSynchronizationQueue)
    {
        return s_customizedSynchronizationQueue;
    }
    
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
        s_defaultSynchronizationQueue = dispatch_queue_create("com.microsoft.msidmackeychaintokencache", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return s_defaultSynchronizationQueue;
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

- (id)accessCreateWithChangeACL:(NSArray<id> *)trustedApplications
                    accessLabel:(NSString *)accessLabel
                          error:(NSError **)error
{
    SecAccessRef access;
    OSStatus status = SecAccessCreate((__bridge CFStringRef)accessLabel, (__bridge CFArrayRef)trustedApplications, &access);
    
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

#pragma mark - Utils

- (BOOL)createError:(NSString*)message
             domain:(NSErrorDomain)domain
          errorCode:(NSInteger)code
              error:(NSError *_Nullable *_Nullable)error
            context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"%@", message);
    if (error)
    {
        *error = MSIDCreateError(domain, code, message, nil, nil, nil, context.correlationId, nil, NO);
    }
    
    return YES;
}

#pragma mark - Operations

- (BOOL)saveData:(NSData *)data
      attributes:(NSDictionary *)attributes
         context:(id<MSIDRequestContext>)context
           error:(NSError **)error
{
    if (!data)
    {
        [self createError:@"Nil data provided" domain:MSIDErrorDomain errorCode:MSIDErrorInvalidInternalParameter error:error context:context];
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Saving keychain item");
    
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    [query addEntriesFromDictionary:attributes];
    NSMutableDictionary *updateQuery = [NSMutableDictionary new];
    updateQuery[(id)kSecValueData] = data;
    
    __block OSStatus status;
    dispatch_barrier_sync(self.class.synchronizationQueue, ^{
        status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)updateQuery);
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Keychain update status: %d.", (int)status);
        
        if (status == errSecItemNotFound)
        {
            [query addEntriesFromDictionary:updateQuery];
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

- (BOOL)removeItemWithAttributes:(NSDictionary *)attributes
                         context:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    [query addEntriesFromDictionary:attributes];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(self.class.synchronizationQueue, ^{
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

- (NSData *)getDataWithAttributes:(NSDictionary *)attributes
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    [query addEntriesFromDictionary:attributes];
    query[(id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
    query[(id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Trying to find keychain items...");
    
    __block CFDictionaryRef result = nil;
    __block OSStatus status;
    
    dispatch_sync(self.class.synchronizationQueue, ^{
        status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    });
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Keychain find status: %d.", (int)status);
        
    if (status == errSecSuccess)
    {
        NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
        NSData *storageData = [resultDict objectForKey:(id)kSecValueData];
        return storageData;
    }
    else if (status == errSecItemNotFound)
    {
        return nil;
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to read stored item from keychain (status: %d).", (int)status);
        [self createError:@"Failed to read stored item from keychain."
                   domain:MSIDKeychainErrorDomain errorCode:status error:error context:context];
        return nil;
    }
}

#pragma mark - Clear

// A test-only method that deletes all items from the cache for the given context.
- (BOOL)clearWithAttributes:(NSDictionary *)attributes
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error

{
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,context, @"Clearing the whole context. This should only be executed in tests.");
    
    // Delete all accounts for the keychainGroup
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    [query addEntriesFromDictionary:attributes];
    
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Trying to delete keychain items...");
    __block OSStatus status;
    dispatch_barrier_sync(self.class.synchronizationQueue, ^{
        status = SecItemDelete((CFDictionaryRef)query);
    });
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,context, @"Keychain delete status: %d.", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil, NO);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"Failed to delete keychain items (status: %d).", (int)status);
        }
        return NO;
    }

    return YES;
}

@end
