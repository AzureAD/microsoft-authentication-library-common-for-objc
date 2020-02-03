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

@interface MSIDTestAutomationApplication()

@property (nonatomic) NSString *appId;
@property (nonatomic) NSString *objectId;
@property (nonatomic) BOOL multiTenantApp;
@property (nonatomic) NSString *labName;
@property (nonatomic) NSOrderedSet *redirectUris;
@property (nonatomic) NSOrderedSet *defaultScopes;

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
        
        _redirectUris = [[json msidStringObjectForKey:@"redirectUri"] msidScopeSet];
        _defaultScopes = [[json msidStringObjectForKey:@"defaultScopes"] msidScopeSet];
        
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

@end
