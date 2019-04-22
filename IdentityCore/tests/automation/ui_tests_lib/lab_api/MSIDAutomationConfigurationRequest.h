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

/*! MSIDTestAccountProvider is the federation provider of the AMSID account, or none in the case of
 entirely in cloud accounts like WW and Black Forest. They are mutally exclusive of each other. */
typedef NSString *MSIDTestAccountProvider;
/*! B2C is a Microsoft B2C account */
extern MSIDTestAccountProvider MSIDTestAccountProviderB2C;
/*! B2C configured to support MSA accounts */
extern MSIDTestAccountProvider MSIDTestAccountProviderB2CMSA;
/*! WW is a world wide entirely on-cloud account */
extern MSIDTestAccountProvider MSIDTestAccountProviderWW;
/*! Black Forest is an AMSID account hosted in the Black Forest sovereign cloud (.de) */
extern MSIDTestAccountProvider MSIDTestAccountProviderBlackForest;
/*! Us gov is an MSID account hosted in the US government sovereign cloud (.us) */
extern MSIDTestAccountProvider MSIDTestAccountProviderAzureUSGov;
/*! Mooncake is an MSID account hosted in the China sovereign cloud (.cn) */
extern MSIDTestAccountProvider MSIDTestAccountProviderChinaCloud;
/*! MSA is a Microsoft consumer account */
extern MSIDTestAccountProvider MSIDTestAccountProviderMSA;
/*! A WW account federated using MSIDFSv2 (these accounts can also be used for on-prem tests) */
extern MSIDTestAccountProvider MSIDTestAccountProviderADfsv2;
/*! A WW account federated using MSIDFSv3 (these accounts can also be used for on-prem tests) */
extern MSIDTestAccountProvider MSIDTestAccountProviderADfsv3;
/*! A WW account federated using MSIDFSv4 (these accounts can also be used for on-prem tests) */
extern MSIDTestAccountProvider MSIDTestAccountProviderADfsv4;
/*! A WW account federated using Shibboleth */
extern MSIDTestAccountProvider MSIDTestAccountProviderShibboleth;
/*! A WW account federated using Ping */
extern MSIDTestAccountProvider MSIDTestAccountProviderPing;
/*! A NTLM account using test adfs environment */
extern MSIDTestAccountProvider MSIDTestAccountProviderNTLM;

/*! MSIDTestAccountFeatures are things that can be enabled for a given account, multiple of these can
 be enabled at a time */
typedef NSString *MSIDTestAccountFeature;
/*! The account has a license and is capable of MDM-ing a device. */
extern MSIDTestAccountFeature MSIDTestAccountFeatureMDMEnabled;
/*! The account has a license to be able to use MAM features */
extern MSIDTestAccountFeature MSIDTestAccountFeatureMAMEnabled;
/*! The account has a license to be able to use advanced Intune app protection features */
extern MSIDTestAccountFeature MSIDTestAccountFeatureTrueMAMEnabled;
/*! The account is capable of registering a device so that it can respond to device auth challenges. */
extern MSIDTestAccountFeature MSIDTestAccountFeatureDeviceAuth;
/*! The account is MFA enabled */
extern MSIDTestAccountFeature MSIDTestAccountFeatureMFAEnabled;
/*! The account is a guest user */
extern MSIDTestAccountFeature MSIDTestAccountFeatureGuestUser;
/*! The account is a guest user */
extern MSIDTestAccountFeature MSIDTestAccountFeatureNTLM;
/*! The account supports optional claims */
extern MSIDTestAccountFeature MSIDTestAccountMAMCAClaims;
/*! The account supports optional claims */
extern MSIDTestAccountFeature MSIDTestAccountMFAClaims;

typedef NSString *MSIDAppVersion;
extern MSIDAppVersion MSIDAppVersionV1;
extern MSIDAppVersion MSIDAppVersionV2;
extern MSIDAppVersion MSIDAppVersionOnPrem;

@interface MSIDAutomationConfigurationRequest : NSObject <NSCopying>

@property (nonatomic) MSIDTestAccountProvider accountProvider;
@property (nonatomic) NSArray<MSIDTestAccountFeature> *accountFeatures;
@property (nonatomic) BOOL needsMultipleUsers;
@property (nonatomic) MSIDAppVersion appVersion;
@property (nonatomic) NSString *appName;
@property (nonatomic) NSDictionary *additionalQueryParameters;

- (NSURL *)requestURLWithAPIPath:(NSString *)apiPath;
+ (MSIDAutomationConfigurationRequest *)requestWithDictionary:(NSDictionary *)dictionary;

@end
