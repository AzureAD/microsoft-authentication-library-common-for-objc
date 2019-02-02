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

#import "MSIDTestAutomationConfiguration.h"
#import "MSIDAutomationTestRequest.h"

@implementation MSIDTestAccount

- (BOOL)isEqualToTestAccount:(MSIDTestAccount *)accountInfo
{
    if (!accountInfo)
    {
        return NO;
    }

    BOOL result = YES;
    result &= (!self.account && !accountInfo.account) || [self.account isEqualToString:accountInfo.account];
    result &= (!self.username && !accountInfo.username) || [self.username isEqualToString:accountInfo.username];
    result &= (!self.keyvaultName && !accountInfo.keyvaultName) || [self.keyvaultName isEqualToString:accountInfo.keyvaultName];
    result &= (!self.homeTenantId && !accountInfo.homeTenantId) || [self.homeTenantId isEqualToString:accountInfo.homeTenantId];
    result &= (!self.homeObjectId && !accountInfo.homeObjectId) || [self.homeObjectId isEqualToString:accountInfo.homeObjectId];
    result &= (!self.targetTenantId && !accountInfo.targetTenantId) || [self.targetTenantId isEqualToString:accountInfo.targetTenantId];

    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDTestAccount.class])
    {
        return NO;
    }

    return [self isEqualToTestAccount:(MSIDTestAccount *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.account.hash;
    hash ^= self.username.hash;
    hash ^= self.keyvaultName.hash;
    hash ^= self.homeTenantId.hash;
    hash ^= self.targetTenantId.hash;
    hash ^= self.homeObjectId.hash;
    hash ^= self.tenantName.hash;

    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MSIDTestAccount *account = [[MSIDTestAccount allocWithZone:zone] init];
    account.username = [self.username copyWithZone:zone];
    account.account = [self.account copyWithZone:zone];
    account.password = [self.password copyWithZone:zone];
    account.keyvaultName = [self.keyvaultName copyWithZone:zone];
    account.homeTenantId = [self.homeTenantId copyWithZone:zone];
    account.targetTenantId = [self.targetTenantId copyWithZone:zone];
    account.homeObjectId = [self.homeObjectId copyWithZone:zone];
    account.tenantName = [self.tenantName copyWithZone:zone];
    account.labName = [self.labName copyWithZone:zone];
    return account;
}

- (instancetype)initWithJSONResponse:(NSDictionary *)response
{
    self = [super init];

    if (self)
    {
        NSString *homeUPN = response[@"homeUPN"];

        if (homeUPN && [homeUPN isKindOfClass:[NSString class]])
        {
            _username = homeUPN;
        }
        else
        {
            _username = response[@"upn"];
        }

        _keyvaultName = response[@"credentialVaultKeyName"];
        _labName = [_keyvaultName lastPathComponent];

        _account = _username;

        NSString *federationProvider = response[@"federationProvider"];

        // TODO: server should return a username instead
        if (federationProvider && ([federationProvider isEqualToString:@"Shibboleth"]
                                   || [federationProvider containsString:@"PingFederate"]))
        {
            _username = response[@"DomainAccount"];
        }

        // TODO: lab doesn't return home tenant ID for non guest users...
        _homeTenantId = [response[@"hometenantId"] length] ? response[@"hometenantId"] : response[@"tenantId"];
        _targetTenantId = response[@"tenantId"];
        _homeObjectId = response[@"objectId"];
        _password = response[@"password"];
        _tenantName = response[@"tenantName"];
    }

    return self;
}

- (NSString *)passwordFromData:(NSData *)responseData
{
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];

    if (!responseDict)
    {
        return nil;
    }

    return responseDict[@"Value"];
}

- (NSString *)homeAccountId
{
    return [NSString stringWithFormat:@"%@.%@", self.homeObjectId, [self.homeTenantId length] ? self.homeTenantId : self.targetTenantId];
}

@end

@interface MSIDTestAutomationConfiguration()

@property (nonatomic) NSArray *registeredRedirectURIs;

@end

@implementation MSIDTestAutomationConfiguration

