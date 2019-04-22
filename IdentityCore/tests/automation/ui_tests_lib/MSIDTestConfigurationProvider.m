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

#import "MSIDTestConfigurationProvider.h"
#import "MSIDAutomation-Swift.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "NSString+MSIDAutomationUtils.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAutomationResetAPIRequest.h"
#import "MSIDClientCredentialHelper.h"

@interface MSIDTestConfigurationProvider()

@property (nonatomic, strong) NSDictionary *appInstallLinks;
@property (nonatomic, strong) NSDictionary *defaultClients;
@property (nonatomic, strong) NSDictionary *defaultEnvironments;
@property (nonatomic, strong) NSDictionary *defaultScopes;
@property (nonatomic, strong) NSDictionary *defaultResources;

@property (nonatomic, readwrite) KeyvaultAuthentication *keyvaultAuthentication;
@property (nonatomic, readwrite) MSIDAutomationUserAPIRequestHandler *userAPIRequestHandler;
@property (nonatomic, readwrite) MSIDAutomationOperationAPIRequestHandler *operationAPIRequestHandler;
@property (nonatomic, readwrite) MSIDAutomationPasswordRequestHandler *passwordRequestHandler;

@end

@implementation MSIDTestConfigurationProvider

- (instancetype)initWithClientCertificateContents:(NSString *)certificate
                              certificatePassword:(NSString *)password
                         additionalConfigurations:(NSDictionary *)additionalConfigurations
                                  appInstallLinks:(NSDictionary *)appInstallLinks
                                      userAPIPath:(NSString *)userAPIPath
                                   defaultClients:(NSDictionary *)defaultClients
                              defaultEnvironments:(NSDictionary *)defaultEnvironments
                            wwEnvironmentIdenfier:(NSString *)wwEnrivonmentIdentifier
                               stressTestInterval:(int)stressTestInterval
                                    defaultScopes:(NSDictionary *)defaultScopes
                                 defaultResources:(NSDictionary *)defaultResources
                                 operationAPIConf:(NSDictionary *)operationAPIConfiguration
{
    self = [super init];

    if (self)
    {
        _keyvaultAuthentication = [[KeyvaultAuthentication alloc] initWithCertContents:certificate certPassword:password];
        _appInstallLinks = appInstallLinks;
        _defaultClients = defaultClients;
        _defaultEnvironments = defaultEnvironments;
        _wwEnvironment = wwEnrivonmentIdentifier;
        _defaultScopes = defaultScopes;
        _defaultResources = defaultResources;
        _stressTestInterval = stressTestInterval;
        
        _userAPIRequestHandler = [[MSIDAutomationUserAPIRequestHandler alloc] initWithAPIPath:userAPIPath
                                                                         cachedConfigurations:additionalConfigurations];
        
        _operationAPIRequestHandler = [[MSIDAutomationOperationAPIRequestHandler alloc] initWithAPIPath:operationAPIConfiguration[@"operation_api_path"]
                                                                              operationAPIConfiguration:operationAPIConfiguration];
        
        _passwordRequestHandler = [MSIDAutomationPasswordRequestHandler new];
    }

    return self;
}

- (instancetype)initWithConfigurationPath:(NSString *)configurationPath
{
    NSData *configurationData = [NSData dataWithContentsOfFile:configurationPath];

    if (!configurationData)
    {
        return nil;
    }

    NSError *jsonError = nil;
    NSDictionary *configurationDictionary = [NSJSONSerialization JSONObjectWithData:configurationData options:0 error:&jsonError];

    if (jsonError || !configurationDictionary)
    {
        return nil;
    }

    NSString *apiPath = configurationDictionary[@"api_path"];
    NSString *certificatePassword = configurationDictionary[@"certificate_password"];
    NSString *encodedCertificate = configurationDictionary[@"certificate_data"];

    NSArray *additionalConfs = configurationDictionary[@"additional_confs"];

    NSMutableDictionary *additionalConfsDictionary = [NSMutableDictionary dictionary];

    for (NSDictionary *additionalConf in additionalConfs)
    {
        NSDictionary *requestDict = additionalConf[@"request"];
        NSDictionary *configurationDict = additionalConf[@"configuration"];

        MSIDAutomationConfigurationRequest *request = [MSIDAutomationConfigurationRequest requestWithDictionary:requestDict];
        MSIDTestAutomationConfiguration *configuration = [[MSIDTestAutomationConfiguration alloc] initWithJSONDictionary:configurationDict];
        additionalConfsDictionary[request] = configuration;
    }

    return [self initWithClientCertificateContents:encodedCertificate
                               certificatePassword:certificatePassword
                          additionalConfigurations:additionalConfsDictionary
                                   appInstallLinks:configurationDictionary[@"app_install_urls"]
                                       userAPIPath:apiPath
                                    defaultClients:configurationDictionary[@"default_clients"]
                               defaultEnvironments:configurationDictionary[@"environments"]
                             wwEnvironmentIdenfier:configurationDictionary[@"default_environment"]
                                stressTestInterval:[configurationDictionary[@"stress_test_interval"] intValue]
                                     defaultScopes:configurationDictionary[@"scopes"]
                                  defaultResources:configurationDictionary[@"resources"]
                                  operationAPIConf:configurationDictionary[@"operation_api_conf"]];

}

- (NSDictionary *)appInstallForConfiguration:(NSString *)appId
{
    return _appInstallLinks[appId];
}

#pragma mark - Default apps

- (MSIDWebviewType)defaultWebviewTypeForPlatform
{
#if TARGET_OS_IPHONE
    return MSIDWebviewTypeDefault;
#else
    return MSIDWebviewTypeWKWebView;
#endif
}

