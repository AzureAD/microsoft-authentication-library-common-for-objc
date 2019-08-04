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

#import "MSIDBrokerVersion.h"
#import "MSIDConstants.h"
#import "MSIDAppExtensionUtil.h"

@interface MSIDBrokerVersion()

@property (nonatomic, readwrite) MSIDBrokerVersionType versionType;
@property (nonatomic, readwrite) NSString *registeredScheme;
@property (nonatomic, readwrite) NSString *brokerBaseUrlString;
@property (nonatomic, readwrite) NSString *versionDisplayableName;
@property (nonatomic, readwrite) BOOL isUniversalLink;

@end

@implementation MSIDBrokerVersion

#pragma mark - Init

- (instancetype)initWithVersionType:(MSIDBrokerVersionType)versionType
{
    self = [super init];
    
    if (self)
    {
        _versionType = versionType;
        _registeredScheme = [self schemeForVersionType:versionType];
        
        if (!_registeredScheme)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unable to resolve expected URL scheme for version type %ld", (long)versionType);
            return nil;
        }
        
        _brokerBaseUrlString = [self brokerBaseUrlForType:versionType];
        
        if (!_brokerBaseUrlString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unable to resolve base broker URL for version type %ld", (long)versionType);
            return nil;
        }
        
        _versionDisplayableName = [self displayableNameForVersionType:versionType];
        _isUniversalLink = [_brokerBaseUrlString hasPrefix:@"https"];
    }
    
    return self;
}

- (instancetype)init
{
    return [self initWithVersionType:MSIDBrokerVersionTypeDefault];
}

#pragma mark - Getters

- (BOOL)isPresentOnDevice
{
    if (!self.registeredScheme)
    {
        return NO;
    }
    
    if (![MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        // Verify broker app url can be opened
        return [[MSIDAppExtensionUtil sharedApplication] canOpenURL:[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@://broker", self.registeredScheme]]];
    }
    else
    {
        // Cannot perform app switching from application extension hosts
        return NO;
    }
}

#pragma mark - Helpers

- (NSString *)brokerBaseUrlForType:(MSIDBrokerVersionType)versionType
{
    switch (versionType) {
        case MSIDBrokerVersionTypeWithADALOnly:
        case MSIDBrokerVersionTypeWithV2Support:
            return [NSString stringWithFormat:@"%@://broker", self.registeredScheme];
            
        case MSIDBrokerVersionTypeWithUniversalLinkSupport:
            return [NSString stringWithFormat:@"https://%@/applebroker", MSIDTrustedAuthorityWorldWide];
            
        default:
            return nil;
    }
}

- (NSString *)displayableNameForVersionType:(MSIDBrokerVersionType)versionType
{
    switch (versionType) {
        case MSIDBrokerVersionTypeWithADALOnly:
            return @"V1-broker";
            
        case MSIDBrokerVersionTypeWithV2Support:
            return @"V2-broker";
            
        case MSIDBrokerVersionTypeWithUniversalLinkSupport:
            return @"V2-broker-universal-link";
            
        default:
            break;
    }
}

- (NSString *)schemeForVersionType:(MSIDBrokerVersionType)versionType
{
    switch (versionType) {
        case MSIDBrokerVersionTypeWithADALOnly:
            return MSID_BROKER_ADAL_SCHEME;
            
        case MSIDBrokerVersionTypeWithV2Support:
            return MSID_BROKER_MSAL_SCHEME;
            
        case MSIDBrokerVersionTypeWithUniversalLinkSupport:
            return MSID_BROKER_UNIVERSAL_LINK_SCHEME;
            
        default:
            return nil;
    }
}

@end
