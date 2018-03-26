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

@implementation MSIDAuthority

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

@end
