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
#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "NSData+MSIDExtensions.h"


#if TARGET_OS_IOS
@interface MSIDWorkPlaceJoinUtilTransportKeyTests : XCTestCase
 -(void)insertEccStkKeyForTenantIdentifier:(NSString *)tenantIdentifier;
@property (nonatomic) NSString *tenantId;
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *stkEccKeyGenerator;
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *eccKeyGenerator;
@property (nonatomic) BOOL useIosStyleKeychain;
@end

static NSString *dummyKeyIdendetifier = @"com.microsoft.workplacejoin.dummyKeyIdentifier";
static NSString *dummyKeyV2Idendeifier = @"com.microsoft.workplacejoin.v2.dummyKeyIdentifier";

// WPJ test values
static NSString *dummyKeyIdentifierValue1 = @"dummyupn@microsoft.com";
static NSString *dummyKeyTenantValue1 = @"72f988bf-86f1-41af-91ab-2d7cd011db47";

static NSString *dummyKeyIdentifierValue2 = @"dummyupn@m365x957144.onmicrosoft.com";
static NSString *dummyKeyTenantValue2 = @"ef5e032c-f4cf-4d87-a328-286ff45dc5b0";

static NSString *dummyKeyIdentifierValue3 = @"dummyupn@m365x193839.onmicrosoft.com";
static NSString *dummyKeyTenantValue3 = @"5ac3f3c6-e654-4968-a4c7-f2a7e4bde783";

static NSString *kDummyTenant1CertIdentifier = @"OWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant2CertIdentifier = @"OWZmNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant3CertIdentifier = @"NmFhNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";

@implementation MSIDWorkPlaceJoinUtilTransportKeyTests

-(void)setUp
{
    [super setUp];
    self.tenantId = NSUUID.UUID.UUIDString;
    self.useIosStyleKeychain = YES;
}

