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
#import <XCTest/XCTest.h>
#import "MSIDWorkPlaceJoinUtilTests.h"
#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDWPJKeyPairWithCert.h"


#if TARGET_OS_IOS
@interface MSIDWorkPlaceJoinUtilTransportKeyTests : MSIDWorkPlaceJoinUtilTests
 -(void)insertEccStkKeyForTenantIdentifier:(NSString *)tenantIdentifier;
@end

@implementation MSIDWorkPlaceJoinUtilTransportKeyTests

- (void)insertEccStkKeyForTenantIdentifier:(NSString *)tenantIdentifier
{
    NSString *keychainGroup = [self keychainGroup:NO];
    NSString *stkTag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateTransportKeyIdentifier, tenantIdentifier, @"-EC"];
    if (!self.stkEccKeyGenerator)
        self.stkEccKeyGenerator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:keychainGroup
                                                                                          useSecureEnclave:YES
                                                                                            applicationTag:stkTag];
    SecKeyRef transportKeyRef = self.stkEccKeyGenerator.eccPrivateKey;
    XCTAssertTrue(transportKeyRef != NULL);
    [self insertKeyIntoKeychain:transportKeyRef
                  privateKeyTag:stkTag
                    accessGroup:keychainGroup];
}

- (void)testGetWPJKeysWithTenantId_whenEccRegistrationWithTransportKey_shouldReturnBothKeys
{
    [self insertDummyEccRegistrationForTenantIdentifier:self.tenantId certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    [self insertEccStkKeyForTenantIdentifier:self.tenantId];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    XCTAssertTrue(result.privateKeyRef != NULL);
    XCTAssertTrue(result.privateTransportKeyRef != NULL);
}

- (void)testGetWPJKeysWithTenantId_whenEccRegistrationWithMissingTransportKey_shouldReturnOnlyDeviceKey
{
    [self insertDummyEccRegistrationForTenantIdentifier:self.tenantId certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    // Don't insert transport key - simulate missing STK scenario
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    XCTAssertTrue(result.privateKeyRef != NULL);
    XCTAssertTrue(result.privateTransportKeyRef == NULL, @"Expected privateTransportKeyRef to be nil when transport key is missing");
}

- (void)testGetWPJKeysWithTenantId_whenPrimaryEccRegistrationWithTransportKey_shouldReturnCorrectKeys
{
    [self addPrimaryEccDefaultRegistrationForTenantId:self.tenantId
                                    sharedAccessGroup:[self keychainGroup:NO]
                                       certIdentifier:kDummyTenant1CertIdentifier
                                     useSecureEnclave:YES];
    [self insertEccStkKeyForTenantIdentifier:self.tenantId];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:nil context:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    XCTAssertTrue(result.privateKeyRef != NULL, @"Primary registration should have device key");
    XCTAssertTrue(result.privateTransportKeyRef != NULL, @"Primary registration should have transport key");
}

- (void)testGetWPJKeysWithTenantId_whenLegacyRegistration_shouldHaveNoTransportKey
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:self.tenantId writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV1);
    XCTAssertTrue(result.privateKeyRef != NULL, @"Legacy registration should have device key");
    XCTAssertTrue(result.privateTransportKeyRef == NULL, @"Legacy registration should not have transport key");
}

- (void)testGetWPJKeysWithTenantId_whenRSARegistrationInV2Format_shouldNotHaveTransportKey
{
    // For iOS, RSA keys in V2 format should not have transport keys
    // This tests the case where we have RSA device key but no transport key expected
    
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    
    // For RSA registrations, transport key should be nil even in V2 format
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    XCTAssertTrue(result.privateKeyRef != NULL, @"Expected privateKeyRef to be non-nil for RSA registration in V2 format");
    XCTAssertTrue(result.privateTransportKeyRef == NULL, @"Expected privateTransportKeyRef to be nil for RSA registration in V2 format");
}

- (void)testGetWPJKeysWithTenantId_concurrentAccess_shouldBeThreadSafe
{
    [self insertDummyEccRegistrationForTenantIdentifier:self.tenantId certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    [self insertEccStkKeyForTenantIdentifier:self.tenantId];
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *results = [NSMutableArray array];
    __block NSLock *lock = [[NSLock alloc] init];
    
    // Launch multiple concurrent requests
    for (int i = 0; i < 5; i++) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
            
            [lock lock];
            if (result) {
                [results addObject:result];
            }
            [lock unlock];
        });
    }
    
    // Wait for all requests to complete
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

    // All requests should succeed
    XCTAssertTrue(results.count == 5, @"All concurrent requests should succeed");
    
    // Verify all results have transport keys
    for (MSIDWPJKeyPairWithCert *result in results) {
        XCTAssertTrue(result.privateKeyRef != NULL);
        XCTAssertTrue(result.privateTransportKeyRef != NULL);
    }

}

@end
#endif
