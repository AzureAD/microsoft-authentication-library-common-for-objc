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

#import "MSIDAutomationBaseApiRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString *MSIDTestAccountType;
extern MSIDTestAccountType MSIDTestAccountTypeCloud;
extern MSIDTestAccountType MSIDTestAccountTypeFederated;
extern MSIDTestAccountType MSIDTestAccountTypeOnPrem;
extern MSIDTestAccountType MSIDTestAccountTypeGuest;
extern MSIDTestAccountType MSIDTestAccountTypeMSA;
extern MSIDTestAccountType MSIDTestAccountTypeB2C;

typedef NSString *MSIDTestAccountMFAType;
extern MSIDTestAccountMFAType MSIDTestAccountMFATypeNone;
extern MSIDTestAccountMFAType MSIDTestAccountMFATypeManual;
extern MSIDTestAccountMFAType MSIDTestAccountMFATypeAuto;
extern MSIDTestAccountMFAType MSIDTestAccountMFAOnSPO;

typedef NSString *MSIDTestAccountProtectionPolicyType;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeNone;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeCA;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAM;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMDM;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAMCA;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMAMCASPO;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeTrueMAMCA;
extern MSIDTestAccountProtectionPolicyType MSIDTestAccountProtectionPolicyTypeMDMCA;

typedef NSString *MSIDTestAccountB2CProviderType;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeNone;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeAmazon;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeFacebook;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeGoogle;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeLocal;
extern MSIDTestAccountB2CProviderType MSIDTestAccountB2CProviderTypeMSA;

typedef NSString *MSIDTestAccountFederationProviderType;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeNone;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV2;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV3;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFSV4;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeADFS2019;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypePing;
extern MSIDTestAccountFederationProviderType MSIDTestAccountFederationProviderTypeShibboleth;

typedef NSString *MSIDTestAccountEnvironmentType;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeWWCloud;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeChinaCloud;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeGermanCloud;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeUSGovCloud;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypePPE;
extern MSIDTestAccountEnvironmentType MSIDTestAccountEnvironmentTypeB2C;


@interface MSIDTestAutomationAccountConfigurationRequest : MSIDAutomationBaseApiRequest

@property (nonatomic) MSIDTestAccountMFAType mfaType;
@property (nonatomic) MSIDTestAccountType accountType;
@property (nonatomic) MSIDTestAccountProtectionPolicyType protectionPolicyType;
@property (nonatomic) MSIDTestAccountB2CProviderType b2cProviderType;
@property (nonatomic) MSIDTestAccountFederationProviderType federationProviderType;
@property (nonatomic) MSIDTestAccountEnvironmentType environmentType;
@property (nonatomic) NSDictionary *additionalQueryParameters;

@end

NS_ASSUME_NONNULL_END