- (MSIDAutomationTestRequest *)defaultConvergedAppRequestWithTenantId:(NSString *)targetTenantId
{
    return [self defaultConvergedAppRequestWithTenantId:targetTenantId];
}

- (MSIDAutomationTestRequest *)defaultConvergedAppRequest:(NSString *)environment
                                           targetTenantId:(NSString *)targetTenantId
{
    return [self defaultConvergedAppRequest:environment targetTenantId:targetTenantId brokerEnabled:NO];
}

- (MSIDAutomationTestRequest *)defaultConvergedAppRequest:(NSString *)environment
                                           targetTenantId:(NSString *)targetTenantId
                                            brokerEnabled:(BOOL)brokerEnabled
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSString *confName = brokerEnabled ? @"brokered_converged" : @"default_converged";
    NSDictionary *defaultConf = self.defaultClients[confName];
    
    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = self.defaultWebviewTypeForPlatform;
        
        NSString *testEnvironment = environment ? environment : self.wwEnvironment;
        
        request.requestScopes = [self scopesForEnvironment:testEnvironment type:@"ms_graph"];
        request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self scopesForEnvironment:testEnvironment type:@"oidc"]];
        request.configurationAuthority = [self defaultAuthorityForIdentifier:testEnvironment];
        request.expectedResultAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
        request.cacheAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
        request.brokerEnabled = brokerEnabled;
    }
    
    return request;
}

- (MSIDAutomationTestRequest *)defaultNonConvergedAppRequest:(NSString *)environment
                                              targetTenantId:(NSString *)targetTenantId
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_nonconverged"];

    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = self.defaultWebviewTypeForPlatform;
        
        NSString *testEnvironment = environment ? environment : self.wwEnvironment;
        
        request.expectedResultAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
        request.cacheAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
    }

    return request;
}

- (MSIDAutomationTestRequest *)defaultAppRequest
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.validateAuthority = YES;
    request.webViewType = self.defaultWebviewTypeForPlatform;
    request.configurationAuthority = [self defaultAuthorityForIdentifier:nil];
    return request;
}

- (MSIDAutomationTestRequest *)defaultInstanceAwareAppRequest
{
    return [self requestWithIdentifier:@"default_sovereign"];
}

- (MSIDAutomationTestRequest *)defaultFociRequestWithoutBroker
{
    return [self requestWithIdentifier:@"default_foci_nobroker"];
}

- (MSIDAutomationTestRequest *)defaultFociRequestWithBroker
{
    return [self requestWithIdentifier:@"default_foci_broker"];
}

- (MSIDAutomationTestRequest *)sharepointFociRequestWithBroker
{
    return [self requestWithIdentifier:@"default_foci_sharepoint"];
}

- (MSIDAutomationTestRequest *)outlookFociRequestWithBroker
{
    return [self requestWithIdentifier:@"default_foci_outlook"];
}

- (MSIDAutomationTestRequest *)requestWithIdentifier:(NSString *)requestIdentifier
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[requestIdentifier];
    
    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = self.defaultWebviewTypeForPlatform;
    }
    
    return request;
}

#pragma mark - Environments

- (NSString *)defaultEnvironmentForIdentifier:(NSString *)environmentIDentifier
{
    return self.defaultEnvironments[environmentIDentifier];
}

- (NSString *)defaultAuthorityForIdentifier:(NSString *)environmentIdentifier
{
    return [self defaultAuthorityForIdentifier:environmentIdentifier tenantId:@"common"];
}

- (NSString *)defaultAuthorityForIdentifier:(NSString *)environmentIdentifier tenantId:(NSString *)tenantId
{
    NSString *identifier = environmentIdentifier ? environmentIdentifier : self.wwEnvironment;
    NSString *environment = [self defaultEnvironmentForIdentifier:identifier];
    
    return [self authorityWithHost:environment tenantId:tenantId];
}

- (NSString *)authorityWithHost:(NSString *)authorityHost tenantId:(NSString *)tenantId
{
    NSString *authority = [NSString stringWithFormat:@"https://%@/%@", authorityHost, (tenantId ? tenantId : @"common")];
    return authority;
}

- (NSString *)b2cAuthorityForIdentifier:(NSString *)environmentIdentifier
                             tenantName:(NSString *)tenantName
                                 policy:(NSString *)policy
{
    NSString *authority = [NSString stringWithFormat:@"https://%@/tfp/%@/%@", [self defaultEnvironmentForIdentifier:environmentIdentifier], tenantName, policy];
    return authority;
}

- (NSString *)scopesForEnvironment:(NSString *)environment type:(NSString *)type
{
    if (!environment)
    {
        environment = self.wwEnvironment;
    }
    
    return self.defaultScopes[type][environment];
}

- (NSString *)oidcScopes
{
    return [self scopesForEnvironment:self.wwEnvironment type:@"oidc"];
}

- (NSString *)resourceForEnvironment:(NSString *)environment type:(NSString *)type
{
    if (!environment)
    {
        environment = self.wwEnvironment;
    }
    
    return self.defaultResources[type][environment];
}

- (MSIDAutomationTestRequest *)fillDefaultRequestParams:(MSIDAutomationTestRequest *)request
                                                 config:(MSIDTestAutomationConfiguration *)configuration
                                                account:(MSIDTestAccount *)account
{
    if (!request.clientId) request.clientId = configuration.clientId;
    if (!request.redirectUri) request.redirectUri = configuration.redirectUri;
    if (!request.requestResource) request.requestResource = configuration.resource;
    if (!request.requestScopes) request.requestScopes = [configuration.resource stringByAppendingString:@"/.default"];
    if (!request.configurationAuthority)
    {
        request.configurationAuthority = [self authorityWithHost:configuration.authorityHost tenantId:account.homeTenantId];
        
    }
    return request;
}

@end
