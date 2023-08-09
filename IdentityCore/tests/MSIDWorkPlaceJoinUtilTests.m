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
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "MSIDRequestParameters.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDTestSwizzle.h"
#import "MSIDWorkPlaceJoinUtilBase+Internal.h"
#import "MSIDWPJMetadata.h"

@interface MSIDWorkPlaceJoinUtilTests : XCTestCase
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *eccKeyGenerator;
@property (nonatomic) BOOL useIosStyleKeychain;
@end

NSString * const dummyKeyIdendetifier = @"com.microsoft.workplacejoin.dummyKeyIdentifier";
NSString * const dummyKeyV2Idendeifier = @"com.microsoft.workplacejoin.v2.dummyKeyIdentifier";

// WPJ test values
NSString *dummyKeyIdentifierValue1 = @"dummyupn@microsoft.com";
NSString *dummyKeyTenantValue1 = @"72f988bf-86f1-41af-91ab-2d7cd011db47";

NSString *dummyKeyIdentifierValue2 = @"dummyupn@m365x957144.onmicrosoft.com";
NSString *dummyKeyTenantValue2 = @"ef5e032c-f4cf-4d87-a328-286ff45dc5b0";

NSString *dummyKeyIdentifierValue3 = @"dummyupn@m365x193839.onmicrosoft.com";
NSString *dummyKeyTenantValue3 = @"5ac3f3c6-e654-4968-a4c7-f2a7e4bde783";

static NSString *kDummyTenant1CertIdentifier = @"OWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant2CertIdentifier = @"OWZmNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";
static NSString *kDummyTenant3CertIdentifier = @"NmFhNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi";


@implementation MSIDWorkPlaceJoinUtilTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    // Setting use iOS style keychain to true by default. Set it to NO in test cases that require ACL.
    self.useIosStyleKeychain = YES;
#if TARGET_OS_OSX
    self.useIosStyleKeychain = NO;
#endif
}

- (void)tearDown
{
    if (self.useIosStyleKeychain)
    {
        [self cleanWPJ:[self keychainGroup:YES]];
        [self cleanWPJ:[self keychainGroup:NO]];
    }
}

