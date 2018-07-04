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
#import "MSIDAuthorityResolving.h"
#import "MSIDAadAuthorityResolver.h"
#import "MSIDAADAuthorityMetadataRequest.h"
#import "MSIDDRSDiscoveryRequest.h"
#import "MSIDWebFingerRequest.h"
#import "MSIDAuthorityResolving.h"
#import "MSIDAadAuthorityResolver.h"
#import "MSIDB2CAuthorityResolver.h"
#import "MSIDAdfsAuthorityResolver.h"
#import "MSIDOpenIdConfigurationInfoRequest.h"

// Trusted authorities
NSString *const MSIDTrustedAuthority             = @"login.windows.net";
NSString *const MSIDTrustedAuthorityUS           = @"login.microsoftonline.us";
NSString *const MSIDTrustedAuthorityChina        = @"login.chinacloudapi.cn";
NSString *const MSIDTrustedAuthorityGermany      = @"login.microsoftonline.de";
NSString *const MSIDTrustedAuthorityWorldWide    = @"login.microsoftonline.com";
NSString *const MSIDTrustedAuthorityUSGovernment = @"login-us.microsoftonline.com";
NSString *const MSIDTrustedAuthorityCloudGovApi  = @"login.cloudgovapi.us";

static NSSet<NSString *> *s_trustedHostList;
static MSIDCache <NSString *, MSIDOpenIdProviderMetadata *> *s_openIdConfigurationCache;

@implementation MSIDAuthority

+ (void)initialize
{
    if (self == [MSIDAuthority self])
    {
        s_trustedHostList = [NSSet setWithObjects:MSIDTrustedAuthority,
                             MSIDTrustedAuthorityUS,
                             MSIDTrustedAuthorityChina,
                             MSIDTrustedAuthorityGermany,
                             MSIDTrustedAuthorityWorldWide,
                             MSIDTrustedAuthorityUSGovernment,
                             MSIDTrustedAuthorityCloudGovApi, nil];
        
        s_openIdConfigurationCache = [MSIDCache new];
    }
}

+ (MSIDCache *)openIdConfigurationCache
{
    return s_openIdConfigurationCache;
}

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        BOOL isValid = [self.class isAuthorityFormatValid:url context:context error:error];
        if (!isValid) return nil;
        
        _url = url;
    }
    
    return self;
}

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                           rawTenant:(nullable NSString *)rawTenant
                             context:(nullable id<MSIDRequestContext>)context
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [self initWithURL:url context:context error:error];
}

- (void)resolveAndValidate:(BOOL)validate
         userPrincipalName:(nullable NSString *)upn
                   context:(nullable id<MSIDRequestContext>)context
           completionBlock:(nonnull MSIDAuthorityInfoBlock)completionBlock
{
    // TODO: abstract.
}

- (NSURL *)networkUrlWithContext:(id<MSIDRequestContext>)context
{
    return self.url;
}

- (NSURL *)cacheUrlWithContext:(id<MSIDRequestContext>)context
{
    return self.url;
}

- (NSArray<NSURL *> *)cacheAliases
{
    return @[self.url];
}

- (NSURL *)universalAuthorityURL
{
    return self.url;
}

- (BOOL)isKnown
{
    return [s_trustedHostList containsObject:self.url.host.lowercaseString];
}

+ (BOOL)isKnownHost:(NSString *)host
{
    if (!host) return NO;
    
    return [s_trustedHostList containsObject:host.lowercaseString];
}

+ (void)loadOpenIdConfigurationInfo:(NSURL *)openIdConfigurationEndpoint
                            context:(id<MSIDRequestContext>)context
                    completionBlock:(MSIDOpenIdConfigurationInfoBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    
    __auto_type cacheKey = openIdConfigurationEndpoint.absoluteString.lowercaseString;
    __auto_type metadata = [s_openIdConfigurationCache objectForKey:cacheKey];
    
    if (metadata)
    {
        completionBlock(metadata, nil);
        return;
    }
    
    __auto_type request = [[MSIDOpenIdConfigurationInfoRequest alloc] initWithEndpoint:openIdConfigurationEndpoint];
    [request sendWithBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         if (cacheKey && metadata)
         {
             [s_openIdConfigurationCache setObject:metadata forKey:cacheKey];
         }
         
         completionBlock(metadata, error);
     }];
}

+ (BOOL)isAuthorityFormatValid:(NSURL *)url
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:url.absoluteString])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"'authority' is a required parameter and must not be nil or empty.", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if (![url.scheme isEqualToString:@"https"])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"authority must use HTTPS.", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDAuthority.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDAuthority *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.url.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDAuthority *)authority
{
    if (!authority)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.url && !authority.url) || [self.url isEqual:authority.url];
    return result;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@", self.url.absoluteString];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDAuthority *authority = [[self.class allocWithZone:zone] initWithURL:_url context:nil error:nil];
    authority->_url = [_url copyWithZone:zone];
    
    return authority;
}

@end

