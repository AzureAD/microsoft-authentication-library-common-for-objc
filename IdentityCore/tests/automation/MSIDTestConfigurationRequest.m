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

#import "MSIDTestConfigurationRequest.h"

/*! WW is a world wide entirely on-cloud account */
MSIDTestAccountProvider MSIDTestAccountProviderWW = @"AzureCloud";
/*! Black Forest is an AMSID account hosted in the Black Forest sovereign cloud (.de) */
MSIDTestAccountProvider MSIDTestAccountProviderBlackForest = @"AzureGermanyCloud";
/*! A WW account federated using MSIDFSv2 (these accounts can also be used for on-prem tests) */
MSIDTestAccountProvider MSIDTestAccountProviderMSIDfsv2 = @"MSIDFSv2";
/*! A WW account federated using MSIDFSv3 (these accounts can also be used for on-prem tests) */
MSIDTestAccountProvider MSIDTestAccountProviderMSIDfsv3 = @"MSIDFSv3";
/*! A WW account federated using MSIDFSv4 (these accounts can also be used for on-prem tests) */
MSIDTestAccountProvider MSIDTestAccountProviderMSIDfsv4 = @"MSIDFSv4";
/*! A WW account federated using Shibboleth */
MSIDTestAccountProvider MSIDTestAccountProviderShibboleth = @"Shib";
/*! A WW account federated using Ping */
MSIDTestAccountProvider MSIDTestAccountProviderPing = @"Ping";

MSIDTestAccountFeature MSIDTestAccountFeatureMDMEnabled = @"mam";
MSIDTestAccountFeature MSIDTestAccountFeatureMAMEnabled = @"mdm";
MSIDTestAccountFeature MSIDTestAccountFeatureDeviceAuth = @"device";
MSIDTestAccountFeature MSIDTestAccountFeatureMFAEnabled = @"mfa";
MSIDTestAccountFeature MSIDTestAccountFeatureGuestUser = @"Guest";

MSIDAppVersion MSIDAppVersionV1 = @"V1";
MSIDAppVersion MSIDAppVersionV2 = @"V2";

@implementation MSIDTestConfigurationRequest

- (BOOL)federated
{
    if ([self.accountProvider isEqualToString:MSIDTestAccountProviderWW]
        || [self.accountProvider isEqualToString:MSIDTestAccountProviderBlackForest])
    {
        return NO;
    }

    return YES;
}

- (NSString *)federatedValue
{
    if (self.federated)
    {
        return @"True";
    }

    return @"False";
}

- (NSString *)caValue
{
    if ([self.accountFeatures containsObject:MSIDTestAccountFeatureMAMEnabled])
    {
        return @"mamca";
    }
    else if ([self.accountFeatures containsObject:MSIDTestAccountFeatureMDMEnabled])
    {
        return @"mdmca";
    }
    else if([self.accountFeatures containsObject:MSIDTestAccountFeatureMFAEnabled])
    {
        return @"mfa";
    }

    return nil;
}

- (NSString *)userTypeValue
{
    if ([self.accountFeatures containsObject:MSIDTestAccountFeatureGuestUser])
    {
        return @"Guest";
    }

    return @"Member";
}

- (BOOL)isEqualToRequest:(MSIDTestConfigurationRequest *)request
{
    if (!request)
    {
        return NO;
    }

    BOOL result = YES;
    result &= (!self.accountProvider && !request.accountProvider) || [self.accountProvider isEqualToString:request.accountProvider];
    result &= (!self.appVersion && !request.appVersion) || [self.appVersion isEqualToString:request.appVersion];
    result &= (!self.accountFeatures && !request.accountFeatures) || [self.accountFeatures isEqualToArray:request.accountFeatures];
    result &= self.needsMultipleUsers == request.needsMultipleUsers;

    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDTestConfigurationRequest.class])
    {
        return NO;
    }

    return [self isEqualToRequest:(MSIDTestConfigurationRequest *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.needsMultipleUsers;
    hash ^= self.accountProvider.hash;
    hash ^= self.accountFeatures.hash;
    hash ^= self.appVersion.hash;

    return hash;
}

- (NSURL *)requestURLWithAPIPath:(NSString *)apiPath
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:apiPath];;

    NSMutableArray *queryItems = [NSMutableArray array];
    
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"isFederated" value:self.federatedValue]];

    NSString *caValue = self.caValue;

    if (caValue)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:caValue value:@"True"]];
    }
    else
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"mdmca" value:@"False"]];
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"mamca" value:@"False"]];
    }

    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"usertype" value:self.userTypeValue]];

    if (self.federated)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"federationProvider" value:self.accountProvider]];
    }
    else
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"AzureEnvironment" value:self.accountProvider]];
    }

    if (self.needsMultipleUsers)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"DisplayAll" value:@"True"]];
    }

    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"AppVersion" value:self.appVersion]];

    for (NSString *queryKey in [self.additionalQueryParameters allKeys])
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:queryKey value:self.additionalQueryParameters[queryKey]]];
    }

    components.queryItems = queryItems;
    NSURL *resultURL = [components URL];
    return resultURL;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    MSIDTestConfigurationRequest *request = [[MSIDTestConfigurationRequest allocWithZone:zone] init];
    request->_accountFeatures = _accountFeatures;
    request->_accountProvider = _accountProvider;
    request->_needsMultipleUsers = _needsMultipleUsers;
    request->_appVersion = _appVersion;
    return request;
}

+ (MSIDTestConfigurationRequest *)requestWithDictionary:(NSDictionary *)dictionary
{
    MSIDTestConfigurationRequest *request = [MSIDTestConfigurationRequest new];
    request.accountProvider = dictionary[@"account_provider"];
    request.accountFeatures = dictionary[@"account_features"];
    request.needsMultipleUsers = [dictionary[@"needs_multiple"] boolValue];
    request.appVersion = dictionary[@"app_version"];
    return request;
}

@end
