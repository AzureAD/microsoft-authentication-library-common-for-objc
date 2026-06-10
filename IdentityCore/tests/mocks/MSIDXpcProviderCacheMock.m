//
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


#import "MSIDXpcProviderCacheMock.h"

@interface MSIDXpcProviderCacheMock()

@property (nonatomic) BOOL isXpcProviderInstalledOnDevice;
@property (nonatomic) BOOL isXpcValidated;
@property (nonatomic, readwrite) NSUInteger cachedBrokerInstanceEndpointGetCount;
@property (nonatomic, readwrite) NSUInteger cachedBrokerInstanceEndpointSetCount;
@property (nonatomic, readwrite) NSUInteger setCachedBrokerInstanceEndpointRejectedCount;
@property (nonatomic, readwrite) NSUInteger clearCachedBrokerInstanceEndpointCallCount;

@end

@implementation MSIDXpcProviderCacheMock
{
    NSXPCListenerEndpoint *_cachedBrokerInstanceEndpoint;
    MSIDSsoProviderType _cachedXpcProviderType;
}

@synthesize xpcConfiguration;

- (instancetype)initWithXpcInstallationStatus:(BOOL)xpcInstallationStatus
                               isXpcValidated:(BOOL)isXpcValidated
{
    self = [super init];
    if (self)
    {
        self.isXpcProviderInstalledOnDevice = xpcInstallationStatus;
        self.isXpcValidated = isXpcValidated;
        
        return self;
    }
    
    return nil;
}

- (BOOL)validateCacheXpcProvider
{
    return _isXpcValidated;
}

- (BOOL)isXpcProviderInstalledOnDevice
{
    return _isXpcProviderInstalledOnDevice;
}

- (MSIDSsoProviderType)cachedXpcProviderType
{
    return _cachedXpcProviderType;
}

- (void)setCachedXpcProviderType:(MSIDSsoProviderType)cachedXpcProviderType
{
    _cachedXpcProviderType = cachedXpcProviderType;
    // Mirror production behavior: provider-type change drops the cached endpoint.
    _cachedBrokerInstanceEndpoint = nil;
}

- (NSXPCListenerEndpoint *)cachedBrokerInstanceEndpoint
{
    self.cachedBrokerInstanceEndpointGetCount += 1;
    return _cachedBrokerInstanceEndpoint;
}

- (BOOL)setCachedBrokerInstanceEndpoint:(NSXPCListenerEndpoint *)endpoint
                        forProviderType:(MSIDSsoProviderType)providerType
{
    if (_cachedXpcProviderType != providerType)
    {
        self.setCachedBrokerInstanceEndpointRejectedCount += 1;
        return NO;
    }
    
    self.cachedBrokerInstanceEndpointSetCount += 1;
    _cachedBrokerInstanceEndpoint = endpoint;
    return YES;
}

- (void)clearCachedBrokerInstanceEndpoint
{
    self.clearCachedBrokerInstanceEndpointCallCount += 1;
    _cachedBrokerInstanceEndpoint = nil;
}

@end


