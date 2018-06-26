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

#import <Foundation/Foundation.h>
#import "MSIDTestAutomationConfigurationRequest.h"
#import "MSIDTestAutomationConfiguration.h"

@interface MSIDTestAccountsProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*
This information would normally come from a configuration file.
@param certificate Base64 encoded client certificate to authenticate with keyvault
@param password Certificate password in case it's password protected
@param additionalConfigurations Additional local configurations that should override server configurations
@param appInstallLinks Information necessary to install additional apps to run multi-app tests, e.g.

 "msal": {
    "install_url": "https://...",
    "app_bundle_id": "com.microsoft.MSALTestApp",
    "app_name": "MSAL Test App"
 },
 "broker": {
    "install_url": "https://...",
    "app_bundle_id": "com.microsoft.broker",
    "app_name": "Broker"
 }
@param apiPath Lab API path
 */

- (instancetype)initWithClientCertificateContents:(NSString *)certificate
                              certificatePassword:(NSString *)password
                         additionalConfigurations:(NSDictionary *)additionalConfigurations
                                  appInstallLinks:(NSDictionary *)appInstallLinks
                                          apiPath:(NSString *)apiPath;

- (instancetype)initWithConfigurationPath:(NSString *)configurationPath;

- (void)configurationWithRequest:(MSIDTestAutomationConfigurationRequest *)request
               completionHandler:(void (^)(MSIDTestAutomationConfiguration *configuration))completionHandler;

- (void)passwordForAccount:(MSIDTestAccount *)account
         completionHandler:(void (^)(NSString *password))completionHandler;

- (NSDictionary *)appInstallForConfiguration:(NSString *)appId;

@end
