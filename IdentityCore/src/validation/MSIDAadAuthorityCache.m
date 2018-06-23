//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAadAuthorityCache.h"
#include <pthread.h>
#import "MSIDError.h"
#import "MSIDAuthority.h"
#import "MSIDAadAuthorityCacheRecord.h"

#define CHECK_CLASS_TYPE(_CHK, _CLS, _ERROR) \
    if (![_CHK isKindOfClass:[_CLS class]]) { \
        NSError *msidError = \
        MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, _ERROR, nil, nil, nil, context.correlationId, nil); \
        if (error) { *error = msidError; } \
        return NO; \
    }

@implementation MSIDAadAuthorityCache

+ (MSIDAadAuthorityCache *)sharedInstance
{
    static MSIDAadAuthorityCache *singleton = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        singleton = [[MSIDAadAuthorityCache alloc] init];
    });
    
    return singleton;
}

- (void)processMetadata:(NSArray<NSDictionary *> *)metadata
   openIdConfigEndpoint:(NSURL *)openIdConfigEndpoint
              authority:(NSURL *)authority
                context:(id<MSIDRequestContext>)context
             completion:(void (^)(BOOL result, NSError *error))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        BOOL result = [self processImpl:metadata authority:authority openIdConfigEndpoint:openIdConfigEndpoint context:context error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, error);
        });
    });
}

static BOOL VerifyHostString(NSString *host, NSString *label, BOOL isAliases, id<MSIDRequestContext> context, NSError * __autoreleasing *error)
{
    CHECK_CLASS_TYPE(host, NSString, ([NSString stringWithFormat:@"\"%@\" in JSON authority validation metadata must be %@", label, isAliases ? @"an array of strings" : @"a string"]));
    
    @try
    {
        // Run this through urlForPreferredHost to make sure it does not throw any exceptions
        urlForPreferredHost([NSURL URLWithString:@"https://fakeurl.contoso.com"], host);
        
        return YES;
    }
    @catch (NSException *ex)
    {
        NSString *details = nil;
        if (isAliases)
        {
            details = [NSString stringWithFormat:@"\"%@\" must contain valid percent encoded host strings", label];
        }
        else
        {
            details = [NSString stringWithFormat:@"\"%@\" must have a valid percent encoded host", label];
        }
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, details, nil, nil, nil, context.correlationId, nil);
        if (error)
        {
            *error = msidError;
        }
        return NO;
    }
}

#define VERIFY_HOST_STRING(_HOST, _LABEL, _ISALIASES) if (!VerifyHostString(_HOST, _LABEL, _ISALIASES, context, error)) { return NO; }

- (BOOL)processImpl:(NSArray<NSDictionary *> *)metadata
          authority:(NSURL *)authority
openIdConfigEndpoint:(NSURL *)openIdConfigEndpoint
            context:(id<MSIDRequestContext>)context
              error:(NSError * __autoreleasing *)error
{
    if (metadata != nil)
    {
        CHECK_CLASS_TYPE(metadata, NSArray, @"JSON metadata from authority validation is not an array");
    }
    
    if (metadata.count == 0)
    {
        MSID_LOG_INFO(context, @"No metadata returned from authority validation");
    }
    else
    {
        MSID_LOG_INFO(context, @"Caching AAD Environements");
    }
    
    NSMutableArray<MSIDAadAuthorityCacheRecord *> *recordsToAdd = [NSMutableArray new];
    
    for (NSDictionary *environment in metadata)
    {
        CHECK_CLASS_TYPE(environment, NSDictionary, @"JSON metadata entry is not a dictionary");
        
        __auto_type record = [MSIDAadAuthorityCacheRecord new];
        record.validated = YES;
        
        NSString *networkHost = environment[@"preferred_network"];
        VERIFY_HOST_STRING(networkHost, @"preferred_network", NO);
        record.networkHost = networkHost;
        
        NSString *cacheHost = environment[@"preferred_cache"];
        VERIFY_HOST_STRING(cacheHost, @"preferred_cache", NO);
        record.cacheHost = cacheHost;
        
        NSArray *aliases = environment[@"aliases"];
        CHECK_CLASS_TYPE(aliases, NSArray, @"\"alias\" in JSON authority validation metadata must be an array");
        record.aliases = aliases;
        
        for (NSString *alias in aliases)
        {
            VERIFY_HOST_STRING(alias, @"aliases", YES);
        }
        
        record.openIdConfigurationEndpoint = openIdConfigEndpoint;
        
        [recordsToAdd addObject:record];
    }
    
    for (MSIDAadAuthorityCacheRecord *record in recordsToAdd)
    {
        __auto_type aliases = record.aliases;
        for (NSString *alias in aliases)
        {
            [self setObject:record forKey:alias];
        }

        MSID_LOG_INFO_PII(context, @"(%@, %@) : %@", record.networkHost, record.cacheHost, aliases);
    }
    
    // In case the authority we were looking for wasn't in the metadata
    NSString *authorityHost = authority.msidHostWithPortIfNecessary;
    
    if (![self objectForKey:authorityHost])
    {
        __auto_type record = [MSIDAadAuthorityCacheRecord new];
        record.validated = YES;
        record.cacheHost = authorityHost;
        record.networkHost = authorityHost;
        
        [self setObject:record forKey:authorityHost];
    }
    
    return YES;
}

