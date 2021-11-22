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

#import "MSIDTestAutomationAccountConfigurationRequest.h"

#pragma mark - MSIDTestAccountType
MSIDTestAccountType MSIDTestAccountTypeCloud = @"cloud";
MSIDTestAccountType MSIDTestAccountTypeFederated = @"federated";
MSIDTestAccountType MSIDTestAccountTypeOnPrem = @"onprem";
MSIDTestAccountType MSIDTestAccountTypeGuest = @"guest";
MSIDTestAccountType MSIDTestAccountTypeMSA = @"msa";
MSIDTestAccountType MSIDTestAccountTypeB2C = @"b2c";

#pragma mark - MSIDTestAccountMFAType;
MSIDTestAccountMFAType MSIDTestAccountMFATypeNone = @"none";
MSIDTestAccountMFAType MSIDTestAccountMFATypeManual = @"mfaonall";
MSIDTestAccountMFAType MSIDTestAccountMFATypeAuto = @"automfaonall";
MSIDTestAccountMFAType MSIDTestAccountMFAOnSPO = @"mfaonspo";

#pragma mark - MSIDTestAccountProtectionPolicyType;
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeNone = @"none";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeCA = @"ca";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAM = @"mam";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMDM = @"mdm";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAMCA = @"mamca";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAMCASPO = @"mamspo";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeTrueMAMCA = @"truemamca";
MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMDMCA = @"mdmca";

#pragma mark - MSIDTestAccountB2CProviderType;
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeNone = @"none";
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeAmazon = @"amazon";
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeFacebook = @"facebook";
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeGoogle = @"google";
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeLocal = @"local";
MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeMSA = @"microsoft";

#pragma mark - MSIDTestAccountFederationProviderType;
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeNone = @"none";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV2 = @"adfsv2";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV3 = @"adfsv3";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV4 = @"adfsv4";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFS2019 = @"adfsv2019";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypePing = @"ping";
MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeShibboleth = @"shibboleth";

#pragma mark - MSIDTestAccountEnvironmentType;
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeWWCloud = @"azurecloud";
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeChinaCloud = @"azurechinacloud";
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeGermanCloud = @"azuregermanycloud";
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeUSGovCloud = @"azureusgovernment";
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypePPE = @"azureppe";
MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeB2C = @"azureb2ccloud";

#pragma mark - MSIDTestAccountTypeUserRoleType
MSIDTestAccountTypeUserRoleType MSIDTestAccountTypeUserRoleTypeCloudAdministrator = @"CloudDeviceAdministrator";

@implementation MSIDTestAutomationAccountConfigurationRequest

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _accountType = MSIDTestAccountTypeCloud;
        _protectionPolicyType = MSIDTestAccountProtectionPolicyTypeNone;
        _federationProviderType = MSIDTestAccountFederationProviderTypeNone;
        _mfaType = MSIDTestAccountMFATypeNone;
        _environmentType = MSIDTestAccountEnvironmentTypeWWCloud;
    }
    
    return self;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    MSIDTestAutomationAccountConfigurationRequest *request = [[MSIDTestAutomationAccountConfigurationRequest allocWithZone:zone] init];
    request.mfaType = [self.mfaType copyWithZone:zone];
    request.accountType = [self.accountType copyWithZone:zone];
    request.protectionPolicyType = [self.protectionPolicyType copyWithZone:zone];
    request.b2cProviderType = [self.b2cProviderType copyWithZone:zone];
    request.federationProviderType = [self.federationProviderType copyWithZone:zone];
    request.environmentType = [self.environmentType copyWithZone:zone];
    request.userRole = [self.userRole copyWithZone:zone];
    return request;
}

#pragma mark - Base request

- (NSString *)requestOperationPath
{
    return @"User";
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSMutableArray *queryItems = [NSMutableArray array];
    
    if (self.mfaType) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"mfa" value:self.mfaType]];
    if (self.accountType) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"usertype" value:self.accountType]];
    if (self.protectionPolicyType) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"protectionpolicy" value:self.protectionPolicyType]];
    if (self.b2cProviderType) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"b2cprovider" value:self.b2cProviderType]];
    if (self.federationProviderType && self.federationProviderType != MSIDTestAccountFederationProviderTypeNone) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"federationprovider" value:self.federationProviderType]];
    if (self.environmentType) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"azureenvironment" value:self.environmentType]];
    if (self.userRole) [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"userrole" value:self.userRole]];
    
    
    for (NSString *queryKey in [self.additionalQueryParameters allKeys])
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:queryKey value:self.additionalQueryParameters[queryKey]]];
    }

    return queryItems;
}

- (BOOL)shouldCacheResponse
{
    return YES;
}

+ (MSIDTestAutomationAccountConfigurationRequest *)requestWithDictionary:(NSDictionary *)dictionary
{
    MSIDTestAutomationAccountConfigurationRequest *request = [MSIDTestAutomationAccountConfigurationRequest new];
    request.mfaType = dictionary[@"mfa"];
    request.accountType = dictionary[@"usertype"];
    request.protectionPolicyType = dictionary[@"protectionpolicy"];
    request.b2cProviderType = dictionary[@"b2cprovider"];
    request.federationProviderType = dictionary[@"federationprovider"];
    request.environmentType = dictionary[@"azureenvironment"];
    request.userRole = dictionary[@"userrole"];
    return request;
}

@end
