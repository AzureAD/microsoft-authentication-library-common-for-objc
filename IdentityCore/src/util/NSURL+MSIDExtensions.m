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

#import "NSURL+MSIDExtensions.h"
#import "NSDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDAadAuthorityCache.h"

const unichar fragmentSeparator = '#';
const unichar queryStringSeparator = '?';

@implementation NSURL (MSIDExtensions)      

// Decodes configuration contained in a URL fragment
- (NSDictionary *)msidFragmentParameters
{
    return [NSDictionary msidURLFormDecode:self.fragment];
}

// Decodes configuration contains in a URL query
- (NSDictionary *)msidQueryParameters
{
    NSURLComponents* components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    
    return [NSDictionary msidURLFormDecode:[components percentEncodedQuery]];
}

- (BOOL)msidIsEquivalentAuthority:(NSURL *)aURL
{
    if (![self msidIsEquivalentAuthorityHost:aURL])
    {
        return NO;
    }
    
    // Check path
    if (self.path || aURL.path)
    {
        if (![self.path isEqual:aURL.path])
        {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)msidIsEquivalentAuthorityHost:(NSURL *)aURL
{
    // Check if equal
    if ([self isEqual:aURL])
    {
        return YES;
    }

    // Check scheme and host
    if (!self.scheme ||
        !aURL.scheme ||
        [self.scheme caseInsensitiveCompare:aURL.scheme] != NSOrderedSame)
    {
        return NO;
    }

    if (!self.host ||
        !aURL.host ||
        [self.host caseInsensitiveCompare:aURL.host] != NSOrderedSame)
    {
        return NO;
    }

    // Check port
    if (self.port || aURL.port)
    {
        if (![self.port isEqual:aURL.port])
        {
            return NO;
        }
    }

    return YES;
}

- (NSString *)msidHostWithPortIfNecessary
{
    NSNumber *port = self.port;
    
    // This assumes we're using https, which is mandatory for all AAD communications.
    if (port == nil || port.intValue == 443)
    {
        return self.host.lowercaseString;
    }
    return [NSString stringWithFormat:@"%@:%d", self.host.lowercaseString, port.intValue];
}

- (NSString *)msidTenant
{
    NSArray *pathComponents = [self pathComponents];
    
    if ([pathComponents count] <= 1)
    {
        return nil;
    }
    
    if ([pathComponents[1] caseInsensitiveCompare:@"tfp"] == NSOrderedSame)
    {
        if ([pathComponents count] < 3)
        {
            return nil;
        }
        
        /* TODO: verify if policy should be also part of the cache key
        Currently, for B2C, there'll be different refresh tokens and access tokens per policy
        This should be controled by different clientInfo returned for different B2C policies
        For AAD it will be:
         
         {
         "uid" :"oid_in_directory"
         "utid" :"tenant id"
         }
         
         For B2C it should be:
         
         {
         "uid" :"oid_in_directory+policy"
         "utid" :"tenant id"
         }
         
         So, there should be already policy identifier as part of the cache key through client info and adding additional policy identifier would mean special client side handling for B2C. Instead, this should be handled by the server side.
         
         */
        
        return pathComponents[2];
    }
    
    return pathComponents[1];
}

+ (NSURL *)msidURLWithEnvironment:(NSString *)environment tenant:(NSString *)tenant
{
    if ([NSString msidIsStringNilOrBlank:environment])
    {
        return nil;
    }

    if ([NSString msidIsStringNilOrBlank:tenant])
    {
        return [self msidURLWithEnvironment:environment];
    }
    
    NSString *authorityString = [NSString stringWithFormat:@"https://%@/%@", environment, tenant];
    return [NSURL URLWithString:authorityString];
}

+ (NSURL *)msidURLWithEnvironment:(NSString *)environment
{
    return [self msidURLWithEnvironment:environment tenant:@"common"];
}

+ (NSURL *)msidAddParameters:(NSDictionary<NSString *, NSString *> *)parameters toUrl:(NSURL *)url
{
    __auto_type urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray new];
    if (urlComponents.queryItems)
    {
        [queryItems addObjectsFromArray:urlComponents.queryItems];
    }
    
    for (id key in parameters)
    {
        id value = parameters[key];
        
        NSAssert([value isKindOfClass:NSString.class], NULL);
        NSAssert([key isKindOfClass:NSString.class], NULL);
        
        if (![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class])
        {
            MSID_LOG_WARN(nil, @"Ignoring key/value.");
            MSID_LOG_WARN_PII(nil, @"Ignoring key: %@ value: %@", key, value);
            continue;
        }
        __auto_type item = [[NSURLQueryItem alloc] initWithName:key value:value];
        [queryItems addObject:item];
    }
    
    urlComponents.queryItems = queryItems;
    
    return urlComponents.URL;
}

@end
