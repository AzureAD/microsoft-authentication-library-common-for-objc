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
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"

@interface MSIDWorkPlaceJoinUtilTests : XCTestCase
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *eccKeyGenerator;
@property (nonatomic) BOOL useIosStyleKeychain;
@property (atomic) MSIDTestSecureEnclaveKeyPairGenerator *stkEccKeyGenerator;
@property (atomic) NSString *tenantId;

extern NSString * const dummyKeyIdendetifier;
extern NSString * const dummyKeyV2Idendeifier;

// WPJ test values
extern NSString *dummyKeyIdentifierValue1;
extern NSString *dummyKeyTenantValue1;

extern NSString *dummyKeyIdentifierValue2;
extern NSString *dummyKeyTenantValue2;

extern NSString *dummyKeyIdentifierValue3;
extern NSString *dummyKeyTenantValue3;

extern NSString *kDummyTenant1CertIdentifier;
extern NSString *kDummyTenant2CertIdentifier;
extern NSString *kDummyTenant3CertIdentifier;

- (NSString *)keychainGroup:(BOOL)useLegacyFormat;
- (OSStatus)insertKeyIntoKeychain:(SecKeyRef)keyRef
                    privateKeyTag:(NSString *)keyTag
                      accessGroup:(NSString *)accessGroup;

- (OSStatus)insertDummyEccRegistrationForTenantIdentifier:(NSString *)tenantIdentifier
                                           certIdentifier:(NSString *)certIdentifier
                                         useSecureEnclave:(BOOL)useEncSecureEnclave;

- (OSStatus)addPrimaryEccDefaultRegistrationForTenantId:(NSString *)tenantId
                                      sharedAccessGroup:(NSString *)sharedAccessGroup
                                         certIdentifier:(NSString *)certIdentifier
                                       useSecureEnclave:(BOOL)useSecureEnclave;

- (OSStatus)insertDummyWPJInLegacyFormat:(BOOL)useLegacyFormat
                        tenantIdentifier:(NSString *)tenantIdentifier
                     writeTenantMetadata:(BOOL)writeTenantMetadata
                          certIdentifier:(NSString *)certIdentifier;
@end
