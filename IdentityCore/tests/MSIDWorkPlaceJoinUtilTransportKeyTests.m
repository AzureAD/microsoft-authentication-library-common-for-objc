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


#if FALSE
@interface MSIDWorkPlaceJoinUtilTransportKeyTests
 -(void)insertEccStkKeyForTenantIdentifier:(NSString *)tenantIdentifier;
@end

@implementation MSIDWorkPlaceJoinUtilTransportKeyTests

// Helper method to delete all STK keys for a given tenant ID
- (OSStatus)deleteAllSTKKeysForTenantId:(NSString *)tenantId
{
    if (!tenantId) {
        return errSecParam;
    }
    
    NSString *keychainGroup = [self keychainGroup:NO]; // Use V2 keychain group
    NSString *stkTagPrefix = [NSString stringWithFormat:@"%@#%@", kMSIDPrivateTransportKeyIdentifier, tenantId];
    
    // Create query to find all STK keys for this tenant
    NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
    [deleteQuery setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [deleteQuery setObject:(__bridge id)kSecAttrTokenIDSecureEnclave forKey:(__bridge id)kSecAttrTokenID];
    [deleteQuery setObject:keychainGroup forKey:(__bridge id)kSecAttrAccessGroup];
    
    // Use the STK tag prefix to match all STK keys for this tenant
    // This will match both "-EC" suffix and any other potential suffixes
    [deleteQuery setObject:[stkTagPrefix dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecAttrApplicationTag];
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    
    // If no items found, that's also considered success for cleanup purposes
    if (status == errSecItemNotFound) {
        status = errSecSuccess;
    }
    
    return status;
}

// Alternative method that uses a more targeted approach by querying first, then deleting
- (OSStatus)deleteAllSTKKeysForTenantIdWithQuery:(NSString *)tenantId
{
    if (!tenantId) {
        return errSecParam;
    }
    
    NSString *keychainGroup = [self keychainGroup:NO];
    NSString *stkTagPrefix = [NSString stringWithFormat:@"%@#%@", kMSIDPrivateTransportKeyIdentifier, tenantId];
    
    // First, query for all STK keys for this tenant
    NSMutableDictionary *queryDict = [[NSMutableDictionary alloc] init];
    [queryDict setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [queryDict setObject:(__bridge id)kSecAttrTokenIDSecureEnclave forKey:(__bridge id)kSecAttrTokenID];
    [queryDict setObject:keychainGroup forKey:(__bridge id)kSecAttrAccessGroup];
    [queryDict setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
    [queryDict setObject:@YES forKey:(__bridge id)kSecReturnAttributes];
    
    CFArrayRef items = NULL;
    OSStatus queryStatus = SecItemCopyMatching((__bridge CFDictionaryRef)queryDict, (CFTypeRef *)&items);
    
    if (queryStatus == errSecItemNotFound) {
        return errSecSuccess; // No items to delete
    }
    
    if (queryStatus != errSecSuccess) {
        return queryStatus;
    }
    
    OSStatus deleteStatus = errSecSuccess;
    NSArray *itemsArray = (__bridge_transfer NSArray *)items;
    
    // Iterate through found items and delete those that match our tenant's STK pattern
    for (NSDictionary *item in itemsArray) {
        NSData *tagData = item[(__bridge id)kSecAttrApplicationTag];
        if (tagData) {
            NSString *tag = [[NSString alloc] initWithData:tagData encoding:NSUTF8StringEncoding];
            if ([tag hasPrefix:stkTagPrefix]) {
                // Create delete query for this specific key
                NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
                [deleteQuery setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
                [deleteQuery setObject:(__bridge id)kSecAttrTokenIDSecureEnclave forKey:(__bridge id)kSecAttrTokenID];
                [deleteQuery setObject:keychainGroup forKey:(__bridge id)kSecAttrAccessGroup];
                [deleteQuery setObject:tagData forKey:(__bridge id)kSecAttrApplicationTag];
                
                OSStatus itemDeleteStatus = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
                if (itemDeleteStatus != errSecSuccess && itemDeleteStatus != errSecItemNotFound) {
                    deleteStatus = itemDeleteStatus; // Keep track of any deletion failures
                }
            }
        }
    }
    
    return deleteStatus;
}

// Teardown
- (void)tearDown
{
    [super tearDown];
    [self deleteAllSTKKeysForTenantIdWithQuery:self.tenantId];
}



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
    NSString *tid = self.tenantId;
    [self insertDummyEccRegistrationForTenantIdentifier:tid certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    // Don't insert transport key - simulate missing STK scenario
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:tid context:nil];
    
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
