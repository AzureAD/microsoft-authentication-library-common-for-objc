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
#import "MSIDTestAutomationAppConfigurationRequest.h"
#import "MSIDTestAutomationApplication.h"
#import "MSIDAutomationOperationAPIInMemoryCacheHandler.h"
#import "MSIDTestAutomationAccountConfigurationRequest.h"

@interface MSIDTestConfigurationProvider()

@property (nonatomic, strong) NSDictionary *appInstallLinks;
@property (nonatomic, strong) NSDictionary *defaultEnvironments;
@property (nonatomic, strong) NSDictionary *defaultScopes;
@property (nonatomic, strong) NSDictionary *defaultResources;

@property (nonatomic, readwrite) KeyvaultAuthentication *keyvaultAuthentication;
@property (nonatomic, readwrite) MSIDAutomationOperationAPIRequestHandler *operationAPIRequestHandler;
@property (nonatomic, readwrite) MSIDAutomationPasswordRequestHandler *passwordRequestHandler;

@end

@implementation MSIDTestConfigurationProvider

- (instancetype)initWithClientCertificateContents:(NSString *)certificate
                              certificatePassword:(NSString *)password
                         additionalConfigurations:(NSDictionary *)additionalConfigurations
                                  appInstallLinks:(NSDictionary *)appInstallLinks
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
        _defaultEnvironments = defaultEnvironments;
        _wwEnvironment = wwEnrivonmentIdentifier;
        _defaultScopes = defaultScopes;
        _defaultResources = defaultResources;
        _stressTestInterval = stressTestInterval;
        
        MSIDAutomationOperationAPIInMemoryCacheHandler *cacheHandler = [[MSIDAutomationOperationAPIInMemoryCacheHandler alloc] initWithDictionary:additionalConfigurations];
        
        _operationAPIRequestHandler = [[MSIDAutomationOperationAPIRequestHandler alloc] initWithAPIPath:operationAPIConfiguration[@"operation_api_path"]
                                                                              operationAPIConfiguration:operationAPIConfiguration];
        _operationAPIRequestHandler.apiCacheHandler = cacheHandler;
        
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

    NSString *certificatePassword = configurationDictionary[@"certificate_password"];
    NSString *encodedCertificate = configurationDictionary[@"certificate_data"];

    NSMutableDictionary *additionalConfsDictionary = [NSMutableDictionary dictionary];
    
    NSArray *additionalAppConfs = configurationDictionary[@"additional_app_confs"];
    
    for (NSDictionary *additionalConf in additionalAppConfs)
    {
        NSDictionary *requestDict = additionalConf[@"request"];
        NSDictionary *configurationDict = additionalConf[@"response"];

        MSIDAutomationBaseApiRequest *request = [MSIDTestAutomationAppConfigurationRequest requestWithDictionary:requestDict];
        MSIDTestAutomationApplication *appConf = [[MSIDTestAutomationApplication alloc] initWithJSONDictionary:configurationDict error:nil];
        additionalConfsDictionary[request] = @[appConf];
    }
    
    NSArray *additionalAccountConfs = configurationDictionary[@"additional_account_confs"];
    
    for (NSDictionary *additionalConf in additionalAccountConfs)
    {
        NSDictionary *requestDict = additionalConf[@"request"];
        NSDictionary *configurationDict = additionalConf[@"response"];

        MSIDAutomationBaseApiRequest *request = [MSIDTestAutomationAccountConfigurationRequest requestWithDictionary:requestDict];
        MSIDTestAutomationAccount *accountConf = [[MSIDTestAutomationAccount alloc] initWithJSONDictionary:configurationDict error:nil];
        additionalConfsDictionary[request] = @[accountConf];
    }
    
    return [self initWithClientCertificateContents:encodedCertificate
                               certificatePassword:certificatePassword
                          additionalConfigurations:additionalConfsDictionary
                                   appInstallLinks:configurationDictionary[@"app_install_urls"]
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

- (MSIDAutomationTestRequest *)defaultAppRequest:(NSString *)environment
                                  targetTenantId:(NSString *)targetTenantId
                                 scopesSupported:(BOOL)scopesSupported
{
    return [self defaultAppRequest:environment targetTenantId:targetTenantId brokerEnabled:NO scopesSupported:scopesSupported];
}

- (MSIDAutomationTestRequest *)defaultAppRequest:(NSString *)environment
                                  targetTenantId:(NSString *)targetTenantId
                                   brokerEnabled:(BOOL)brokerEnabled
                                 scopesSupported:(BOOL)scopesSupported
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.validateAuthority = YES;
    request.webViewType = self.defaultWebviewTypeForPlatform;
    
    NSString *testEnvironment = environment ? environment : self.wwEnvironment;
    
    if (scopesSupported)
    {
        request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self scopesForEnvironment:testEnvironment type:@"oidc"]];
        request.requestScopes = [self scopesForEnvironment:testEnvironment type:@"ms_graph"];
        
        // TODO: use supportsTenantSpecificResultAuthority
        request.expectedResultAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
    }
    else
    {
        request.requestResource = [self resourceForEnvironment:testEnvironment type:@"ms_graph"];
        
        request.expectedResultScopes = request.requestResource;
        request.requestScopes = [NSString stringWithFormat:@"%@/.default", request.requestResource];
        
        // TODO: use supportsTenantSpecificResultAuthority
        request.expectedResultAuthority = [self defaultAuthorityForIdentifier:testEnvironment];
    }
    
    request.configurationAuthority = [self defaultAuthorityForIdentifier:testEnvironment];
    
    request.cacheAuthority = [self defaultAuthorityForIdentifier:testEnvironment tenantId:targetTenantId];
    request.brokerEnabled = brokerEnabled;
    
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
                                              appConfig:(MSIDTestAutomationApplication *)appConfig
{
    if (!request.clientId) request.clientId = appConfig.appId;
    if (!request.redirectUri) request.redirectUri = appConfig.defaultRedirectUri;
    return request;
}

