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

// Decodes parameters contained in a URL fragment
- (NSDictionary *)msidFragmentParameters
{
    return [NSDictionary msidURLFormDecode:self.fragment];
}

// Decodes parameters contains in a URL query
- (NSDictionary *)msidQueryParameters
{
    NSURLComponents* components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    
    return [NSDictionary msidURLFormDecode:[components percentEncodedQuery]];
}

- (BOOL)msidIsEquivalentAuthority:(NSURL *)aURL
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

- (BOOL)msidIsEquivalentWithAnyAlias:(NSArray<NSURL *> *)aliases
{
    if (!aliases)
    {
        return NO;
    }
        
    for (NSURL *alias in aliases)
    {
        if ([self msidIsEquivalentAuthority:alias])
        {
            return YES;
        }
    }
    return NO;
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

// TODO: add unit tests
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
        // TODO: verify if policy should be also part of the cache key
        return pathComponents[2];
    }
    
    return pathComponents[1];
}

@end
