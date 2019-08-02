//
//  MSIDBrokerVersion.m
//  IdentityCore iOS
//
//  Created by Olga Dalton on 8/1/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "MSIDBrokerVersion.h"
#import "MSIDConstants.h"
#import "MSIDAppExtensionUtil.h"

@interface MSIDBrokerVersion()

@property (nonatomic, readwrite) MSIDBrokerVersionType versionType;
@property (nonatomic, readwrite) NSString *registeredScheme;
@property (nonatomic, readwrite) NSString *brokerBaseUrlString;

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
    }
    
    return self;
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

- (NSString *)brokerBaseUrlForType:(MSIDBrokerVersionType)versionType
{
    switch (versionType) {
        case MSIDBrokerVersionTypeWithADALOnly:
        case MSIDBrokerVersionTypeWithV2Support:
            return [NSString stringWithFormat:@"%@://broker", self.registeredScheme];
            
        case MSIDBrokerVersionTypeWithUniversalLinkSupport:
            return [NSString stringWithFormat:@"%@://applebroker", MSIDTrustedAuthorityWorldWide];
            
        default:
            return nil;
    }
}

#pragma mark - Helpers

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
