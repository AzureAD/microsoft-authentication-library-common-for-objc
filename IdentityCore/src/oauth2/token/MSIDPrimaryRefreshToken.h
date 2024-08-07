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

#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyCredentialCacheCompatible.h"

typedef NS_ENUM(NSInteger, MSIDExternalPRTKeyLocationType)
{
    MSIDExternalPRTKeyLocationTypeNone = 0, // Key isn't stored externally
    MSIDExternalPRTKeyLocationTypeWPJSecureEnclave = 1, // WPJ device and STK keys stored in secure enclave are used for PRT operations (for device-bound cases)
    MSIDExternalPRTKeyLocationTypeSSO = 2, // External SSO keys are used for PRT operations
    MSIDExternalPRTKeyLocationTypeSecureEnclave = 3 // External secure enclave keys are used for PRT operations (for deviceless cases)
};

@class MSIDLegacyTokenCacheItem;

@interface MSIDPrimaryRefreshToken : MSIDLegacyRefreshToken <MSIDLegacyCredentialCacheCompatible>

@property (nonatomic) NSData *sessionKey;
@property (nonatomic) NSString *deviceID;
@property (nonatomic) NSString *prtProtocolVersion;
@property (nonatomic) NSDate *expiresOn;
@property (nonatomic) NSDate *cachedAt;
@property (nonatomic) NSUInteger expiryInterval;
@property (nonatomic, readonly) NSUInteger refreshInterval;
@property (nonatomic) NSDate *lastRecoveryAttempt;
@property (nonatomic) NSUInteger recoveryAttemptCount;
@property (nonatomic) BOOL lastRecoveryAttemptFailed;
@property (nonatomic) MSIDExternalPRTKeyLocationType externalKeyLocationType;
 
- (BOOL)isDevicelessPRT;
- (BOOL)shouldRefreshWithInterval:(NSUInteger)refreshInterval;
- (NSUInteger)prtId;

@end
