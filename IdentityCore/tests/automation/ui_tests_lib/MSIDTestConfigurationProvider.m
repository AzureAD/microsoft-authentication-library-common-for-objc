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
#import "MSIDTestResetAPIRequest.h"
#import "MSIDClientCredentialHelper.h"

@interface MSIDTestConfigurationProvider()

@property (nonatomic, strong) NSMutableDictionary *cachedConfigurations;
@property (nonatomic, strong) NSDictionary *appInstallLinks;
@property (nonatomic, strong) KeyvaultAuthentication *keyvaultAuthentication;
@property (nonatomic, strong) NSString *userAPIPath;
@property (nonatomic, strong) NSDictionary *defaultClients;
@property (nonatomic, strong) NSDictionary *defaultEnvironments;
@property (nonatomic, strong) NSDictionary *defaultScopes;
@property (nonatomic, strong) NSDictionary *defaultResources;
@property (nonatomic, strong) NSString *labAPIPassword;
@property (nonatomic, strong) NSString *resetAPIPath;
@property (nonatomic, strong) NSString *resetAPIKeyvaultPath;
@property (nonatomic, strong) NSDictionary *resetAPIConfiguration;

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
                                     resetAPIConf:(NSDictionary *)resetAPIConfiguration
{
    self = [super init];

    if (self)
    {
        _cachedConfigurations = [NSMutableDictionary dictionary];
        _keyvaultAuthentication = [[KeyvaultAuthentication alloc] initWithCertContents:certificate certPassword:password];
        _userAPIPath = userAPIPath;
        [_cachedConfigurations addEntriesFromDictionary:additionalConfigurations];
        _appInstallLinks = appInstallLinks;
        _defaultClients = defaultClients;
        _defaultEnvironments = defaultEnvironments;
        _wwEnvironment = wwEnrivonmentIdentifier;
        _defaultScopes = defaultScopes;
        _defaultResources = defaultResources;
        _stressTestInterval = stressTestInterval;
        _resetAPIConfiguration = resetAPIConfiguration;
        _resetAPIPath = resetAPIConfiguration[@"reset_api_path"];
        _resetAPIKeyvaultPath = resetAPIConfiguration[@"reset_api_keyvault"];
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

        MSIDTestAutomationConfigurationRequest *request = [MSIDTestAutomationConfigurationRequest requestWithDictionary:requestDict];
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
                                      resetAPIConf:configurationDictionary[@"reset_api_conf"]];

}

- (NSDictionary *)appInstallForConfiguration:(NSString *)appId
{
    return _appInstallLinks[appId];
}

- (void)configurationWithRequest:(MSIDTestAutomationConfigurationRequest *)request
               completionHandler:(void (^)(MSIDTestAutomationConfiguration *configuration))completionHandler
{
    if (_cachedConfigurations[request])
    {
        if (completionHandler)
        {
            completionHandler(_cachedConfigurations[request]);
        }

        return;
    }

    NSURL *resultURL = [request requestURLWithAPIPath:self.userAPIPath];

    [[[NSURLSession sharedSession] dataTaskWithURL:resultURL
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
      {
          if (error)
          {
              if (completionHandler)
              {
                  completionHandler(nil);
              }

              return;
          }

          MSIDTestAutomationConfiguration *configuration = [[MSIDTestAutomationConfiguration alloc] initWithJSONResponseData:data];
          self->_cachedConfigurations[request] = configuration;

          if (completionHandler)
          {
              completionHandler(configuration);
          }

      }] resume];
}

- (void)passwordForAccount:(MSIDTestAccount *)account
         completionHandler:(void (^)(NSString *password))completionHandler
{
    if (account.password)
    {
        completionHandler(account.password);
        return;
    }

    NSURL *url = [NSURL URLWithString:account.keyvaultName];
    [Secret getWithUrl:url completion:^(NSError *error, Secret *secret) {

        if (error)
        {
            if (completionHandler)
            {
                completionHandler(nil);
            }

            return;
        }

        if (secret)
        {
            account.password = secret.value;
        }

        if (completionHandler)
        {
            completionHandler(secret.value);
        }
    }];
}

