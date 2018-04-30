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

#import "MSIDAuthority.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAuthorityResolverProtocol.h"
#import "MSIDAadAuthorityResolver.h"
#import "MSIDAADGetAuthorityMetadataRequest.h"
#import "MSIDDRSDiscoveryRequest.h"
#import "MSIDWebFingerRequest.h"
#import "MSIDAuthorityResolverProtocol.h"
#import "MSIDAadAuthorityResolver.h"
#import "MSIDB2CAuthorityResolver.h"
#import "MSIDAdfsAuthorityResolver.h"
#import "MSIDOpenIdConfigurationInfoRequest.h"

static NSSet<NSString *> *s_trustedHostList;

// Trusted authorities
static NSString *const MSIDTrustedAuthority             = @"login.windows.net";
static NSString *const MSIDTrustedAuthorityUS           = @"login.microsoftonline.us";
static NSString *const MSIDTrustedAuthorityChina        = @"login.chinacloudapi.cn";
static NSString *const MSIDTrustedAuthorityGermany      = @"login.microsoftonline.de";
static NSString *const MSIDTrustedAuthorityWorldWide    = @"login.microsoftonline.com";
static NSString *const MSIDTrustedAuthorityUSGovernment = @"login-us.microsoftonline.com";
static NSString *const MSIDTrustedAuthorityCloudGovApi  = @"login.cloudgovapi.us";

@implementation MSIDAuthority

+ (void)initialize
{
    s_trustedHostList = [NSSet setWithObjects:MSIDTrustedAuthority,
                         MSIDTrustedAuthorityUS,
                         MSIDTrustedAuthorityChina,
                         MSIDTrustedAuthorityGermany,
                         MSIDTrustedAuthorityWorldWide,
                         MSIDTrustedAuthorityUSGovernment,
                         MSIDTrustedAuthorityCloudGovApi, nil];
                        //    login.microsoftonline.us ???
}

+ (BOOL)isADFSInstance:(NSString *)endpoint
{
    if ([NSString msidIsStringNilOrBlank:endpoint])
    {
        return NO;
    }
    
    return [[self class] isADFSInstanceURL:[NSURL URLWithString:endpoint.lowercaseString]];
}

+ (BOOL)isADFSInstanceURL:(NSURL *)endpointUrl
{
    if (!endpointUrl)
    {
        return NO;
    }
    
    NSArray *paths = endpointUrl.pathComponents;
    if (paths.count >= 2)
    {
        NSString *tenant = [paths objectAtIndex:1];
        return [@"adfs" isEqualToString:tenant];
    }
    return NO;
}

+ (BOOL)isB2CInstanceURL:(NSURL *)endpointUrl
{
    if (!endpointUrl)
    {
        return NO;
    }
    
    NSArray *paths = endpointUrl.pathComponents;
    if (paths.count >= 2)
    {
        NSString *tenant = [paths objectAtIndex:1];
        return [@"tfp" isEqualToString:tenant];
    }
    return NO;
}

+ (BOOL)isConsumerInstanceURL:(NSURL *)authorityURL
{
    if (!authorityURL)
    {
        return NO;
    }
    
    NSArray *paths = authorityURL.pathComponents;
    
    if ([paths count] >= 2)
    {
        NSString *tenantName = [paths[1] lowercaseString];
        
        return [tenantName isEqualToString:@"consumers"];
    }
    
    return NO;
}

+ (NSURL *)universalAuthorityURL:(NSURL *)authorityURL
{
    if (!authorityURL)
    {
        return nil;
    }
    
    NSArray *paths = authorityURL.pathComponents;
    
    if ([paths count] >= 2)
    {
        NSString *tenantName = [paths[1] lowercaseString];
        
        if ([tenantName isEqualToString:@"organizations"])
        {
            NSURLComponents *components = [NSURLComponents componentsWithURL:authorityURL resolvingAgainstBaseURL:NO];
            components.path = @"/common";
            return [components URL];
        }
    }
    
    return authorityURL;
}

+ (BOOL)isTenantless:(NSURL *)authority
{
    NSArray *authorityURLPaths = authority.pathComponents;
    
    if ([authorityURLPaths count] >= 2)
    {
        NSString *tenantName = [authorityURLPaths[1] lowercaseString];
        
        if ([tenantName isEqualToString:@"common"] ||
            [tenantName isEqualToString:@"organizations"])
        {
            return YES;
        }
    }
    
    return NO;
}

+ (NSURL *)cacheUrlForAuthority:(NSURL *)authority
                       tenantId:(NSString *)tenantId
{
    if (!tenantId)
    {
        return authority;
    }
    
    if ([self isADFSInstanceURL:authority])
    {
        return authority;
    }
    
    if (![self isTenantless:authority])
    {
        return authority;
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [authority msidHostWithPortIfNecessary], tenantId]];
}

+ (void)discoverAuthority:(NSURL *)authority
        userPrincipalName:(NSString *)upn
                 validate:(BOOL)validate
                  context:(id<MSIDRequestContext>)context
          completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    NSError *error;
    authority = [self normalizeAuthority:authority context:context error:&error];
    
    if (error)
    {
        if (completionBlock) completionBlock(nil, nil, NO, error);
        return;
    }
    
    id <MSIDAuthorityResolverProtocol> resolver;
    // ADFS.
    if ([MSIDAuthority isADFSInstanceURL:authority])
    {
        resolver = [MSIDAdfsAuthorityResolver new];
    }
    // B2C.
    else if ([MSIDAuthority isB2CInstanceURL:authority])
    {
        resolver = [MSIDB2CAuthorityResolver new];
    }
    // AAD.
    else
    {
        resolver = [MSIDAadAuthorityResolver new];
    }
    
    [resolver discoverAuthority:authority
              userPrincipalName:upn
                       validate:validate
                        context:context
                completionBlock:completionBlock];
}

+ (void)loadOpenIdConfigurationInfo:(NSURL *)openIdConfigurationEndpoint
                            context:(id<MSIDRequestContext>)context
                    completionBlock:(MSIDOpenIdConfigurationInfoBlock)completionBlock
{
    __auto_type request = [[MSIDOpenIdConfigurationInfoRequest alloc] initWithEndpoint:openIdConfigurationEndpoint];
    [request sendWithBlock:completionBlock];
}

+ (NSURL *)normalizeAuthority:(NSURL *)authority
                      context:(id<MSIDRequestContext>)context
                        error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:authority.absoluteString])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"'authority' is a required parameter and must not be nil or empty.", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    if (![authority.scheme isEqualToString:@"https"])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"authority must use HTTPS.", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    if (authority.pathComponents.count < 2)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"authority must specify a tenant or common.", nil, nil, nil, context.correlationId, nil);
        }
        return nil;
    }
    
    // B2C
    if ([self isB2CInstanceURL:authority])
    {
        if (authority.pathComponents.count < 3)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"B2C authority should have at least 3 segments in the path (i.e. https://<host>/tfp/<tenant>/<policy>/...)", nil, nil, nil, context.correlationId, nil);
            }
            return nil;
        }
        
        NSString *updatedAuthorityString = [NSString stringWithFormat:@"https://%@/%@/%@/%@", [authority msidHostWithPortIfNecessary], authority.pathComponents[1], authority.pathComponents[2], authority.pathComponents[3]];
        return [NSURL URLWithString:updatedAuthorityString];
    }
    
    // ADFS and AAD
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [authority msidHostWithPortIfNecessary], authority.pathComponents[1]]];
}

+ (BOOL)isKnownHost:(NSURL *)url
{
    return [s_trustedHostList containsObject:url.host.lowercaseString];
}

@end
