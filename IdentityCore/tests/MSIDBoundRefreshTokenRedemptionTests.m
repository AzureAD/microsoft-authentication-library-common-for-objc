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
#if TARGET_OS_IPHONE
#import <XCTest/XCTest.h>
#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshToken+Redemption.h"
#import "MSIDBoundRefreshTokenRedemptionParameters.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDEcdhApv.h"
#import "MSIDJWECrypto.h"
#import "MSIDJWTHelper.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestSecureEnclaveKeyPairGenerator.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDKeychainUtil.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTestSwizzle.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDFlightManagerMockProvider.h"
#import "MSIDConstants.h"
#import "MSIDRegistrationInformationMock.h"

@interface MSIDBoundRefreshTokenRedemptionTests : XCTestCase
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *deviceKeyGenerator;
@property (nonatomic) MSIDTestSecureEnclaveKeyPairGenerator *transportKeyGenerator;
@property (nonatomic) NSString *tenantId;
@property (nonatomic) NSString *deviceKeyTag;
@property (nonatomic) NSString *transportKeyTag;
@property (nonatomic) NSString *accessGroup;
@property (nonatomic) NSString *deviceId;
@end

static const NSString *kAuthorityUrl = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";

@implementation MSIDBoundRefreshTokenRedemptionTests

- (void)setUp
{
    [super setUp];
    [self cleanUpWpjInformation];
    self.tenantId = NSUUID.UUID.UUIDString;
    self.accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    self.deviceKeyTag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateKeyIdentifier, self.tenantId, @"-EC"];
    self.transportKeyTag = [NSString stringWithFormat:@"%@#%@%@", kMSIDPrivateTransportKeyIdentifier, self.tenantId, @"-EC"];
    self.deviceKeyGenerator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:self.accessGroup useSecureEnclave:YES applicationTag:self.deviceKeyTag];
    self.transportKeyGenerator = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:self.accessGroup useSecureEnclave:YES applicationTag:self.transportKeyTag];
    self.deviceId = @"9ee5f33b-9749-43e7-9567-8318ea41254b";
    MSIDFlightManagerMockProvider *flightProvider = [MSIDFlightManagerMockProvider new];
    flightProvider.boolForKeyContainer = @{ MSID_FLIGHT_ENABLE_QUERYING_STK: @YES };
    MSIDFlightManager.sharedInstance.flightProvider = flightProvider;
}

- (void)tearDown
{
    [super tearDown];
    self.deviceKeyGenerator = nil;
    self.transportKeyGenerator = nil;
    self.tenantId = nil;
    [self cleanUpWpjInformation];
    [MSIDTestSwizzle reset];
}

#pragma mark - Redeeming Bound Refresh Token Tests

- (void)testGetTokenRedemptionJwt_whenRequestParametersNil_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    MSIDBoundRefreshTokenRedemptionParameters *params = nil;
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:@"tenant123"
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Request parameters for bound refresh token redemption are nil"]);
}

- (void)testGetTokenRedemptionJwt_whenBoundDeviceIdNil_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    NSString *nilDeviceId = nil;
    token.boundDeviceId = nilDeviceId;
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params = [[MSIDBoundRefreshTokenRedemptionParameters alloc]
                                                         initWithClientId:@"client123"
                                                        authorityEndpoint:[NSURL URLWithString:(NSString*)kAuthorityUrl]
                                                                   scopes:[NSSet setWithObject:@"scope1"]
                                                                    nonce:@"nonce123"
                                                         extraPayloadClaims:nil
                                                         workplaceJoinInfo:wpjInfo];
    XCTAssertNotNil(params);
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:@"tenant123"
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Bound device ID for bound refresh token is nil or blank"]);
}

- (void)testGetTokenRedemptionJwt_whenBoundDeviceIdWhitespace_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    token.boundDeviceId = @"   ";

    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:@"tenant123"
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testGetTokenRedemptionJwt_whenWorkplaceJoinDataNil_shouldNotReturnNil
{
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];
    XCTAssertNotNil(params);
}

