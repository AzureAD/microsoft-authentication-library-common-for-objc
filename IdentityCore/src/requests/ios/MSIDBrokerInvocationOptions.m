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

#import "MSIDBrokerInvocationOptions.h"
#import "MSIDConstants.h"
#import "MSIDAppExtensionUtil.h"

@interface MSIDBrokerInvocationOptions()

@property (nonatomic, readwrite) MSIDRequiredBrokerType minRequiredBrokerType;
@property (nonatomic, readwrite) MSIDBrokerProtocolType protocolType;
@property (nonatomic, readwrite) MSIDBrokerAADRequestVersion brokerAADRequestVersion;
@property (nonatomic, readwrite) NSString *registeredScheme;
@property (nonatomic, readwrite) NSString *brokerBaseUrlString;
@property (nonatomic, readwrite) NSString *versionDisplayableName;
@property (nonatomic, readwrite) BOOL isUniversalLink;

@end

@implementation MSIDBrokerInvocationOptions

#pragma mark - Init

- (nullable instancetype)initWithRequiredBrokerType:(MSIDRequiredBrokerType)minRequiredBrokerType
                                       protocolType:(MSIDBrokerProtocolType)protocolType
                                  aadRequestVersion:(MSIDBrokerAADRequestVersion)aadRequestVersion
{
    self = [super init];
    
    if (self)
    {
        _minRequiredBrokerType = minRequiredBrokerType;
        _protocolType = protocolType;
        _brokerAADRequestVersion = aadRequestVersion;
        
        _registeredScheme = [self registeredSchemeForBrokerType:minRequiredBrokerType];
        
        if (!_registeredScheme)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unable to resolve expected URL scheme for required broker type %ld", (long)minRequiredBrokerType);
            return nil;
        }
        
        _brokerBaseUrlString = [self brokerBaseUrlForCommunicationProtocolType:protocolType aadRequestVersion:aadRequestVersion];
        
        if (!_brokerBaseUrlString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unable to resolve base broker URL for protocol type %ld", (long)protocolType);
            return nil;
        }
        
        _versionDisplayableName = [self displayableNameForBrokerType:minRequiredBrokerType];
        _isUniversalLink = [_brokerBaseUrlString hasPrefix:@"https"];
    }
    
    return self;
}

- (instancetype)init
{
    return [self initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault
                               protocolType:MSIDBrokerProtocolTypeUniversalLink
                          aadRequestVersion:MSIDBrokerAADRequestVersionV2];
}

#pragma mark - Getters

- (BOOL)isRequiredBrokerPresent
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

- (NSString *)brokerBaseUrlForCommunicationProtocolType:(MSIDBrokerProtocolType)protocolType
                                      aadRequestVersion:(MSIDBrokerAADRequestVersion)aadRequestVersion
{
    NSString *aadRequestScheme = nil;
    
    switch (aadRequestVersion) {
        case MSIDBrokerAADRequestVersionV1:
            aadRequestScheme = MSID_BROKER_ADAL_SCHEME;
            break;
            
        case MSIDBrokerAADRequestVersionV2:
            aadRequestScheme = MSID_BROKER_MSAL_SCHEME;
            break;
            
        default:
            return nil;
    }
    
    switch (protocolType) {
        case MSIDBrokerProtocolTypeCustomScheme:
            return [NSString stringWithFormat:@"%@://broker", aadRequestScheme];
            break;
        case MSIDBrokerProtocolTypeUniversalLink:
            return [NSString stringWithFormat:@"https://%@/applebroker/%@", MSIDTrustedAuthorityWorldWide, aadRequestScheme];
        default:
            break;
    }
    
    return nil;
}

- (NSString *)displayableNameForBrokerType:(MSIDRequiredBrokerType)brokerType
{
    switch (brokerType) {
        case MSIDRequiredBrokerTypeWithADALOnly:
            return @"V1-broker";
            
        case MSIDRequiredBrokerTypeWithV2Support:
            return @"V2-broker";
            
        case MSIDRequiredBrokerTypeWithNonceSupport:
            return @"V2-broker-nonce";
            
        default:
            break;
    }
}

- (NSString *)registeredSchemeForBrokerType:(MSIDRequiredBrokerType)brokerType
{
    switch (brokerType) {
        case MSIDRequiredBrokerTypeWithADALOnly:
            return MSID_BROKER_ADAL_SCHEME;
            
        case MSIDRequiredBrokerTypeWithV2Support:
            return MSID_BROKER_MSAL_SCHEME;
            
        case MSIDRequiredBrokerTypeWithNonceSupport:
            return MSID_BROKER_NONCE_SCHEME;
            
        default:
            return nil;
    }
}

@end