#pragma mark Fetch Legacy and default registration tests
// For now enabling these tests only on iOS. When CI/CD can be configured with specific mac instance & that instance is added to provisioned profiles, we should enable these for macOS
#if TARGET_OS_IOS
- (void)testGetWPJKeysWithTenantId_whenWPJMissing_shouldReturnNil
{
#if TARGET_OS_OSX
    self.useIosStyleKeychain = NO;
#endif
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyWithDifferentTenant_shouldReturnLegacy
{
#if TARGET_OS_OSX
    self.useIosStyleKeychain = NO;
#endif
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId1" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV1);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyWithSameTenant_shouldReturnLegacy
{
#if TARGET_OS_OSX
    self.useIosStyleKeychain = NO;
#endif
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV1);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInDefaultWithDifferentTenant_shouldReturnNil
{
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId1" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInDefaultWithSameTenant_EccBasedRegNoSecureEnclave_shouldReturnDefault
{
    [self insertDummyEccRegistrationForTenantIdentifier:@"tenantId" certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:NO];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    CFStringRef cName = NULL;
    SecCertificateCopyCommonName(result.certificateRef, &cName);
    NSString *certId = [[NSString alloc] initWithData:[NSData msidDataFromBase64UrlEncodedString:kDummyTenant1CertIdentifier] encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(CFBridgingRelease(cName), certId);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInDefaultWithSameTenant_EccBasedRegUsingSecureEnclave_shouldReturnDefault
{
    [self insertDummyEccRegistrationForTenantIdentifier:@"tenantId" certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion, MSIDWPJKeychainAccessGroupV2);
    CFStringRef cName = NULL;
    SecCertificateCopyCommonName(result.certificateRef, &cName);
    NSString *certId = [[NSString alloc] initWithData:[NSData msidDataFromBase64UrlEncodedString:kDummyTenant1CertIdentifier] encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(CFBridgingRelease(cName), certId);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInDefaultWithDifferentTenant_EccBasedRegNoSecureEnclave_shouldReturnNil
{
    [self insertDummyEccRegistrationForTenantIdentifier:@"tenantId1" certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:NO];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInDefaultWithDifferentTenant_EccBasedRegUsingSecureEnclave_shouldReturnNil
{
    [self insertDummyEccRegistrationForTenantIdentifier:@"tenantId1" certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertNil(result);
}
#endif
- (void)testGetRegistrationInformation_withoutRegistrationInformation_andNoChallenge_shoudReturnNil
{
    MSIDRegistrationInformation *registrationInfo = [MSIDWorkPlaceJoinUtil getRegistrationInformation:nil workplacejoinChallenge:nil];
    XCTAssertNil(registrationInfo);
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

- (void)testGetWPJStringDataForIdentifier_withKeychainV2Item_shouldReturnValidValue
{
#if TARGET_OS_MAC
    XCTSkip(@"Skip keychain tests on MacOS since they conflict with production records.");
#endif
    
    NSString *sharedAccessGroup = [self keychainGroup:NO];

    // Insert dummy UPN value.
    [MSIDWorkPlaceJoinUtilTests insertDummyStringUPNDataIntoKeychainV2:dummyKeyIdentifierValue1 tenantIdentifier:dummyKeyTenantValue1 dataIdentifier:dummyKeyV2Idendeifier accessGroup:sharedAccessGroup];
    NSString *formattedKeyForUPN = (__bridge NSString *)kSecAttrLabel;
    NSString *formattedKeyForTenantId = (__bridge NSString *)kSecAttrService;
    NSString *upnData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1 identifier:dummyKeyIdentifierValue1 key:formattedKeyForUPN context:nil error:nil];
    NSString *tenantData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1  identifier:dummyKeyIdentifierValue1 key:formattedKeyForTenantId context:nil error:nil];

    XCTAssertNotNil(upnData1);
    XCTAssertNotNil(tenantData1);
    XCTAssertEqual([dummyKeyIdentifierValue1 isEqualToString: upnData1], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue1");
    XCTAssertEqual([dummyKeyTenantValue1 isEqualToString: tenantData1], TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue1");

    // Cleanup
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:kMSIDUPNKeyIdentifier accessGroup:sharedAccessGroup];
}

- (void)testGetWPJStringDataForIdentifier_withKeychainItemV2_shouldReturnValidValue_WithMultipleEntries
{
#if TARGET_OS_MAC
    XCTSkip(@"Skip keychain tests on MacOS since they conflict with production records.");
#endif
    
    NSString *sharedAccessGroup = [self keychainGroup:NO];
    
    // Insert dummy UPN values
    [MSIDWorkPlaceJoinUtilTests insertDummyStringUPNDataIntoKeychainV2:dummyKeyIdentifierValue1 tenantIdentifier:dummyKeyTenantValue1 dataIdentifier:dummyKeyV2Idendeifier accessGroup:sharedAccessGroup];
    [MSIDWorkPlaceJoinUtilTests insertDummyStringUPNDataIntoKeychainV2:dummyKeyIdentifierValue2 tenantIdentifier:dummyKeyTenantValue2 dataIdentifier:dummyKeyV2Idendeifier accessGroup:sharedAccessGroup];

    NSString *formattedKeyForUPN = (__bridge NSString *)kSecAttrLabel;
    NSString *formattedKeyForTenantId = (__bridge NSString *)kSecAttrService;
    NSString *upnData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1 identifier:dummyKeyIdentifierValue1 key:formattedKeyForUPN context:nil error:nil];
    NSString *tenantData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1  identifier:dummyKeyIdentifierValue1 key:formattedKeyForTenantId context:nil error:nil];
    
    NSString *upnData2 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue2 identifier:dummyKeyIdentifierValue2 key:formattedKeyForUPN context:nil error:nil];
    NSString *tenantData2 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue2  identifier:dummyKeyIdentifierValue2 key:formattedKeyForTenantId context:nil error:nil];

    XCTAssertNotNil(upnData1);
    XCTAssertNotNil(tenantData1);
    XCTAssertNotNil(upnData2);
    XCTAssertNotNil(tenantData2);
   
    XCTAssertEqual([dummyKeyIdentifierValue1 isEqualToString: upnData1], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue1");
   XCTAssertEqual([dummyKeyTenantValue1 isEqualToString: tenantData1], TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue1");
    XCTAssertEqual([dummyKeyIdentifierValue2 isEqualToString: upnData2], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue2");
    XCTAssertEqual([dummyKeyTenantValue2 isEqualToString: tenantData2], TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue2");

   // Cleanup
   [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:kMSIDUPNKeyIdentifier accessGroup:sharedAccessGroup];
}

- (void)testGetWPJStringDataForIdentifierV2_withKeychainItem_shouldReturnValidValueDepiteMultipleEntriesInV1AndV2
{
#if TARGET_OS_MAC
    XCTSkip(@"Skip keychain tests on MacOS since they conflict with production records.");
#endif
    
    NSString *dummyKeyIdentifierValue = @"dummyupn@dummytenant.com";
    NSString *sharedAccessGroup = [self keychainGroup:YES];

    // Insert dummy UPN value.
    [MSIDWorkPlaceJoinUtilTests insertDummyStringDataIntoKeychain:dummyKeyIdentifierValue dataIdentifier:dummyKeyIdendetifier accessGroup:sharedAccessGroup];


    NSString *upnData = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:dummyKeyIdendetifier context:nil error:nil];
    XCTAssertNotNil(upnData);
    XCTAssertEqual([dummyKeyIdentifierValue isEqualToString: upnData], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue");
    
    // Insert dummy WPJ metadat valus in keychain V2
    sharedAccessGroup = [self keychainGroup:NO];
    [MSIDWorkPlaceJoinUtilTests insertDummyStringUPNDataIntoKeychainV2:dummyKeyIdentifierValue1 tenantIdentifier:dummyKeyTenantValue1 dataIdentifier:dummyKeyV2Idendeifier accessGroup:sharedAccessGroup];
    [MSIDWorkPlaceJoinUtilTests insertDummyStringUPNDataIntoKeychainV2:dummyKeyIdentifierValue2 tenantIdentifier:dummyKeyTenantValue2 dataIdentifier:dummyKeyV2Idendeifier accessGroup:sharedAccessGroup];

    NSString *formattedKeyForUPN = (__bridge NSString *)kSecAttrLabel;
    NSString *formattedKeyForTenantId = (__bridge NSString *)kSecAttrService;
    NSString *upnData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1 identifier:dummyKeyIdentifierValue1 key:formattedKeyForUPN context:nil error:nil];
    NSString *tenantData1 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue1  identifier:dummyKeyIdentifierValue1 key:formattedKeyForTenantId context:nil error:nil];
    
    NSString *upnData2 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue2 identifier:dummyKeyIdentifierValue2 key:formattedKeyForUPN context:nil error:nil];
    NSString *tenantData2 = [MSIDWorkPlaceJoinUtil getWPJStringDataFromV2ForTenantId:dummyKeyTenantValue2  identifier:dummyKeyIdentifierValue2 key:formattedKeyForTenantId context:nil error:nil];

    XCTAssertNotNil(upnData1);
    XCTAssertNotNil(tenantData1);
    XCTAssertNotNil(upnData2);
    XCTAssertNotNil(tenantData2);
    XCTAssertEqual([dummyKeyIdentifierValue1 isEqualToString: upnData1], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue");
    XCTAssertEqual([dummyKeyTenantValue1 isEqualToString: tenantData1], TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertEqual([dummyKeyIdentifierValue2 isEqualToString: upnData2], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue");
    XCTAssertEqual([dummyKeyTenantValue2 isEqualToString: tenantData2], TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");

    // Cleanup
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:kMSIDUPNKeyIdentifier accessGroup:sharedAccessGroup];
    sharedAccessGroup = [self keychainGroup:YES];
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

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_withMetadataNil_shouldReturnNil
{
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.validateAuthority = YES;
    
    [MSIDTestSwizzle classMethod:@selector(getPrimaryEccTenantWithSharedAccessGroup:context:error:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *sharedAccessGroup, __unused id <MSIDRequestContext> context, __unused NSError **error)
    {
        return @"PrimaryTenantId";
    }];
    
    [MSIDTestSwizzle classMethod:@selector(readWPJMetadataWithSharedAccessGroup:tenantIdentifier:domainName:context:error:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *sharedAccessGroup,
                                        __unused NSString *tenantIdentifier,
                                        __unused NSString *domainName,
                                        __unused id <MSIDRequestContext> context,
                                        __unused NSError **error)
    {
        return nil;
    }];
   
    
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *tenantId, __unused id <MSIDRequestContext> context)
    {
        return nil;
    }];
    
    NSDictionary *deviceRegMetaDataInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:requestParams tenantId:nil usePrimaryFormat:YES];
    XCTAssertNil(deviceRegMetaDataInfo);
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_withMetadataQueryErrorButValidMetadata_shouldReturnNil
{
    
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.validateAuthority = YES;
    
    [MSIDTestSwizzle classMethod:@selector(getPrimaryEccTenantWithSharedAccessGroup:context:error:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *sharedAccessGroup, __unused id <MSIDRequestContext> context, __unused NSError **error)
    {
        return @"PrimaryTenantId";
    }];
    
    [MSIDTestSwizzle classMethod:@selector(readWPJMetadataWithSharedAccessGroup:tenantIdentifier:domainName:context:error:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *sharedAccessGroup,
                                        __unused NSString *tenantIdentifier,
                                        __unused NSString *domainName,
                                        __unused id <MSIDRequestContext> context,
                                        NSError **error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Error reading metadata", nil, nil, nil, nil, nil, NO);
        MSIDWPJMetadata *metadata = [MSIDWPJMetadata new];
        return metadata;
    }];
    
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId1" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    MSIDWPJKeyPairWithCert *keyPairWithCert = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    keyPairWithCert.keyChainVersion = MSIDWPJKeychainAccessGroupV2;
    
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *tenantId, __unused id <MSIDRequestContext> context)
    {
        return keyPairWithCert;
    }];
    
    NSDictionary *deviceRegMetaDataInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:requestParams tenantId:nil usePrimaryFormat:YES];
    XCTAssertNil(deviceRegMetaDataInfo);
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_withPrimaryEccTenantNil_shouldReturnNil
{
    
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.validateAuthority = YES;
    
    [MSIDTestSwizzle classMethod:@selector(getPrimaryEccTenantWithSharedAccessGroup:context:error:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *sharedAccessGroup, __unused id <MSIDRequestContext> context, __unused NSError **error)
    {
        return nil;
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id) ^(__unused id obj, __unused NSString *tenantId, __unused id <MSIDRequestContext> context)
    {
        return nil;
    }];

    NSDictionary *deviceRegMetaDataInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:requestParams tenantId:nil usePrimaryFormat:YES];
    XCTAssertNil(deviceRegMetaDataInfo);
}

#pragma mark - iOS WPJ tests

#if TARGET_OS_IPHONE

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andTenantIdMatches_shouldReturnRegistrationV2
{
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV2, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andTenantIdMatches_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andTenantIdMismatches_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId2" writeTenantMetadata:YES certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdWritten_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdRequested_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:nil writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenWPJInLegacyFormat_andNoTenantIdRequestedNotWritten_shouldReturnRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:nil writeTenantMetadata:NO certIdentifier:kDummyTenant1CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
}

- (void)testGetWPJKeysWithTenantId_whenMultipleWPJInLegacyAndDefaultFormat_andMatchingDefaultOne_shouldReturnDefaultRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"tenantId1" writeTenantMetadata:YES certIdentifier:kDummyTenant1CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant3CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId2" context:nil];
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV2, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    XCTAssertNotNil(result);
    
    NSString *expectedSubject = [kDummyTenant3CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedSubject, result.certificateSubject);
}

- (void)testGetWPJKeysWithTenantId_whenMultipleWPJInDefaultFormat_andLegacyRegistration_withMismatchingTenant_shouldReturnLegacyRegistration
{
    [self insertDummyWPJInLegacyFormat:YES tenantIdentifier:@"contoso" writeTenantMetadata:NO certIdentifier:kDummyTenant3CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId1" writeTenantMetadata:NO certIdentifier:kDummyTenant1CertIdentifier];
    [self insertDummyWPJInLegacyFormat:NO tenantIdentifier:@"tenantId2" writeTenantMetadata:NO certIdentifier:kDummyTenant2CertIdentifier];
    
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:@"tenantId3" context:nil];
    XCTAssertNotNil(result);
    // Returns WPJ entry, so V1 is expected
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV1, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    NSString *expectedSubject = [kDummyTenant3CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedSubject, result.certificateSubject);
}

- (void)testGetWPJKeysWithNilTenantId_WithSecureEnclave_shouldReturnPrimaryRegistration
{
    [self addPrimaryEccDefaultRegistrationForTenantId:@"primaryTenantId" sharedAccessGroup:[self keychainGroup:NO] certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:YES];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:nil context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV2, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    NSString *expectedSubject = [kDummyTenant1CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedSubject, result.certificateSubject);
}

- (void)testGetWPJKeysWithNilTenantId_WithNoSecureEnclave_shouldReturnPrimaryRegistration
{
    [self addPrimaryEccDefaultRegistrationForTenantId:@"primaryTenantId" sharedAccessGroup:[self keychainGroup:NO] certIdentifier:kDummyTenant1CertIdentifier useSecureEnclave:NO];
    MSIDWPJKeyPairWithCert *result = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:nil context:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.keyChainVersion == MSIDWPJKeychainAccessGroupV2, TRUE, "Expected registrationInfo.tenantID to be same as test dummyKeyTenantValue");
    NSString *expectedSubject = [kDummyTenant1CertIdentifier msidBase64UrlDecode];
    XCTAssertEqualObjects(expectedSubject, result.certificateSubject);
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
        if (self.useIosStyleKeychain)
        {
#if TARGET_OS_OSX
        if (@available(macOS 10.15, *))
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
        if (@available(macOS 10.15, *))
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
        if (@available(macOS 10.15, *))
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
    if (@available(macOS 10.15, *)) {
        query[(__bridge id <NSCopying>) (kSecUseDataProtectionKeychain)] = @YES;
    }
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

@end
