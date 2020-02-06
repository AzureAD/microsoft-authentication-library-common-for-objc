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

#import "MSIDTestAutomationAccount.h"
#import "NSDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"

@interface MSIDTestAutomationAccount()

@property (nonatomic) NSString *objectId;
@property (nonatomic) NSString *userType;
@property (nonatomic) NSString *upn;
@property (nonatomic) NSString *domainUsername;
@property (nonatomic) NSString *keyvaultName;
@property (nonatomic) NSString *homeObjectId;
@property (nonatomic) NSString *targetTenantId;
@property (nonatomic) NSString *homeTenantId;
@property (nonatomic) NSString *tenantName;
@property (nonatomic) NSString *homeTenantName;
@property (nonatomic) BOOL isHomeAccount;

@end

// This is a temporary tenant mapping dictionary until lab adds this to response
static NSDictionary *s_tenantMappingDictionary;

@implementation MSIDTestAutomationAccount

+ (NSDictionary *)tenantMappingDictionary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_tenantMappingDictionary = @{@"msidlab4.com": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                      @"msidlab4.onmicrosoft.com": @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca",
                                      @"msidlab3.com": @"8e44f19d-bbab-4a82-b76b-4cd0a6fbc97a",
                                      @"msidlab3.onmicrosoft.com": @"8e44f19d-bbab-4a82-b76b-4cd0a6fbc97a",
                                      @"msidlab9.com": @"cc0319fa-c0e1-4b2c-ba5f-2cc3b598b01b",
                                      @"msidlab13.com": @"ec825bad-a705-4570-8eca-fe2461368f4e",
                                      @"outlook.com": @"9188040d-6c67-4c5b-b112-36a304b66dad",
                                      @"blfmsidlab1.onmicrosoft.de": @"469fdeb4-d4fd-4fde-991e-308a78e4bea4",
                                      @"msidlab2.onmicrosoft.com": @"6277510b-7d73-41a4-80c7-716caa59a8f3"
        };
    });
    
    return s_tenantMappingDictionary;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    self = [super init];
    
    if (self)
    {
        _objectId = [json msidStringObjectForKey:@"objectId"];
        _userType = [json msidStringObjectForKey:@"userType"];
        
        NSString *homeUPN = [json msidStringObjectForKey:@"homeUPN"];
        NSString *guestUPN = [json msidStringObjectForKey:@"upn"];
        _upn = (homeUPN && ![homeUPN isEqualToString:@"None"]) ? homeUPN : guestUPN;
        _isHomeAccount = ![guestUPN containsString:@"#EXT#"];
        
        NSString *domainUsername = [json msidStringObjectForKey:@"domainUsername"]; // TODO: check name of this attribute
        _domainUsername = (domainUsername && ![domainUsername isEqualToString:@"None"]) ? domainUsername : _upn;
        
        _keyvaultName = [json msidStringObjectForKey:@"credentialVaultKeyName"];
        _keyvaultName = [_keyvaultName stringByReplacingOccurrencesOfString:@"/MSIDLAB/" withString:@"/"]; // TODO: remove me once blackforest query gets fixed!
        _password = [json msidStringObjectForKey:@"password"];
        
        _homeObjectId = _isHomeAccount ? _objectId : [json msidStringObjectForKey:@"homeObjectId"]; // TODO: check name of this attribute
        _targetTenantId = [json msidStringObjectForKey:@"tenantId"]; // TODO: check name of this attribute
        _homeTenantId = [json msidStringObjectForKey:@"homeTenantId"]; // TODO: check name of this attribute
        _tenantName = [guestUPN msidDomainSuffix];
        
        if (!_targetTenantId)
        {
            _targetTenantId = [[self.class tenantMappingDictionary] objectForKey:_tenantName.lowercaseString]; // TODO: remove me!
        }
        
        if (!_homeTenantId)
        {
            _homeTenantId = [[self.class tenantMappingDictionary] objectForKey:[_upn msidDomainSuffix].lowercaseString]; // TODO: remove me!
        }
        
        NSString *homeTenantName = [json msidStringObjectForKey:@"homeDomain"];
        _homeTenantName = homeTenantName ? homeTenantName : _tenantName;
        
        if (!_upn || !_keyvaultName)
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidResponse, @"Missing parameter in application response JSON", nil, nil, nil, nil, nil, YES);
            }
        }
        
        _homeAccountId = [NSString stringWithFormat:@"%@.%@", _homeObjectId, _homeTenantId];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    return nil;
}

@end