- (void)testGetTokenRedemptionJwt_whenBoundDeviceIdMismatch_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    token.boundDeviceId = @"device_id_from_token";
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Bound device ID does not match device ID from WPJ keys"]);
}

- (void)testGetTokenRedemptionJwt_whenPrivateKeyRefNil_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    [self cleanUpTransportKey];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorWorkplaceJoinRequired);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Failed to obtain private transport key for bound RT redemption JWT."]);
}

- (void)testGetTokenRedemptionJwt_whenEcdhApvCreationFails_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];

    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    [MSIDTestSwizzle instanceMethod:@selector(initWithKey:apvPrefix:customClientNonce:context:error:)
                           class:MSIDEcdhApv.class
                           block:^(void)
    {
        return nil;
    }];
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Failed to create ECDH APV data for bound RT redemption JWT."]);
}

- (void)testGetTokenRedemptionJwt_whenJWTSigningFails_shouldReturnNilAndSetError
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];


    NSError *error;
    MSIDJWECrypto *jweCrypto;
    [MSIDTestSwizzle classMethod:@selector(createSignedJWTforHeader:payload:signingKey:)
                           class:MSIDJWTHelper.class
                           block:^(void)
    {
        return nil;
    }];
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Failed to sign JWT for bound RT redemption"]);
}

- (void)testGetTokenRedemptionJwt_withValidParameters_shouldSucceed
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObjects:@"scope1", @"scope2", nil]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                  tokenRedemptionParameters:params
                                                    context:nil
                                                  jweCrypto:&jweCrypto
                                                      error:&error];
    
    XCTAssertNotNil(jwt);
    XCTAssertNil(error);
    XCTAssertNotNil(jweCrypto);
    [self validateJwtValidity:jwt params:params refreshToken:token.refreshToken];
}

- (void)testGetTokenRedemptionJwt_withNonSecureEnclaveBackedRegistration_shouldFail
{
    MSIDBoundRefreshToken *token = [self createToken];
    MSIDRegistrationInformationMock *regInfo = [MSIDRegistrationInformationMock new];
    regInfo.isWorkPlaceJoinedFlag = YES;
    [regInfo setCertificateSubject:self.deviceId];
    MSIDTestSecureEnclaveKeyPairGenerator *dkGen = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:self.accessGroup useSecureEnclave:NO applicationTag:self.deviceKeyTag];
    MSIDTestSecureEnclaveKeyPairGenerator *stkGen = [[MSIDTestSecureEnclaveKeyPairGenerator alloc] initWithSharedAccessGroup:self.accessGroup useSecureEnclave:NO applicationTag:self.transportKeyTag];
    [regInfo setPrivateKey:dkGen.eccPrivateKey];
    [regInfo setPrivateTransportKey:stkGen.eccPrivateKey];
    [regInfo setCertificateIssuer:@"82dbaca4-3e81-46ca-9c73-0950c1eaca97"];

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObjects:@"scope1", @"scope2", nil]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:regInfo];
    
    XCTAssertFalse(dkGen.eccPrivateKey == NULL);
    XCTAssertFalse(stkGen.eccPrivateKey == NULL);
    
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:MSIDWorkPlaceJoinUtil.class
                           block:^(void)
    {
        NSData *mockCertData = [NSData msidDataFromBase64UrlEncodedString:[self dummyEccCertificate]];
        SecCertificateRef mockCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)mockCertData);
        MSIDWPJKeyPairWithCert *wpjKeys = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:dkGen.eccPrivateKey certificate:mockCert certificateIssuer:@"some-issuer"];
        [wpjKeys initializePrivateTransportKeyRef:stkGen.eccPrivateKey];
        return wpjKeys;
    }];
    
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                  tokenRedemptionParameters:params
                                                    context:nil
                                                  jweCrypto:&jweCrypto
                                                      error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"The private device key for bound RT redemption JWT is not from Secure Enclave. Binding will not be satisfied."]);
}

- (void)testGetTokenRedemptionJwt_errorPassedAsNil_shouldNotCrash
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];

    MSIDJWECrypto *jweCrypto;
    NSError *error;
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNotNil(jwt);
    // Should not crash when error is nil
}