- (void)addInvalidRecord:(NSURL *)authority
              oauthError:(NSError *)oauthError
                 context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WARN(context, @"Caching Invalid AAD Instance");
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = NO;
    record.error = oauthError;
    [self setObject:record forKey:authority.msidHostWithPortIfNecessary];
}

#pragma mark -
#pragma mark Cache Accessors

- (MSIDAadAuthorityCacheRecord *)checkCacheImpl:(NSString *)environment
{
    return [self objectForKey:authority.msidHostWithPortIfNecessary];
}

static NSURL *urlForPreferredHost(NSURL *url, NSString *preferredHost)
{
    if (!preferredHost)
    {
        return url;
    }
    
    if ([url.msidHostWithPortIfNecessary isEqualToString:preferredHost])
    {
        return url;
    }
    
    // Otherwise switch the host for the preferred one.
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    
    NSArray *hostComponents = [preferredHost componentsSeparatedByString:@":"];
    
    // I hope there's never a case where there's percent encoded characters in the host, but using
    // this setter prevents NSURLComponents from trying to do any further mangling on the string,
    // probably a good thing.
    components.percentEncodedHost = hostComponents[0];
    
    if (hostComponents.count > 1)
    {
        NSScanner *scanner = [NSScanner scannerWithString:hostComponents[1]];
        int port = 0;
        if (![scanner scanInt:&port] || !scanner.isAtEnd || port < 1 )
        {
            // setPercentEncodedHost and setPort both throw if there's an error. The validation code runs
            // this function in a try block first to make sure the data is valid, so it's okay for
            // us to throw here as well to propogate the error
            @throw [NSException exceptionWithName:@"InvalidNumberFormatException" reason:@"Port is not a valid integer or port" userInfo:nil];
        }
        components.port = [NSNumber numberWithInt:port];
    }
    else
    {
        components.port = nil;
    }
    
    return components.URL;
}

- (NSURL *)networkUrlForAuthority:(NSURL *)authority
                          context:(id<MSIDRequestContext>)context
{
    if ([MSIDAuthority isADFSInstanceURL:authority])
    {
        return authority;
    }
    
    NSURL *url = [self networkUrlForAuthorityImpl:authority];
    if (!url)
    {
        MSID_LOG_WARN(context, @"No cached preferred_network for authority");
        return authority;
    }
    
    return url;
}

- (NSURL *)cacheUrlForAuthority:(NSURL *)authority
                        context:(id<MSIDRequestContext>)context
{
    if ([MSIDAuthority isADFSInstanceURL:authority])
    {
        return authority;
    }
    
    NSURL *url = [self cacheUrlForAuthorityImpl:authority];
    if (!url)
    {
        MSID_LOG_WARN(context, @"No cached preferred_cache for authority");
        return authority;
    }
    
    
    return url;
}

- (NSString *)cacheEnvironmentForEnvironment:(NSString *)environment
                                     context:(id<MSIDRequestContext>)context
{
    NSString *cacheEnvironment = [self cacheEnvironmentForEnvironmentImpl:environment];
    if (!cacheEnvironment)
    {
        MSID_LOG_WARN(context, @"No cached preferred_cache for environment");
        return environment;
    }

    return cacheEnvironment;
}

