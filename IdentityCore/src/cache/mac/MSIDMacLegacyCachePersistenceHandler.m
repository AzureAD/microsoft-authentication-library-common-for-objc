//
//  MSIDMacLegacyCachePersistenceHandler.m
//  IdentityCore Mac
//
//  Created by Olga Dalton on 10/26/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDMacLegacyCachePersistenceHandler.h"

@interface MSIDMacLegacyCachePersistenceHandler()

@property (nonatomic) NSDictionary *keychainAttributes;

@end

@implementation MSIDMacLegacyCachePersistenceHandler

#pragma mark - Init

- (nullable instancetype)initWithTrustedApplications:(nullable NSArray *)trustedApplications
                                         accessLabel:(nonnull NSString *)accessLabel
                                          attributes:(nonnull NSDictionary *)attributes
                                               error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    self = [super initWithTrustedApplications:trustedApplications accessLabel:accessLabel error:error];
    
    if (self)
    {
        if (!attributes[(id)kSecAttrService] || !attributes[(id)kSecAttrAccount])
        {
            [self createError:@"Invalid attributes provided without service or account"
                       domain:MSIDErrorDomain
                    errorCode:MSIDErrorInvalidDeveloperParameter
                        error:error
                      context:nil];
            return nil;
        }
        
        self.keychainAttributes = attributes;
    }
    
    return self;
}

#pragma mark - MSIDMacTokenCacheDelegate

- (void)willAccessCache:(nonnull MSIDMacTokenCache *)cache
{
    [self readAndDeserializeWithCache:cache];
}

- (void)didAccessCache:(nonnull MSIDMacTokenCache *)cache
{
    
}

- (void)willWriteCache:(nonnull MSIDMacTokenCache *)cache
{
   [self readAndDeserializeWithCache:cache];
}

- (void)didWriteCache:(nonnull MSIDMacTokenCache *)cache
{
    NSData *data = [cache serialize];
    
    NSError *writeError = nil;
    BOOL result = [self saveData:data attributes:[self keychainQuery] context:nil error:&writeError];
    
    if (!result)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to write data to keychain with error %@", MSID_PII_LOG_MASKABLE(writeError));
    }
}

#pragma mark - Internal

- (void)readAndDeserializeWithCache:(nonnull MSIDMacTokenCache *)cache
{
    NSError *readError = nil;
    NSData *data = [self getDataWithAttributes:[self keychainQuery] context:nil error:&readError];
    
    if (readError)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to read cache with error %@", MSID_PII_LOG_MASKABLE(readError));
        return;
    }
    
    if (data)
    {
        [cache deserialize:data error:&readError];
    }
    
    if (readError)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to deserialize cache with error %@", MSID_PII_LOG_MASKABLE(readError));
    }
}

- (NSDictionary *)keychainQuery
{
    NSMutableDictionary *query = [NSMutableDictionary new];
    [query addEntriesFromDictionary:self.keychainAttributes];
    
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecAttrAccess] = self.accessControlForSharedItems;
    
    return query;
}

@end
