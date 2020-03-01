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

#import "MSIDTestAutomationApplication.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDB2CAuthority.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDJsonSerializer.h"

@interface MSIDTestAutomationApplication()

@property (nonatomic) NSString *appId;
@property (nonatomic) NSString *objectId;
@property (nonatomic) BOOL multiTenantApp;
@property (nonatomic) NSString *labName;
@property (nonatomic) NSOrderedSet *redirectUris;
@property (nonatomic) NSOrderedSet *defaultScopes;
@property (nonatomic) NSDictionary *b2cAuthorities;

@end

@implementation MSIDTestAutomationApplication

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    self = [super init];
    
    if (self)
    {
        _appId = [json msidStringObjectForKey:@"appId"];
        _objectId = [json msidStringObjectForKey:@"objectId"];
        _multiTenantApp = [[json msidStringObjectForKey:@"multiTenantApp"] isEqualToString:@"Yes"];
        _labName = [json msidStringObjectForKey:@"labName"];
        
        NSString *redirectUriString = [json msidStringObjectForKey:@"redirectUri"];
        
        _redirectUris = [redirectUriString msidScopeSet];
        _defaultScopes = [self msidOrderedSetFromCommaSeparatedString:[json msidStringObjectForKey:@"defaultScopes"]];
        _defaultAuthorities = [self msidOrderedSetFromCommaSeparatedString:[json msidStringObjectForKey:@"authority"]];
        
        NSString *b2cAuthoritiesString = [json msidStringObjectForKey:@"b2cAuthorities"];
        NSArray *b2cAuthorities = nil;
        
        if (b2cAuthoritiesString)
        {
            b2cAuthorities = [NSJSONSerialization JSONObjectWithData:[b2cAuthoritiesString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        }

        if (b2cAuthorities && [b2cAuthorities isKindOfClass:[NSArray class]])
        {
            NSMutableDictionary *resultB2CAuthorities = [NSMutableDictionary new];
            
            for (NSDictionary *b2cAuthority in b2cAuthorities)
            {
                NSString *authorityType = [b2cAuthority msidStringObjectForKey:@"AuthorityType"];
                NSString *authority = [b2cAuthority msidStringObjectForKey:@"Authority"];
                
                if (!authorityType || !authority)
                {
                    continue;
                }
                
                resultB2CAuthorities[authorityType] = authority;
            }
            
            _b2cAuthorities = resultB2CAuthorities;
        }
        
        if (!_appId || !_redirectUris.count || !_defaultScopes)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, @"Missing parameter in application response JSON", nil, nil, nil, nil, nil, YES);
            }
        }
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    return nil;
}

- (NSString *)redirectUriWithPrefix:(NSString *)redirectPrefix
{
    for (NSString *uri in _redirectUris)
    {
        if ([uri hasPrefix:redirectPrefix])
        {
            return uri;
        }
    }
    
    return _redirectUris[0];
}

- (NSString *)defaultRedirectUri
{
    return [self redirectUriWithPrefix:self.redirectUriPrefix];
}

#pragma mark - Helpers

- (NSOrderedSet *)msidOrderedSetFromCommaSeparatedString:(NSString *)string
{
    NSCharacterSet *set = [NSCharacterSet punctuationCharacterSet];
    NSMutableOrderedSet<NSString *> *results = [NSMutableOrderedSet<NSString *> new];
    NSArray *parts = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            NSString *resultPart = [part stringByTrimmingCharactersInSet:set].msidTrimmedString.lowercaseString;
            [results addObject:resultPart];
        }
    }
    
    return results;
}

- (NSString *)b2cAuthorityForPolicy:(NSString *)policy tenantId:(NSString *)tenantId
{
    NSString *authority = self.b2cAuthorities[policy];
    
    if (!authority)
    {
        return nil;
    }
    
    MSIDB2CAuthority *msidAuthority = [[MSIDB2CAuthority alloc] initWithURL:[NSURL URLWithString:authority] validateFormat:YES rawTenant:tenantId context:nil error:nil];
    return msidAuthority.url.absoluteString;
}

@end