- (void)testGetTokenRedemptionJwt_jweCryptoPassedAsNil_shouldSucceed
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    NSError *error;
    MSIDJWECrypto *jweCrypto = NULL;
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNotNil(jwt);
    XCTAssertNil(error);
    XCTAssertNotNil(jweCrypto);
    XCTAssertTrue([jweCrypto isKindOfClass:[MSIDJWECrypto class]]);
}

- (void)testGetTokenRedemptionJwt_jweCryptoCouldNotBeConstructed_shouldReturnError
{
    MSIDBoundRefreshToken *token = [self createToken];
    [self insertWorkPlaceJoinInformation];
    MSIDWPJKeyPairWithCert *wpjInfo = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:self.tenantId context:nil];
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:@"client123"
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:[NSSet setWithObject:@"scope1"]
                        nonce:@"nonce123"
         extraPayloadClaims:nil
         workplaceJoinInfo:wpjInfo];
    NSError *error;
    MSIDJWECrypto *jweCrypto;
    
    [MSIDTestSwizzle instanceMethod:@selector(initWithKeyExchangeAlg:encryptionAlgorithm:apv:context:error:)
                           class:MSIDJWECrypto.class
                           block:^(void)
    {
        return nil;
    }];
    
    NSString *jwt = [token getTokenRedemptionJwtForTenantId:self.tenantId
                                 tokenRedemptionParameters:params
                                                   context:nil
                                                 jweCrypto:&jweCrypto
                                                     error:&error];
    
    XCTAssertNil(jwt);
    XCTAssertNotNil(error);
    // Should not crash when jweCrypto is nil
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"Failed to create JWE crypto for bound RT redemption JWT."]);
}


#pragma mark - MSIDBoundRefreshTokenRedemptionParameters Tests

- (void)testInitWithClientId_whenValidParameters_shouldInitializeCorrectly
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObjects:@"scope1", @"scope2", nil];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
    extraPayloadClaims:nil
    workplaceJoinInfo:nil];

    XCTAssertNotNil(params);
    XCTAssertEqualObjects(params.clientId, clientId);
    XCTAssertEqualObjects(params.scopes, scopes);
    XCTAssertEqualObjects(params.nonce, nonce);
}

- (void)testInitWithClientId_whenClientIdNil_shouldReturnNil
{
    NSString *clientId = nil;
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];


    XCTAssertNil(params);
}

- (void)testInitWithNotAuthority_shouldReturnNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";
    NSURL *nilAuthority;
    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:nilAuthority
                       scopes:scopes
                        nonce:nonce
           extraPayloadClaims:nil
            workplaceJoinInfo:nil];


    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenClientIdEmpty_shouldReturnNil
{
    NSString *clientId = @"";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
           extraPayloadClaims:nil
            workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenClientIdWhitespace_shouldReturnNil
{
    NSString *clientId = @"   ";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
           extraPayloadClaims:nil
            workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenScopesNil_shouldReturnNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = nil;
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenScopesEmpty_shouldReturnNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet set];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenNonceNil_shouldNotReturnNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = nil;

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNotNil(params);
}

- (void)testInitWithClientId_whenNonceEmpty_shouldReturnNotNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNotNil(params);
}