- (void)passwordForLabAPIWithCompletionHandler:(void (^)(NSString *password, NSError *error))completionHandler
{
    if (self.labAPIPassword)
    {
        completionHandler(self.labAPIPassword, nil);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:self.resetAPIKeyvaultPath];
    [Secret getWithUrl:url completion:^(NSError *error, Secret *secret) {
        
        if (error)
        {
            if (completionHandler)
            {
                completionHandler(nil, error);
            }
            
            return;
        }
        
        self.labAPIPassword = secret.value;
        if (completionHandler) completionHandler(secret.value, nil);
    }];
}

- (void)resetPasswordForAccount:(MSIDTestAccount *)account
              completionHandler:(void (^)(BOOL result, NSError *error))completionHandler
{
    MSIDTestResetAPIRequest *request = [MSIDTestResetAPIRequest new];
    request.apiOperation = @"Password";
    request.userUPN = account.account;
    [self callLabAPIWithRequest:request completionHandler:completionHandler];
}

- (void)removeDeviceForAccount:(MSIDTestAccount *)account
                      deviceId:(NSString *)deviceId
             completionHandler:(void (^)(BOOL result, NSError *error))completionHandler
{
    MSIDTestResetAPIRequest *request = [MSIDTestResetAPIRequest new];
    request.apiOperation = @"Device";
    request.userUPN = account.account;
    request.deviceGUID = deviceId;
    [self callLabAPIWithRequest:request completionHandler:completionHandler];
}

- (void)callLabAPIWithRequest:(MSIDTestResetAPIRequest *)request
            completionHandler:(void (^)(BOOL result, NSError *error))completionHandler
{
    [self passwordForLabAPIWithCompletionHandler:^(NSString *password, NSError *error) {
        
        if (!password)
        {
            if (completionHandler)
            {
                completionHandler(NO, error);
            }
            
            return;
        }
        
        [self getAccessTokenAndCallLabAPI:request
                              apiPassword:password
                        completionHandler:completionHandler];
       
    }];
}

- (void)getAccessTokenAndCallLabAPI:(MSIDTestResetAPIRequest *)request
                        apiPassword:(NSString *)apiPassword
                  completionHandler:(void (^)(BOOL result, NSError *error))completionHandler
{
    [MSIDClientCredentialHelper getAccessTokenForAuthority:self.resetAPIConfiguration[@"reset_api_authority"]
                                                  resource:self.resetAPIConfiguration[@"reset_api_resource"]
                                                  clientId:self.resetAPIConfiguration[@"reset_api_client_id"]
                                          clientCredential:self.resetAPIConfiguration[@"reset_api_client_secret"]
                                         completionHandler:^(NSString *accessToken, NSError *error) {
                                             
                                             NSURL *resultURL = [request requestURLWithAPIPath:self.resetAPIPath labPassword:apiPassword];
                                             
                                             NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:resultURL];
                                             NSString *bearerHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
                                             [urlRequest addValue:bearerHeader forHTTPHeaderField:@"Authorization"];
                                             
                                             [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest
                                                                              completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                                               {
                                                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                   
                                                   if (httpResponse.statusCode == 200)
                                                   {
                                                       if (completionHandler)
                                                       {
                                                           completionHandler(YES, nil);
                                                       }
                                                       
                                                       return;
                                                   }
                                                   
                                                   completionHandler(NO, error);
                                               }] resume];
                                         }];
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

- (MSIDAutomationTestRequest *)defaultFociRequestWithoutBroker
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_foci_nobroker"];

    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = self.defaultWebviewTypeForPlatform;
    }

    return request;
}

- (MSIDAutomationTestRequest *)defaultFociRequestWithBroker
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_foci_broker"];

    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = self.defaultWebviewTypeForPlatform;
    }

    return request;
}

- (MSIDAutomationTestRequest *)sharepointFociRequestWithBroker
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_foci_sharepoint"];
    
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
