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
#import "MSIDAutomationConfigurationRequest.h"
#import "MSIDTestAutomationConfiguration.h"
#import "MSIDAutomationTestRequest.h"
#import "MSIDAutomationUserAPIRequestHandler.h"
#import "MSIDAutomationOperationAPIRequestHandler.h"
#import "MSIDAutomationPasswordRequestHandler.h"

@interface MSIDTestConfigurationProvider : NSObject

@property (nonatomic, strong) NSString *wwEnvironment;
@property (nonatomic) int stressTestInterval;

@property (nonatomic, readonly) MSIDAutomationUserAPIRequestHandler *userAPIRequestHandler;
@property (nonatomic, readonly) MSIDAutomationOperationAPIRequestHandler *operationAPIRequestHandler;
@property (nonatomic, readonly) MSIDAutomationPasswordRequestHandler *passwordRequestHandler;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithConfigurationPath:(NSString *)configurationPath;

// Default configuration
- (MSIDAutomationTestRequest *)defaultFociRequestWithBroker;
- (MSIDAutomationTestRequest *)defaultFociRequestWithoutBroker;
- (MSIDAutomationTestRequest *)sharepointFociRequestWithBroker;
- (MSIDAutomationTestRequest *)outlookFociRequestWithBroker;

- (MSIDAutomationTestRequest *)defaultNonConvergedAppRequest:(NSString *)environment
                                              targetTenantId:(NSString *)targetTenantId;

- (MSIDAutomationTestRequest *)defaultConvergedAppRequestWithTenantId:(NSString *)targetTenantId;
- (MSIDAutomationTestRequest *)defaultConvergedAppRequest:(NSString *)environment
                                           targetTenantId:(NSString *)targetTenantId;

- (MSIDAutomationTestRequest *)defaultConvergedAppRequest:(NSString *)environment
                                           targetTenantId:(NSString *)targetTenantId
                                            brokerEnabled:(BOOL)brokerEnabled;

- (MSIDAutomationTestRequest *)defaultAppRequest;
- (MSIDAutomationTestRequest *)defaultInstanceAwareAppRequest;

- (NSDictionary *)appInstallForConfiguration:(NSString *)appId;
// Environment configuration
- (NSString *)defaultEnvironmentForIdentifier:(NSString *)environmentIDentifier;
- (NSString *)defaultAuthorityForIdentifier:(NSString *)environmentIdentifier;
- (NSString *)defaultAuthorityForIdentifier:(NSString *)environmentIdentifier tenantId:(NSString *)tenantId;
- (NSString *)b2cAuthorityForIdentifier:(NSString *)environmentIdentifier
                             tenantName:(NSString *)tenantName
                                 policy:(NSString *)policy;
// Fill default params
- (MSIDAutomationTestRequest *)fillDefaultRequestParams:(MSIDAutomationTestRequest *)request
                                                 config:(MSIDTestAutomationConfiguration *)configuration
                                                account:(MSIDTestAccount *)account;

- (NSString *)oidcScopes;
- (NSString *)scopesForEnvironment:(NSString *)environment type:(NSString *)type;
- (NSString *)resourceForEnvironment:(NSString *)environment type:(NSString *)type;

@end