- (void)testInitWithClientId_whenClientIdTabCharacters_shouldReturnNil
{
    NSString *clientId = @"\t\t";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenClientIdNewlineCharacters_shouldReturnNil
{
    NSString *clientId = @"\n\n";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testInitWithClientId_whenNonceNewlineCharacters_shouldNotReturnNil
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"\n\n";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNotNil(params);
}

- (void)testInitWithClientId_whenMixedWhitespace_shouldReturnNil
{
    NSString *clientId = @" \t\n ";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @" \t\n ";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    XCTAssertNil(params);
}

- (void)testJsonDictionary_whenValidParameters_shouldReturnCorrectDictionary
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObjects:@"scope1", @"scope2", nil];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    XCTAssertNotNil(jsonDict);
    XCTAssertEqualObjects(jsonDict[MSID_OAUTH2_GRANT_TYPE], MSID_OAUTH2_REFRESH_TOKEN);
    XCTAssertEqualObjects(jsonDict[@"bound_rt_exchange"], @1);
    XCTAssertEqualObjects(jsonDict[@"iss"], clientId);
    XCTAssertEqualObjects(jsonDict[MSID_OAUTH2_CLIENT_ID], clientId);
    XCTAssertEqualObjects(jsonDict[@"nonce"], nonce);
    
    // Verify scope string contains both scopes
    NSString *scopeString = jsonDict[MSID_OAUTH2_SCOPE];
    XCTAssertTrue([scopeString containsString:@"scope1"]);
    XCTAssertTrue([scopeString containsString:@"scope2"]);
    
    // Verify time fields are present
    XCTAssertNotNil(jsonDict[@"iat"]);
    XCTAssertNotNil(jsonDict[@"exp"]);
    XCTAssertNotNil(jsonDict[@"nbf"]);
}

- (void)testJsonDictionary_whenSingleScope_shouldReturnCorrectScopeString
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"single-scope"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    XCTAssertEqualObjects(jsonDict[MSID_OAUTH2_SCOPE], @"single-scope");
}

- (void)testJsonDictionary_timeFields_shouldHaveCorrectValues
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";
    
    NSDate *beforeCreation = [[NSDate date] dateByAddingTimeInterval:-1]; // 1 second buffer

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSDate *afterCreation = [[NSDate date] dateByAddingTimeInterval:1]; // 1 second buffer
    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    // Verify iat (issued at time) is reasonable
    NSString *iatString = jsonDict[@"iat"];
    NSTimeInterval iat = [iatString doubleValue];
    XCTAssertTrue(iat >= [beforeCreation timeIntervalSince1970]);
    XCTAssertTrue(iat <= [afterCreation timeIntervalSince1970]);
    
    // Verify nbf (not before time) equals iat
    NSString *nbfString = jsonDict[@"nbf"];
    XCTAssertEqualObjects(iatString, nbfString);
    
    // Verify exp (expiration time) is 5 minutes after iat
    NSNumber *exp = jsonDict[@"exp"];
    NSTimeInterval expectedExp = iat + (5 * 60); // 5 minutes
    XCTAssertEqualWithAccuracy([exp doubleValue], expectedExp, 1.0); // Allow 1 second tolerance
}

- (void)testJsonDictionary_whenMultipleScopes_shouldJoinWithSpaces
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObjects:@"scope1", @"scope2", @"scope3", nil];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    NSString *scopeString = jsonDict[MSID_OAUTH2_SCOPE];
    
    // Verify all scopes are present and separated by spaces
    NSArray *scopeComponents = [scopeString componentsSeparatedByString:@" "];
    XCTAssertEqual(scopeComponents.count, 3);
    
    NSSet *scopeSet = [NSSet setWithArray:scopeComponents];
    XCTAssertEqualObjects(scopeSet, scopes);
}

- (void)testJsonDictionary_whenCalledMultipleTimes_shouldReturnFreshDictionary
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict1 = [params jsonDictionary];
    NSMutableDictionary *jsonDict2 = [params jsonDictionary];
    
    // Should be different instances but with same content
    XCTAssertNotEqual(jsonDict1, jsonDict2);
    
    // Modify one dictionary and verify the other is unchanged
    jsonDict1[@"test_key"] = @"test_value";
    XCTAssertNil(jsonDict2[@"test_key"]);
}

- (void)testJsonDictionary_verifyIfRequestedScopesAreEmpty_shouldFail
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet new];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];
    XCTAssertNil(params);
}

- (void)testJsonDictionary_verifyIfRequestedScopesHasAza_shouldFail
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObjects:@"scope1", @"aza", @"scope2", nil];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];
    XCTAssertNil(params);
}

