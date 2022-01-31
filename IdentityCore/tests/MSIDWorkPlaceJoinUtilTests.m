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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <XCTest/XCTest.h>
#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDAssymetricKeyPairWithCert.h"

@interface MSIDWorkPlaceJoinUtilTests : XCTestCase
@end

NSString * const dummyKeyIdendetifier = @"com.microsoft.workplacejoin.dummyKeyIdentifier";
static NSString *kDummyTenant1CertIdentifier = @"OWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant2CertIdentifier = @"OWZmNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant3CertIdentifier = @"NmFhNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";


@implementation MSIDWorkPlaceJoinUtilTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
#if TARGET_OS_IPHONE
    [self cleanWPJ:[self keychainGroup:YES]];
    [self cleanWPJ:[self keychainGroup:NO]];
#endif
}

- (void)testGetWPJStringDataForIdentifier_withKeychainItem_shouldReturnValidValue
{
    NSString *dummyKeyIdentifierValue = @"dummyupn@dummytenant.com";
    NSString *sharedAccessGroup = [self keychainGroup:YES];

    // Insert dummy UPN value.
    [MSIDWorkPlaceJoinUtilTests insertDummyStringDataIntoKeychain:dummyKeyIdentifierValue dataIdentifier:dummyKeyIdendetifier accessGroup:sharedAccessGroup];

    NSString *keyData = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:dummyKeyIdendetifier context:nil error:nil];
    XCTAssertNotNil(keyData);
    XCTAssertEqual([dummyKeyIdentifierValue isEqualToString: keyData], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue");

    // Cleanup
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:kMSIDUPNKeyIdentifier accessGroup:sharedAccessGroup];
}

- (void)testGetWPJStringDataForIdentifier_withoutKeychainItem_shouldReturnNil
{
    NSString *sharedAccessGroup = [self keychainGroup:YES];

    // Delete dummy key-value, if any exists before
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:dummyKeyIdendetifier accessGroup:sharedAccessGroup];

    NSString *keyData = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:dummyKeyIdendetifier context:nil error:nil];
    XCTAssertNil(keyData);
}

#pragma mark - iOS WPJ tests

#if TARGET_OS_IPHONE
- (void)testGetWPJKeysWithTenantId_whenWPJMissing_shouldReturnNil
{
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andTenantIdMatches_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andTenantIdMismatches_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId2" writeTenantMetadata:YES certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdWritten_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdRequested_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:nil writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdRequestedNotWritten_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:nil writeTenantMetadata:NO certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenMultipleWPJInLegacyAndDefaultFormat_andMatchingDefaultOne_shouldReturnDefaultRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId1" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant3CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId2" context:nil];
    XCTAssertNotNil(result);
    
    NSString *expectedIssuer = [kDummyTenant3CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedIssuer, result.certificateSubject);
}

- (void)testGetWPJKeysWithTenantId_whenMultipleWPJInDefaultFormat_andLegacyRegistration_withMismatchingTenant_shouldReturnLegacyRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"contoso" writeTenantMetadata:NO certIdentifier:kDummyTenant3CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId1" writeTenantMetadata:NO certIdentifier:kDummyTenant1CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDAssymetricKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId3" context:nil];
    XCTAssertNotNil(result);
    NSString *expectedIssuer = [kDummyTenant3CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedIssuer, result.certificateSubject);
}
#endif

#pragma mark - Helpers