- (void)tearDown
{
    if (self.useIosStyleKeychain)
    {
        [self cleanWPJ:[self keychainGroup:YES]];
        [self cleanWPJ:[self keychainGroup:NO]];
    }
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


#pragma mark - Helpers from MSIDWorkPlaceJoinUtilTests
- (void)cleanWPJ:(NSString *)keychainGroup
{
    NSArray *deleteClasses = @[(__bridge id)(kSecClassKey), (__bridge id)(kSecClassCertificate), (__bridge id)(kSecClassGenericPassword)];
    
    for (NSString *deleteClass in deleteClasses)
    {
        NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
        [deleteQuery setObject:deleteClass forKey:(__bridge id)kSecClass];
        if (self.useIosStyleKeychain)
        {
#if TARGET_OS_OSX
            [deleteQuery setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
#endif
            [deleteQuery setObject:keychainGroup forKey:(__bridge id)kSecAttrAccessGroup];
        }
        OSStatus result = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        XCTAssertTrue(result == errSecSuccess || result == errSecItemNotFound);
    }
}

- (OSStatus)insertDummyWPJInLegacyFormat:(BOOL)useLegacyFormat
                        tenantIdentifier:(NSString *)tenantIdentifier
                     writeTenantMetadata:(BOOL)writeTenantMetadata
                          certIdentifier:(NSString *)certIdentifier
{
    SecCertificateRef certRef = [self dummyCertRef:certIdentifier];
    SecKeyRef keyRef = [self dummyPrivateKeyForCertRef];
    
    NSString *keychainGroup = [self keychainGroup:useLegacyFormat];
    
    NSString *tag = nil;
    
    if (useLegacyFormat)
    {
        tag = [NSString stringWithFormat:@"%@", kMSIDPrivateKeyIdentifier];
        
        if (writeTenantMetadata && tenantIdentifier)
        {
            [self.class insertDummyStringDataIntoKeychain:tenantIdentifier
                                           dataIdentifier:kMSIDTenantKeyIdentifier
                                              accessGroup:keychainGroup];
        }
    }
    else
    {
        tag = [NSString stringWithFormat:@"%@#%@", kMSIDPrivateKeyIdentifier, tenantIdentifier];
    }
    
    return [self insertDummyDRSIdentityIntoKeychain:certRef
                                      privateKeyRef:keyRef
                                      privateKeyTag:tag
                                        accessGroup:keychainGroup];

}

- (OSStatus)insertDummyEccRegistrationForTenantIdentifier:(NSString *)tenantIdentifier
                                           certIdentifier:(NSString *)certIdentifier
                                        useSecureEnclave:(BOOL)useEncSecureEnclave
{
    SecCertificateRef certRef = [self dummyEccCertRef:certIdentifier];
    XCTAssertTrue(certRef != NULL);
    // Append Suffix kMSIDPrivateKeyIdentifier
    NSString *tag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateKeyIdentifier, tenantIdentifier, @"-EC"];
    SecKeyRef keyRef = [self createAndGetdummyEccPrivateKey:useEncSecureEnclave privateKeyTag:tag];
    XCTAssertTrue(keyRef != NULL);
    NSString *keychainGroup = [self keychainGroup:NO];
    OSStatus status = [self insertDummyDRSIdentityIntoKeychain:certRef
                                                 privateKeyRef:keyRef
                                                 privateKeyTag:tag
                                                   accessGroup:keychainGroup];
    return status;
}

- (OSStatus)insertDummyDRSIdentityIntoKeychain:(SecCertificateRef)certRef
                                 privateKeyRef:(SecKeyRef)privateKeyRef
                                 privateKeyTag:(NSString *)privateKeyTag
                                   accessGroup:(NSString *)accessGroup
{
    OSStatus status = noErr;
    
    status = [self insertKeyIntoKeychain:privateKeyRef
                           privateKeyTag:privateKeyTag
                             accessGroup:accessGroup];
    if (status != noErr && status != errSecDuplicateItem)
    {
        return status;
    }
    
    NSDictionary *attributes = (NSDictionary *)CFBridgingRelease(SecKeyCopyAttributes(privateKeyRef));
    return [self insertCertIntoKeychain:certRef
                            accessGroup:accessGroup
                          publicKeyHash:attributes[(__bridge id)kSecAttrApplicationLabel]];
}

- (OSStatus)insertKeyIntoKeychain:(SecKeyRef)keyRef
                    privateKeyTag:(NSString *)keyTag
                      accessGroup:(NSString *)accessGroup
{
    NSMutableDictionary *keyInsertQuery = [[NSMutableDictionary alloc] init];
    [keyInsertQuery setObject:(__bridge id)(kSecClassKey) forKey:(__bridge id)kSecClass];
    [keyInsertQuery setObject:(__bridge id)(keyRef) forKey:(__bridge id)kSecValueRef];
    [keyInsertQuery setObject:[NSData dataWithBytes:[keyTag UTF8String] length:keyTag.length] forKey:(__bridge id)kSecAttrApplicationTag];

    if (self.useIosStyleKeychain)
    {
        [keyInsertQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#if TARGET_OS_OSX
        [keyInsertQuery setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
#endif
    }
    return SecItemAdd((__bridge CFDictionaryRef)keyInsertQuery, nil);
}

- (OSStatus)insertCertIntoKeychain:(SecCertificateRef)certRef
                       accessGroup:(NSString *)accessGroup
                     publicKeyHash:(NSData *)publicKeyHash
{
    NSMutableDictionary *certInsertQuery = [[NSMutableDictionary alloc] init];
    [certInsertQuery setObject:(__bridge id)(kSecClassCertificate) forKey:(__bridge id)kSecClass];
    [certInsertQuery setObject:(__bridge id)(certRef) forKey:(__bridge id)kSecValueRef];
    [certInsertQuery setObject:publicKeyHash forKey:(__bridge id)kSecAttrPublicKeyHash];
    if (self.useIosStyleKeychain)
    {
        [certInsertQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#if TARGET_OS_OSX
        [certInsertQuery setObject:@YES forKey:(__bridge id)kSecUseDataProtectionKeychain];
#endif
    }
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)certInsertQuery, NULL);
    return st;
}

- (SecCertificateRef)dummyCertRef:(NSString *)certIdentifier
{
    NSString *drsIssuedCertificate = [self dummyCertificate:certIdentifier];
    NSData *certData = [NSData msidDataFromBase64UrlEncodedString:drsIssuedCertificate];
    return SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certData));
}