- (void)testJsonDictionary_verifyAllRequiredFields_shouldBePresent
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    // Verify all expected keys are present
    NSArray *expectedKeys = @[
        MSID_OAUTH2_GRANT_TYPE,
        MSID_BOUND_RT_EXCHANGE,
        @"iss",
        @"iat",
        @"exp",
        @"nbf",
        MSID_OAUTH2_CLIENT_ID,
        @"nonce",
        MSID_OAUTH2_SCOPE
    ];
    
    for (NSString *key in expectedKeys) {
        XCTAssertNotNil(jsonDict[key], @"Key %@ should be present in JSON dictionary", key);
    }
}

- (void)testJsonDictionary_withLargeNumberOfScopes_shouldHandleCorrectly
{
    NSString *clientId = @"test-client-id";
    NSMutableSet *scopes = [NSMutableSet set];
    
    // Add 50 scopes to test performance and correctness
    for (int i = 0; i < 50; i++) {
        [scopes addObject:[NSString stringWithFormat:@"scope%d", i]];
    }
    
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    NSString *scopeString = jsonDict[MSID_OAUTH2_SCOPE];
    
    // Verify all scopes are present
    NSArray *scopeComponents = [scopeString componentsSeparatedByString:@" "];
    XCTAssertEqual(scopeComponents.count, 50);
    
    NSSet *scopeSet = [NSSet setWithArray:scopeComponents];
    XCTAssertEqualObjects(scopeSet, scopes);
}

- (void)testJsonDictionary_boundRefreshTokenExchangeValue_shouldBeNumberOne
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    // Verify the bound_refresh_token_exchange is exactly @1 (NSNumber with value 1)
    id boundExchangeValue = jsonDict[MSID_BOUND_RT_EXCHANGE];
    XCTAssertTrue([boundExchangeValue isKindOfClass:[NSNumber class]]);
    XCTAssertEqualObjects(boundExchangeValue, @1);
    XCTAssertEqual([boundExchangeValue intValue], 1);
}

- (void)testJsonDictionary_timeFieldTypes_shouldBeCorrectTypes
{
    NSString *clientId = @"test-client-id";
    NSSet *scopes = [NSSet setWithObject:@"scope1"];
    NSString *nonce = @"test-nonce";

    MSIDBoundRefreshTokenRedemptionParameters *params =
        [[MSIDBoundRefreshTokenRedemptionParameters alloc]
             initWithClientId:clientId
            authorityEndpoint:[NSURL URLWithString:(NSString *)kAuthorityUrl]
                       scopes:scopes
                        nonce:nonce
         extraPayloadClaims:nil
         workplaceJoinInfo:nil];

    NSMutableDictionary *jsonDict = [params jsonDictionary];
    
    // Verify iat and nbf are strings (converted from NSNumber)
    XCTAssertTrue([jsonDict[@"iat"] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue([jsonDict[@"nbf"] isKindOfClass:[NSNumber class]]);
    
    // Verify exp is NSNumber
    XCTAssertTrue([jsonDict[@"exp"] isKindOfClass:[NSNumber class]]);
}

#pragma mark - Helper methods
- (MSIDBoundRefreshToken *)createToken
{
    MSIDRefreshToken *refreshToken = [self createRefreshToken];
    MSIDBoundRefreshToken *boundToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:refreshToken boundDeviceId:self.deviceId];
    return boundToken;
}

- (MSIDRefreshToken *)createRefreshToken
{
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.utid"];
    
    token.refreshToken = @"refreshToken";
    token.environment = @"contoso.com";
    token.clientId = @"some clientId";
    token.accountIdentifier = accountIdentifier;
    token.familyId = @"family";
    
    return token;
}

- (OSStatus)insertWorkPlaceJoinInformation
{
    NSData *mockCertData = [NSData msidDataFromBase64UrlEncodedString:[self dummyEccCertificate]];
    SecCertificateRef mockCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)mockCertData);
    
    SecKeyRef transportKey = self.transportKeyGenerator.eccPrivateKey;
    SecKeyRef deviceKey = self.deviceKeyGenerator.eccPrivateKey;
    
    XCTAssertFalse(transportKey == NULL);
    XCTAssertFalse(deviceKey == NULL);
    
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    NSDictionary *attributes = (NSDictionary *)CFBridgingRelease(SecKeyCopyAttributes(deviceKey));
    
    NSMutableDictionary *certInsertQuery = [[NSMutableDictionary alloc] init];
    [certInsertQuery setObject:(__bridge id)(kSecClassCertificate) forKey:(__bridge id)kSecClass];
    [certInsertQuery setObject:(__bridge id)(mockCert) forKey:(__bridge id)kSecValueRef];
    [certInsertQuery setObject:attributes[(__bridge id)kSecAttrApplicationLabel] forKey:(__bridge id)kSecAttrPublicKeyHash];
    [certInsertQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)certInsertQuery, NULL);
    return status;
}

