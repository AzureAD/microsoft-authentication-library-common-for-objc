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
        s_tenantMappingDictionary = @{@"outlook.com": @"9188040d-6c67-4c5b-b112-36a304b66dad"};
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
        
        NSString *domainUsername = [json msidStringObjectForKey:@"domainAccount"];
        _domainUsername = (domainUsername && ![domainUsername isEqualToString:@"None"] && ![NSString msidIsStringNilOrBlank:domainUsername]) ? domainUsername : _upn;
        
        _keyvaultName = [json msidStringObjectForKey:@"credentialVaultKeyName"];
        _password = [json msidStringObjectForKey:@"password"];
        
        _homeObjectId = _isHomeAccount ? _objectId : [json msidStringObjectForKey:@"homeObjectId"];
        _targetTenantId = [json msidStringObjectForKey:@"tenantID"];
        
        if (!_targetTenantId)
        {
            _targetTenantId = [json msidStringObjectForKey:@"tenantId"];
        }
        
        _tenantName = [guestUPN msidDomainSuffix];
        
        // TODO: remove this hack after MSA migration on lab side is complete!
        NSString *mappedTenantId = [[self.class tenantMappingDictionary] objectForKey:_tenantName.lowercaseString];
        
        if (mappedTenantId)
        {
            _targetTenantId = mappedTenantId;
        }
        
        NSString *homeTenantId = [json msidStringObjectForKey:@"homeTenantID"];
        _homeTenantId = [NSString msidIsStringNilOrBlank:homeTenantId] ? _targetTenantId : homeTenantId;
        
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