- (SecCertificateRef)dummyEccCertRef:(NSString *)certIdentifier
{
    NSString *drsIssuedCertificate = [self dummyEccCertificate:certIdentifier];
    NSData *certData = [NSData msidDataFromBase64UrlEncodedString:drsIssuedCertificate];
    return SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certData));
}

- (NSString *)dummyCertificate:(NSString *)certIdentifier
{
    return [NSString stringWithFormat: @"MIIEAjCCAuqgAwIBAgIQFc8t8z6QDoBGW1z8UDN+0zANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTE5MDgyOTIwMjU1NloXDTI5MDgyOTIwNTU1NlowLzEtMCsGA1UEAxMk%@MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABo4HQMIHNMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwDgYDVR0PAQH/BAQDAgeAMCIGCyqGSIb3FAEFghwCBBMEgRA78+WeSZfnQ5VngxjqQSVLMCIGCyqGSIb3FAEFghwDBBMEgRBP+CztBI6eSJZu39covAlhMCIGCyqGSIb3FAEFghwFBBMEgRCS4qJehkWISIVqoGYSGf2rMBQGCyqGSIb3FAEFghwIBAUEgQJOQTATBgsqhkiG9xQBBYIcBwQEBIEBMDANBgkqhkiG9w0BAQsFAAOCAQEAn6nzvuRd1moZ78aNfaZwFlxJx9ycNQNHRVljw4/Asqc9X2ySq4vE+f3zpqq2Q0c6lZ/yykb0KmZXeqWgyRK82uR48gWNAVvbPJr4l6B2cnTHAwkc+PLmADr7sE2WgBGH3uSqMcDKSbE/VpH3zOAnxeC8RByy/EEvGdC3YasjR9IGL4sSkyLHrZNO6Pz7oApL/BA713xJcp+EkzDIFF09JILuP1IANz8uW26GyNLBtBfdulKbbzv1i0tWMukN+s8upm9mWJyn8hXmz/LUa5NQtP0mBrRbw1d7NXPOgO54dr+DPpKZxrQw6zpwCJ/waeKIJjHAIDAF6h1BjFCaAulhJA==", certIdentifier];
}

- (NSString *)dummyEccCertificate:(NSString *)certIdentifier
{
    return [NSString stringWithFormat: @"MIIDNzCCAh-gAwIBAgIQKBcXojifRIxLIuut33ZknzANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTIzMDMxMzIxMjk0OFoXDTMzMDMxMzIxNTk0OFowLzEtMCsGA1UEAxMk%@MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEl-xbT_nXgQkkzQOX7NPrvh9vPMt7yrzLqBthSpZXuIjV77izK_GW91qHTzZImhwbvXG6AcVH9Qs7ilN-VIb9xaOB0DCBzTAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB_wQMMAoGCCsGAQUFBwMCMA4GA1UdDwEB_wQEAwIHgDAiBgsqhkiG9xQBBYIcAgQTBIEQo8MK5pvg9k-6UZTxtj7IITAiBgsqhkiG9xQBBYIcAwQTBIEQj-LgHz1F-kSyqt3J40Sn7zAiBgsqhkiG9xQBBYIcBQQTBIEQkq1F9o3jGk21ENGwmnSoyjAUBgsqhkiG9xQBBYIcCAQFBIECTkEwEwYLKoZIhvcUAQWCHAcEBASBATAwDQYJKoZIhvcNAQELBQADggEBAFYbeUHpPcZj6Z8BcPhQ59dOi3-aGSYKX6Ub6GBv1CgiqU9EJ-P6VOipCL5dR458nMXJ4j97_pOXwPT0sS1rSTJ8_x3YpGLIJXpvkqDEHIoUvX1sR1tOlvXhUiP0O6l35-sil1itUZAKqS7RZtd8TWnMIgw3rCHbDHA9OlagunL6o75YC5Y74VdedZbCUjTy-IuU_VKM5gpa3c6uf_QleYgdQFlDjMH9w4TkqaWNONNoYulLZI8AykT9QtYB0iAsFr4KRL58ot1svOhqMil9vKDTkDrixEyThCcHmyyHeNoBjmXtaubOAiE3cMoJs7bV7I1uOS9aAI-Hm0W9NV-CkeE", certIdentifier];
}