- (NSArray<NSURL *> *)cacheAliasesForAuthority:(NSURL *)authority
{
    if (!authority) return @[];
    
    if ([MSIDAuthority isADFSInstanceURL:authority])
    {
        return @[ authority ];
    }
    
    return [self cacheAliasesForAuthorityImpl:authority];
}

- (NSArray<NSString *> *)cacheAliasesForEnvironment:(NSString *)environment
{
    if (!environment)
    {
        return @[];
    }

    return [self cacheAliasesForEnvironmentImpl:environment];
}

- (NSURL *)networkUrlForAuthorityImpl:(NSURL *)authority
{
    MSIDAadAuthorityCacheRecord *record = [self objectForKey:authority.msidHostWithPortIfNecessary];
    if (!record)
    {
        return nil;
    }
    
    return urlForPreferredHost(authority, record.networkHost);
}

- (NSURL *)cacheUrlForAuthorityImpl:(NSURL *)authority
{
    MSIDAadAuthorityCacheRecord *record = [self objectForKey:authority.msidHostWithPortIfNecessary];
    if (!record)
    {
        return nil;
    }
    
    return urlForPreferredHost(authority, record.cacheHost);
}

- (NSString *)cacheEnvironmentForEnvironmentImpl:(NSString *)environment
{
    __auto_type record = [self checkCache:environment];
    if (!record)
    {
        return nil;
    }

    return record.cacheHost;
}

- (NSArray<NSURL *> *)cacheAliasesForAuthorities:(NSArray<NSURL *> *)authorities
{
    NSMutableArray<NSURL *> *resultAuthorities = [NSMutableArray new];

    for (NSURL *authority in authorities)
    {
        [resultAuthorities addObjectsFromArray:[self cacheAliasesForAuthority:authority]];
    }

    return resultAuthorities;
}

- (NSArray<NSURL *> *)cacheAliasesForAuthorityImpl:(NSURL *)authority
{
    NSMutableArray<NSURL *> *authorities = [NSMutableArray new];
    
    MSIDAadAuthorityCacheRecord *record = [self objectForKey:authority.msidHostWithPortIfNecessary];
    if (!record)
    {
        [authorities addObject:authority];
        return authorities;
    }
    
    NSArray<NSString *> *aliases = record.aliases;
    NSString *cacheHost = record.cacheHost;
    NSString *host = authority.msidHostWithPortIfNecessary;
    if (cacheHost)
    {
        // The cache lookup order for authorities is defined as the preferred host first
        [authorities addObject:urlForPreferredHost(authority, cacheHost)];
        if (![cacheHost isEqualToString:host])
        {
            // Followed by the authority provided by the developer, provided here by the authority
            // URL passed into this method
            [authorities addObject:authority];
        }
    }
    else
    {
        [authorities addObject:authority];
    }
    
    // And then we add any remaining aliases listed in the metadata
    for (NSString *alias in aliases)
    {
        if ([alias isEqualToString:host] || (cacheHost && [alias isEqualToString:cacheHost]))
        {
            continue;
        }
        
        [authorities addObject:urlForPreferredHost(authority, alias)];
    }
    
    return authorities;
}

- (NSArray<NSString *> *)cacheAliasesForEnvironmentImpl:(NSString *)environment
{
    NSMutableArray<NSString *> *environments = [NSMutableArray new];

    __auto_type record = [self checkCache:environment];
    if (!record)
    {
        [environments addObject:environment];
        return environments;
    }

    NSArray<NSString *> *aliases = record.aliases;
    NSString *cacheEnvironment = record.cacheHost;
    if (cacheEnvironment)
    {
        // The cache lookup order for authorities is defined as the preferred host first
        [environments addObject:cacheEnvironment];
        if (![cacheEnvironment isEqualToString:environment])
        {
            // Followed by the authority provided by the developer, provided here by the authority
            // URL passed into this method
            [environments addObject:environment];
        }
    }
    else
    {
        [environments addObject:environment];
    }

    // And then we add any remaining aliases listed in the metadata
    for (NSString *alias in aliases)
    {
        if ([alias isEqualToString:environment] || [alias isEqualToString:environment])
        {
            continue;
        }

        [environments addObject:alias];
    }

    return environments;
}

@end