- (void)cleanUpWpjInformation
{
    NSArray *deleteClasses = @[(__bridge id)(kSecClassKey), (__bridge id)(kSecClassCertificate), (__bridge id)(kSecClassGenericPassword)];
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    for (NSString *deleteClass in deleteClasses)
    {
        NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
        [deleteQuery setObject:deleteClass forKey:(__bridge id)kSecClass];
        [deleteQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
        OSStatus result = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        XCTAssertTrue(result == errSecSuccess || result == errSecItemNotFound);
    }
}

- (void)cleanUpPrivateKey
{
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
    [deleteQuery setObject:(__bridge id)(kSecClassKey) forKey:(__bridge id)kSecClass];
    [deleteQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    [deleteQuery setObject:[NSData dataWithBytes:[self.deviceKeyTag UTF8String] length:self.deviceKeyTag.length] forKey:(__bridge id)kSecAttrApplicationTag];
    [deleteQuery setObject:@YES forKey:(__bridge id)kSecAttrIsPermanent];
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    XCTAssertTrue(result == errSecSuccess || result == errSecItemNotFound);
}

- (void)cleanUpTransportKey
{
    NSString *accessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin.v2", [[MSIDKeychainUtil sharedInstance] teamId]];
    NSMutableDictionary *deleteQuery = [[NSMutableDictionary alloc] init];
    [deleteQuery setObject:(__bridge id)(kSecClassKey) forKey:(__bridge id)kSecClass];
    [deleteQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    [deleteQuery setObject:@YES forKey:(__bridge id)kSecAttrIsPermanent];
    [deleteQuery setObject:[NSData dataWithBytes:[self.transportKeyTag UTF8String] length:self.transportKeyTag.length] forKey:(__bridge id)kSecAttrApplicationTag];
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    XCTAssertTrue(result == errSecSuccess || result == errSecItemNotFound);
}

- (NSString *)dummyEccCertificate
{
    return  @"MIIDNzCCAh-gAwIBAgIQKBcXojifRIxLIuut33ZknzANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTIzMDMxMzIxMjk0OFoXDTMzMDMxMzIxNTk0OFowLzEtMCsGA1UEAxMkOWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRiMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEl-xbT_nXgQkkzQOX7NPrvh9vPMt7yrzLqBthSpZXuIjV77izK_GW91qHTzZImhwbvXG6AcVH9Qs7ilN-VIb9xaOB0DCBzTAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB_wQMMAoGCCsGAQUFBwMCMA4GA1UdDwEB_wQEAwIHgDAiBgsqhkiG9xQBBYIcAgQTBIEQo8MK5pvg9k-6UZTxtj7IITAiBgsqhkiG9xQBBYIcAwQTBIEQj-LgHz1F-kSyqt3J40Sn7zAiBgsqhkiG9xQBBYIcBQQTBIEQkq1F9o3jGk21ENGwmnSoyjAUBgsqhkiG9xQBBYIcCAQFBIECTkEwEwYLKoZIhvcUAQWCHAcEBASBATAwDQYJKoZIhvcNAQELBQADggEBAFYbeUHpPcZj6Z8BcPhQ59dOi3-aGSYKX6Ub6GBv1CgiqU9EJ-P6VOipCL5dR458nMXJ4j97_pOXwPT0sS1rSTJ8_x3YpGLIJXpvkqDEHIoUvX1sR1tOlvXhUiP0O6l35-sil1itUZAKqS7RZtd8TWnMIgw3rCHbDHA9OlagunL6o75YC5Y74VdedZbCUjTy-IuU_VKM5gpa3c6uf_QleYgdQFlDjMH9w4TkqaWNONNoYulLZI8AykT9QtYB0iAsFr4KRL58ot1svOhqMil9vKDTkDrixEyThCcHmyyHeNoBjmXtaubOAiE3cMoJs7bV7I1uOS9aAI-Hm0W9NV-CkeE";
}

- (void)validateJwtValidity:(NSString *)jwt params:(MSIDBoundRefreshTokenRedemptionParameters *)params refreshToken:(NSString *)refreshToken
{
    XCTAssertNotNil(jwt);
    XCTAssertNotNil(params);
    XCTAssertNotNil(refreshToken);
    NSArray<NSString *> *jwtParts = [jwt componentsSeparatedByString:@"."];
    XCTAssertEqual(jwtParts.count, 3); // JWT should have 3 parts
    NSData *header = [[[jwtParts objectAtIndex:0] msidBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *payload = [[[jwtParts objectAtIndex:1] msidBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *jsonError = nil;
    NSDictionary *headerObject = [NSJSONSerialization JSONObjectWithData:header options:0 error:&jsonError];
    XCTAssertNil(jsonError);
    XCTAssertNotNil(headerObject);
    NSDictionary *payloadObject = [NSJSONSerialization JSONObjectWithData:payload options:0 error:&jsonError];
    XCTAssertNil(jsonError);
    XCTAssertNotNil(payloadObject);
    // Validate header
    XCTAssertTrue(headerObject.count == 3);
    XCTAssertEqualObjects(headerObject[@"alg"], @"ES256");
    XCTAssertEqualObjects(headerObject[@"typ"], @"JWT");
    XCTAssertNotNil(headerObject[@"x5c"]);
    // Validate payload
    XCTAssertEqualObjects(payloadObject[@"iss"], params.clientId);
    XCTAssertEqualObjects(payloadObject[@"client_id"], params.clientId);
    XCTAssertEqualObjects(payloadObject[@"nonce"], params.nonce);
    XCTAssertEqualObjects(payloadObject[@"scope"], [params.scopes.allObjects componentsJoinedByString:@" "]);
    XCTAssertFalse([payloadObject[@"scope"] containsString:@"aza"]);
    XCTAssertEqualObjects(payloadObject[@"refresh_token"], refreshToken);
    XCTAssertEqualObjects(payloadObject[@"grant_type"], @"refresh_token");
    XCTAssertEqualObjects(payloadObject[MSID_BOUND_RT_EXCHANGE], @1);
    XCTAssertNotNil(payloadObject[@"iat"]);
    XCTAssertNotNil(payloadObject[@"nbf"]);
    XCTAssertNotNil(payloadObject[@"exp"]);
    XCTAssertNotNil(payloadObject[@"jwe_crypto"]);
    XCTAssertTrue([payloadObject[@"jwe_crypto"] isKindOfClass:[NSDictionary class]]);
    NSDictionary *jweCrypto = payloadObject[@"jwe_crypto"];
    XCTAssertNotNil(jweCrypto);
    
    NSString *signature = [jwtParts objectAtIndex:2];
    XCTAssertNotNil(signature);
    XCTAssertTrue(signature.length > 0);
    NSData *message = [[NSString stringWithFormat:@"%@.%@", [jwtParts objectAtIndex:0], [jwtParts objectAtIndex:1]] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signatureData = [NSData msidDataFromBase64UrlEncodedString:signature];
    CFErrorRef error = NULL;
    XCTAssertFalse(self.deviceKeyGenerator.eccPublicKey == NULL);
    XCTAssertTrue(SecKeyVerifySignature(self.deviceKeyGenerator.eccPublicKey,
                                        kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                        (__bridge CFDataRef) message,
                                        (__bridge CFDataRef) signatureData,
                                        &error));
    XCTAssertTrue(error == NULL);
}

@end
#endif