- (NSString *)dummyPrivateKeyForCert
{
    return @"MIIEowIBAAKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABAoIBAEmRRI3GeQQWpn2h3m11wsPKC/sLYdxJZcFjdrGG2LqCaY0XO4vJjO5MDJlxb+uaQsXascf91sx67QyfbSpirMIy9sUP1LNRHEmtEW4YUDbcjq1aDsB76GyVYPt0VIG/0v4ABcQ97qIyUCeivw5ZU6LBjwUD1ScHiSEfSeCMWyk9YgRUozM3yZOpvugwjOF7efEjVlWvGvIfh9U/Xyeuj+NJ3r8zW87K+ySzGwrPwEmfBBfyd5LOqZzPJAKGJ3og8oaMDf4IWV7iSicCcPCbq6psj+B/i4HZc9u3MqE7YjKVbNG2S6qDsLUxpWfct72ZeKtfZcb3Kqa1nh0RximqUoECgYEA6UfzvsHg283KOTxQqX3v2IDbtwv73wKd/+V8sq8mhtjJhv5SpyJe99L/cuoxTu2ELUPmKIP++b7oyMvdRNyJaLIMRYDGGAKeLXXtWht//tCmHXyOZDhs9oHC3EMNHmqXBDSObL/CbN5puAQbCjofUX5zTNMdmq0qTOPYUezxjHECgYEA6S8JXstQ5RL+pmonoFlPWfuwXL8chpGJH1iOab1WYwjAbszSy1LJBQu5dWhKcqLl3EFywJgWRUKGFlQ/099XRVTHl4YhjEN054GEBxsTkZUhwXh0l0v6lPnsG6daWcTZ44gh4FXtqfPD/5/RcWUfhYQW0NoeIzviWt8MqZ6NIQ0CgYEA1TDpg/qBOb9vQTFq8grix7Szlyx/iYZFyNf8RvwktHWobxM7i/ywV8HfrDB00ZHlCs0TqRFAUxNygBc3Zzg455JX/qi54LV7w0YTnRamucQLG8V6CAM9KWbbIxqwAY0d6DzzsFTrJT151i8CWy1U89AhJSOG2ZXJo61SQ0TMVzECgYA6w8PUw+BLGpJaVf5OhrNctfUoKnGB6ENqRuL8+t4+bwIv6iZlXyORxfajA/lfEnZjH4tPxgQ2yCEKl4jOWEaiDk+OfBsQQh/AB//B2qz/z1mGbFjVmCw6RxGdlntKjDVtBe2jn4QZhHksfpZFwXpEJ5moYI+fyYOt6vBB/tcKMQKBgD7q4f036ad5TeX14vsFSSkGeOJrbUw0UqYeUit9B8DICwrV42/z60kTXxGg+2Wo8gL5Fo2tKCUe34BvvpMP92EKB/qbjoIirbZVnEDP9K1rCdGdEaYzDlRXsQ/p/bM6Tz3X++wpnqcDQhJp6lTDVLaX4faSQjWuVVIHVn1zpvIr";
}

- (SecKeyRef)dummyPrivateKeyForCertRef
{
    NSDictionary *keyAttr = @{(__bridge NSString*) kSecAttrKeyType : (__bridge NSString*)kSecAttrKeyTypeRSA,
                              (__bridge NSString*) kSecAttrKeyClass : (__bridge NSString*)kSecAttrKeyClassPrivate};
    
    NSString *privateKeyForCert = [self dummyPrivateKeyForCert];
    NSData *keyData = [NSData msidDataFromBase64UrlEncodedString:privateKeyForCert];
    return SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef) keyAttr, NULL);
}

