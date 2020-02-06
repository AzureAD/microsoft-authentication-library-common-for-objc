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

#import "MSIDTestAutomationAppConfigurationRequest.h"

#pragma mark - MSIDTestAppType
MSIDTestAppType MSIDTestAppTypeCloud = @"cloud";
MSIDTestAppType MSIDTestAppTypeOnPrem = @"onprem";

#pragma mark - MSIDTestAppEnvironment
MSIDTestAppEnvironment MSIDTestAppEnvironmentWWCloud = @"azurecloud";
MSIDTestAppEnvironment MSIDTestAppEnvironmentChinaCloud = @"azurechinacloud";
MSIDTestAppEnvironment MSIDTestAppEnvironmentGermanCloud = @"azuregermanycloud";
MSIDTestAppEnvironment MSIDTestAppEnvironmentUSGovCloud = @"azureusgovernment";
MSIDTestAppEnvironment MSIDTestAppEnvironmentAzureB2C = @"azureb2ccloud";
MSIDTestAppEnvironment MSIDTestAppEnvironmentPPECloud = @"azureppe";

#pragma mark - MSIDTestAppAudience
MSIDTestAppAudience MSIDTestAppAudienceMyOrg = @"azureadmyorg";
MSIDTestAppAudience MSIDTestAppAudienceMultipleOrgs = @"azureadmultipleorgs";
MSIDTestAppAudience MSIDTestAppAudienceMultipleOrgsAndPersonalAccounts = @"azureadandpersonalmicrosoftaccount";

@implementation MSIDTestAutomationAppConfigurationRequest

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _testAppType = MSIDTestAppTypeCloud;
        _testAppEnvironment = MSIDTestAppEnvironmentWWCloud;
        _testAppAudience = MSIDTestAppAudienceMultipleOrgsAndPersonalAccounts;
    }
    
    return self;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    MSIDTestAutomationAppConfigurationRequest *request = [[MSIDTestAutomationAppConfigurationRequest allocWithZone:zone] init];
    request.testAppType = [self.testAppType copyWithZone:zone];
    request.testAppEnvironment = [self.testAppEnvironment copyWithZone:zone];
    request.testAppAudience = [self.testAppAudience copyWithZone:zone];
    return request;
}

#pragma mark - Base request

- (NSString *)requestOperationPath
{
    return @"App";
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSMutableArray *queryItems = [NSMutableArray array];
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"apptype" value:self.testAppType]];
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"azureenvironment" value:self.testAppEnvironment]];
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"signinaudience" value:self.testAppAudience]];

    for (NSString *queryKey in [self.additionalQueryParameters allKeys])
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:queryKey value:self.additionalQueryParameters[queryKey]]];
    }

    return queryItems;
}

- (NSString *)keyvaultNameKey
{
    return nil;
}

- (BOOL)shouldCacheResponse
{
    return YES;
}

+ (MSIDTestAutomationAppConfigurationRequest *)requestWithDictionary:(NSDictionary *)dictionary
{
    MSIDTestAutomationAppConfigurationRequest *request = [MSIDTestAutomationAppConfigurationRequest new];
    request.testAppType = dictionary[@"test_app_type"];
    request.testAppEnvironment = dictionary[@"test_app_environment"];
    request.testAppAudience = dictionary[@"test_app_audience"];
    return request;
}

@end