- (BOOL)isEqualToConfiguration:(MSIDTestAutomationConfiguration *)configuration
{
    if (!configuration)
    {
        return NO;
    }

    BOOL result = YES;
    result &= (!self.authority && !configuration.authority) || [self.authority isEqualToString:configuration.authority];
    result &= (!self.clientId && !configuration.clientId) || [self.clientId isEqualToString:configuration.clientId];
    result &= (!self.redirectUri && !configuration.redirectUri) || [self.redirectUri isEqualToString:configuration.redirectUri];
    result &= (!self.resource && !configuration.resource) || [self.resource isEqualToString:configuration.resource];
    result &= (!self.accounts && !configuration.accounts) || [self.accounts isEqualToArray:configuration.accounts];

    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDTestAutomationConfiguration.class])
    {
        return NO;
    }

    return [self isEqualToConfiguration:(MSIDTestAutomationConfiguration *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.authority.hash;
    hash ^= self.clientId.hash;
    hash ^= self.redirectUri.hash;
    hash ^= self.resource.hash;
    hash ^= self.accounts.hash;

    return hash;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)responseDict
{
    self = [super init];

    if (self)
    {
        _clientId = responseDict[@"AppID"];
        _registeredRedirectURIs = responseDict[@"RedirectURI"];
        _redirectUri = [self redirectUriWithPrefix:self.class.defaultRegisteredScheme];

        // TODO: why are there multiple resources?
        _resource = responseDict[@"Resource_ids"][0];

        _authority = responseDict[@"Authority"][0];
        
        NSURL *authorityURL = [NSURL URLWithString:_authority];
        _authorityHost = [authorityURL msidHostWithPortIfNecessary];

        NSMutableArray *accounts = [NSMutableArray array];

        if ([responseDict[@"Users"] isKindOfClass:[NSDictionary class]])
        {
            MSIDTestAccount *account = [[MSIDTestAccount alloc] initWithJSONResponse:responseDict[@"Users"]];

            if (account)
            {
                [accounts addObject:account];
            }
        }
        else if ([responseDict[@"Users"] isKindOfClass:[NSArray class]])
        {
            for (NSDictionary *accountDict in responseDict[@"Users"])
            {
                MSIDTestAccount *account = [[MSIDTestAccount alloc] initWithJSONResponse:accountDict];

                if (account)
                {
                    [accounts addObject:account];
                }
            }
        }

        _accounts = accounts;
        _policies = responseDict[@"Policy"];
    }

    return self;
}

- (instancetype)initWithJSONResponseData:(NSData *)response
{
    id responseObj = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];

    if (!responseObj)
    {
        return nil;
    }

    NSDictionary *responseDict = nil;

    // TODO: fix this hack on the server side!
    if ([responseObj isKindOfClass:[NSArray class]])
    {
        NSArray *responseArray = (NSArray *) responseObj;
        responseDict = responseArray[0];
    }
    else if ([responseObj isKindOfClass:[NSDictionary class]])
    {
        responseDict = responseObj;
    }

    return [self initWithJSONDictionary:responseDict];
}

- (NSString *)redirectUriWithPrefix:(NSString *)redirectPrefix
{
    for (NSString *uri in _registeredRedirectURIs)
    {
        if ([uri hasPrefix:redirectPrefix])
        {
            return uri;
        }
    }
    
    return _registeredRedirectURIs[0];
}

- (void)addAdditionalAccount:(MSIDTestAccount *)additionalAccount
{
    NSMutableArray *accounts = [self.accounts mutableCopy];
    [accounts addObject:additionalAccount];
    self.accounts = accounts;
}

- (NSString *)authorityWithTenantId:(NSString *)tenantId
{
    return [NSString stringWithFormat:@"https://%@/%@", _authorityHost, tenantId];
}

#pragma mark - Class properties

static NSString *s_defaultAppScheme = nil;

+ (void)setDefaultRegisteredScheme:(NSString *)defaultRegisteredScheme
{
    s_defaultAppScheme = defaultRegisteredScheme;
}

+ (NSString *)defaultRegisteredScheme
{
    return s_defaultAppScheme;
}

@end