- (SecKeyRef)createAndGetdummyEccPrivateKey:(BOOL)useSecureEnclave privateKeyTag:(NSString *)privateKeyTag
{
    self.eccKeyGenerator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc]
                            initWithSharedAccessGroup:[self keychainGroup:NO]
                            useSecureEnclave:useSecureEnclave
                            applicationTag:privateKeyTag];
    XCTAssertNotNil(self.eccKeyGenerator);
    return self.eccKeyGenerator.eccPrivateKey;
}

- (NSString *)keychainGroup:(BOOL)useLegacyFormat
{
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    XCTAssertNotNil(teamId);

    if (useLegacyFormat)
    {
        return [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    }
    
    return [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
}

+ (OSStatus) insertDummyStringDataIntoKeychain: (NSString *) stringData
                                dataIdentifier: (NSString *) dataIdentifier
                                   accessGroup: (__unused NSString *) accessGroup
{
    NSMutableDictionary *insertStringDataQuery = [[NSMutableDictionary alloc] init];
    [insertStringDataQuery setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [insertStringDataQuery setObject:dataIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [insertStringDataQuery setObject:stringData forKey:(__bridge id<NSCopying>)(kSecAttrService)];

#if TARGET_OS_IOS
    [insertStringDataQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif
    return SecItemAdd((__bridge CFDictionaryRef)insertStringDataQuery, NULL);
}

+ (OSStatus) insertDummyStringUPNDataIntoKeychainV2: (NSString *) stringData
                                   tenantIdentifier: (NSString *) tenantIdentifier
                                     dataIdentifier: (NSString *) dataIdentifier
                                        accessGroup: (__unused NSString *) accessGroup
{
    NSMutableDictionary *insertStringDataQuery = [[NSMutableDictionary alloc] init];
    [insertStringDataQuery setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [insertStringDataQuery setObject:dataIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [insertStringDataQuery setObject:stringData forKey:(__bridge id<NSCopying>)(kSecAttrLabel)];
    [insertStringDataQuery setObject:tenantIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrService)];

#if TARGET_OS_IOS
    [insertStringDataQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif
    return SecItemAdd((__bridge CFDictionaryRef)insertStringDataQuery, NULL);
}

+ (OSStatus) deleteDummyStringDataIntoKeychain: (NSString *) dataIdentifier
                                   accessGroup: (__unused NSString *) accessGroup
{
    NSMutableDictionary *deleteStringDataQuery = [[NSMutableDictionary alloc] init];
    [deleteStringDataQuery setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [deleteStringDataQuery setObject:dataIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [deleteStringDataQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];

#if TARGET_OS_IOS
    [deleteStringDataQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif

    return SecItemDelete((__bridge CFDictionaryRef)(deleteStringDataQuery));
}

- (OSStatus)addPrimaryEccDefaultRegistrationForTenantId:(NSString *)tenantId
                                      sharedAccessGroup:(NSString *)sharedAccessGroup
                                         certIdentifier:(NSString *)certIdentifier
                                       useSecureEnclave:(BOOL)useSecureEnclave
{
    // Add tenantId for primary registration to keychain.
    NSMutableDictionary *query = [NSMutableDictionary new];
    query[(__bridge id <NSCopying>) (kSecClass)] = (__bridge id) (kSecClassGenericPassword);
    query[(__bridge id <NSCopying>) (kSecReturnAttributes)] = (id) kCFBooleanTrue;
    query[(__bridge id <NSCopying>) (kSecAttrAccount)] = @"ecc_default_tenant";
    query[(__bridge id <NSCopying>) (kSecAttrService)] = @"ecc_default_tenant";
    query[(__bridge id <NSCopying>) (kSecAttrDescription)] = tenantId;
#if TARGET_OS_OSX
    query[(__bridge id <NSCopying>) (kSecUseDataProtectionKeychain)] = @YES;
#endif
    query[(__bridge id) kSecAttrAccessGroup] = sharedAccessGroup;
    CFDictionaryRef attributeDictCF = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef) query, (CFTypeRef *) &attributeDictCF);
    
    if (status != errSecSuccess || status == errSecDuplicateItem)
    {
        return status;
    }
    return [self insertDummyEccRegistrationForTenantIdentifier:tenantId certIdentifier:certIdentifier useSecureEnclave:useSecureEnclave];
}

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

@end
#endif
