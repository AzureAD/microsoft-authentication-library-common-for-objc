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

#import "MSIDTestAccountsProvider.h"
#import "MSIDAutomation-Swift.h"

@interface MSIDTestAccountsProvider()

@property (nonatomic, strong) NSMutableDictionary *cachedConfigurations;
@property (nonatomic, strong) NSDictionary *appInstallLinks;
@property (nonatomic, strong) KeyvaultAuthentication *keyvaultAuthentication;
@property (nonatomic, strong) NSString *apiPath;
@property (nonatomic, strong) NSDictionary *defaultClients;
@property (nonatomic, strong) NSDictionary *defaultEnvironments;

@end

@implementation MSIDTestAccountsProvider

- (instancetype)initWithClientCertificateContents:(NSString *)certificate
                              certificatePassword:(NSString *)password
                         additionalConfigurations:(NSDictionary *)additionalConfigurations
                                  appInstallLinks:(NSDictionary *)appInstallLinks
                                          apiPath:(NSString *)apiPath
                                   defaultClients:(NSDictionary *)defaultClients
                              defaultEnvironments:(NSDictionary *)defaultEnvironments
{
    self = [super init];

    if (self)
    {
        _cachedConfigurations = [NSMutableDictionary dictionary];
        _keyvaultAuthentication = [[KeyvaultAuthentication alloc] initWithCertContents:certificate certPassword:password];
        _apiPath = apiPath;
        [_cachedConfigurations addEntriesFromDictionary:additionalConfigurations];
        _appInstallLinks = appInstallLinks;
        _defaultClients = defaultClients;
        _defaultEnvironments = defaultEnvironments;
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
                                           apiPath:apiPath
                                    defaultClients:configurationDictionary[@"environments"]
                               defaultEnvironments:configurationDictionary[@"default_clients"]];

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

    NSURL *resultURL = [request requestURLWithAPIPath:_apiPath];

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

#pragma mark - Default apps

- (MSIDAutomationTestRequest *)defaultConvergedAppRequest
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_converged"];

    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = MSIDWebviewTypeDefault;
    }

    return request;
}

- (MSIDAutomationTestRequest *)defaultNonConvergedAppRequest
{
    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    NSDictionary *defaultConf = self.defaultClients[@"default_nonconverged"];

    if (defaultConf)
    {
        request.clientId = defaultConf[@"client_id"];
        request.redirectUri = defaultConf[@"redirect_uri"];
        request.validateAuthority = YES;
        request.webViewType = MSIDWebviewTypeDefault;
    }

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
        request.webViewType = MSIDWebviewTypeDefault;
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
        request.webViewType = MSIDWebviewTypeDefault;
    }

    return request;
}

#pragma mark - Environments

- (NSString *)defaultEnvironmentForIdentifier:(NSString *)environmentIDentifier
{
    return self.defaultEnvironments[environmentIDentifier];
}

@end