- (void)cleanWPJ:(NSString *)keychainGroup
{
    NSArray *deleteClasses = @[(__bridge id)(kSecClassKey), (__bridge id)(kSecClassCertificate), (__bridge id)(kSecClassGenericPassword)];
    
    for (NSString *deleteClass in deleteClasses)
    {
        NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
        [deleteQuery setObject:deleteClass forKey:(__bridge id)kSecClass];
    #if TARGET_OS_IOS
        [deleteQuery setObject:keychainGroup forKey:(__bridge id)kSecAttrAccessGroup];
    #endif
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

- (OSStatus)insertDummyDRSIdentityIntoKeychain:(SecCertificateRef)certRef
                                 privateKeyRef:(SecKeyRef)privateKeyRef
                                 privateKeyTag:(NSString *)privateKeyTag
                                   accessGroup:(NSString *)accessGroup
{
    OSStatus status = noErr;
    
    status = [self insertKeyIntoKeychain:privateKeyRef
                           privateKeyTag:privateKeyTag
                             accessGroup:accessGroup];
    if (status != noErr)
    {
        return status;
    }
    
    return [self insertCertIntoKeychain:certRef
                            accessGroup:accessGroup
                          publicKeyHash:nil];
}

- (OSStatus)insertKeyIntoKeychain:(SecKeyRef)keyRef
                    privateKeyTag:(NSString *)keyTag
                      accessGroup:(NSString *)accessGroup
{
    NSMutableDictionary *keyInsertQuery = [[NSMutableDictionary alloc] init];
    [keyInsertQuery setObject:(__bridge id)(kSecClassKey) forKey:(__bridge id)kSecClass];
    [keyInsertQuery setObject:(__bridge id)(keyRef) forKey:(__bridge id)kSecValueRef];
    [keyInsertQuery setObject:[NSData dataWithBytes:[keyTag UTF8String] length:keyTag.length] forKey:(__bridge id)kSecAttrApplicationTag];

#if TARGET_OS_IOS
    [keyInsertQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif
    return SecItemAdd((__bridge CFDictionaryRef)keyInsertQuery, nil);
}

- (OSStatus)insertCertIntoKeychain:(SecCertificateRef)certRef
                       accessGroup:(NSString *)accessGroup
                     publicKeyHash:(NSData *)publicKeyHash
{
    NSMutableDictionary *certInsertQuery = [[NSMutableDictionary alloc] init];
    [certInsertQuery setObject:(__bridge id)(kSecClassCertificate) forKey:(__bridge id)kSecClass];
    [certInsertQuery setObject:(__bridge id)(certRef) forKey:(__bridge id)kSecValueRef];
#if TARGET_OS_IOS
    [certInsertQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#else
    //For MacOS new getWorkPlaceJoinKeyObj queries certificate reference using publicKeyHash (applicationLabel) retrieved from the private key dictionary
    [certInsertQuery setObject:publicKeyHash forKey:(__bridge id)kSecAttrPublicKeyHash];
#endif
    return SecItemAdd((__bridge CFDictionaryRef)certInsertQuery, NULL);
}

- (SecCertificateRef)dummyCertRef:(NSString *)certIdentifier
{
    NSString *drsIssuedCertificate = [self dummyCertificate:certIdentifier];
    NSData *certData = [NSData msidDataFromBase64UrlEncodedString:drsIssuedCertificate];
    return SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certData));
}

- (NSString *)dummyCertificate:(NSString *)certIdentifier
{
    return [NSString stringWithFormat: @"MIIEAjCCAuqgAwIBAgIQFc8t8z6QDoBGW1z8UDN+0zANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTE5MDgyOTIwMjU1NloXDTI5MDgyOTIwNTU1NlowLzEtMCsGA1UEAxMk%@MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABo4HQMIHNMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwDgYDVR0PAQH/BAQDAgeAMCIGCyqGSIb3FAEFghwCBBMEgRA78+WeSZfnQ5VngxjqQSVLMCIGCyqGSIb3FAEFghwDBBMEgRBP+CztBI6eSJZu39covAlhMCIGCyqGSIb3FAEFghwFBBMEgRCS4qJehkWISIVqoGYSGf2rMBQGCyqGSIb3FAEFghwIBAUEgQJOQTATBgsqhkiG9xQBBYIcBwQEBIEBMDANBgkqhkiG9w0BAQsFAAOCAQEAn6nzvuRd1moZ78aNfaZwFlxJx9ycNQNHRVljw4/Asqc9X2ySq4vE+f3zpqq2Q0c6lZ/yykb0KmZXeqWgyRK82uR48gWNAVvbPJr4l6B2cnTHAwkc+PLmADr7sE2WgBGH3uSqMcDKSbE/VpH3zOAnxeC8RByy/EEvGdC3YasjR9IGL4sSkyLHrZNO6Pz7oApL/BA713xJcp+EkzDIFF09JILuP1IANz8uW26GyNLBtBfdulKbbzv1i0tWMukN+s8upm9mWJyn8hXmz/LUa5NQtP0mBrRbw1d7NXPOgO54dr+DPpKZxrQw6zpwCJ/waeKIJjHAIDAF6h1BjFCaAulhJA==", certIdentifier];
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

- (NSString *)keychainGroup:(BOOL)useLegacyFormat
{
#if TARGET_OS_IPHONE
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];
    XCTAssertNotNil(teamId);

    if (useLegacyFormat)
    {
        return [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    }
    
    return [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", teamId];
#else
    return nil;
#endif
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

@end