- (void)configureResourceInRequest:(MSIDAutomationTestRequest *)request
               forEnvironment:(NSString *)environment
                                     type:(NSString *)type
                            suportsScopes:(BOOL)suportsScopes
{
    NSString *resource = [self resourceForEnvironment:environment type:type];
    request.requestScopes = [resource stringByAppendingString:@"/.default"];
    request.requestResource = [self resourceForEnvironment:environment type:type];;
    
    if (suportsScopes)
    {
        request.expectedResultScopes = request.requestScopes;
    }
    else
    {
        request.expectedResultScopes = request.requestResource;
    }
}

- (void)configureScopesInRequest:(MSIDAutomationTestRequest *)request
               forEnvironment:(NSString *)environment
                      scopesType:(NSString *)scopesType
                    resourceType:(NSString *)resourceType
                   suportsScopes:(BOOL)suportsScopes
{
    if (suportsScopes)
    {
        request.requestScopes = [self scopesForEnvironment:environment type:scopesType];
        
        if ([scopesType isEqualToString:@"ms_graph"] || [scopesType isEqualToString:@"ms_graph_static"])
        {
            request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.oidcScopes];
        }
        else
        {
            request.expectedResultScopes = request.requestScopes;
        }
    }
    else
    {
        request.requestResource = [self resourceForEnvironment:environment type:resourceType];
        request.requestScopes = [request.requestResource stringByAppendingString:@"/.default"];
        request.expectedResultScopes = request.requestResource;
    }
}

- (void)configureAuthorityInRequest:(MSIDAutomationTestRequest *)request
                     forEnvironment:(NSString *)environment
                           tenantId:(NSString *)tenantId
                    accountTenantId:(NSString *)accountTenantId
supportsTenantSpecificResultAuthority:(BOOL)supportsTenantSpecificResultAuthority
{
    request.configurationAuthority = [self defaultAuthorityForIdentifier:environment tenantId:tenantId];
    
    if (supportsTenantSpecificResultAuthority)
    {
        request.expectedResultAuthority = [self defaultAuthorityForIdentifier:environment tenantId:accountTenantId];
    }
    else
    {
        request.expectedResultAuthority = request.configurationAuthority;
    }
}

@end
