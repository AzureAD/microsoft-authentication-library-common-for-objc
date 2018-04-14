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
@property (nonatomic, strong) KeyvaultAuthentication *keyvaultAuthentication;
@property (nonatomic, strong) NSString *apiPath;

@end

@implementation MSIDTestAccountsProvider

- (instancetype)initWithClientCertificatePath:(NSString *)certificatePath
                          certificatePassword:(NSString *)password
                     additionalConfigurations:(NSDictionary *)additionalConfigurations
                                      apiPath:(NSString *)apiPath
{
    self = [super init];

    if (self)
    {
        _cachedConfigurations = [NSMutableDictionary dictionary];
        _keyvaultAuthentication = [[KeyvaultAuthentication alloc] initWithCertPath:certificatePath certPassword:password];
        _apiPath = apiPath;
        [_cachedConfigurations addEntriesFromDictionary:additionalConfigurations];
    }

    return self;
}

- (void)configurationWithRequest:(MSIDTestConfigurationRequest *)request
               completionHandler:(void (^)(MSIDTestConfiguration *configuration))completionHandler
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

          MSIDTestConfiguration *configuration = [[MSIDTestConfiguration alloc] initWithJSONResponseData:data];
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

@end
