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
#import "MSIDDeviceTokenUtil.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDHttpRequest.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDConstants.h"
#import "MSIDError.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDCachedNonce.h"
#import "MSIDNonceTokenRequestMock.h"
#import "NSData+MSIDExtensions.h"
#import "NSURL+MSIDExtensions.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAuthority.h"
#import "MSIDExternalSSOContextMock.h"

#pragma mark - Test subclass

// Subclass that overrides the workplace-join lookup seam so tests can inject a fake
// registration without swizzling or touching the keychain.
@interface MSIDDeviceTokenUtilTestMock : MSIDDeviceTokenUtil

@property (class, nonatomic, strong, nullable) MSIDWPJKeyPairWithCert *stubbedRegistration;

// Re-declared private seam from MSIDDeviceTokenUtil so we can override it.
+ (nullable MSIDWPJKeyPairWithCert *)deviceRegistrationForTenantId:(nullable NSString *)tenantId
                                                          context:(nullable id<MSIDRequestContext>)context;

@end

@implementation MSIDDeviceTokenUtilTestMock

static MSIDWPJKeyPairWithCert *gStubbedRegistration = nil;

+ (MSIDWPJKeyPairWithCert *)stubbedRegistration { return gStubbedRegistration; }
+ (void)setStubbedRegistration:(MSIDWPJKeyPairWithCert *)stubbedRegistration { gStubbedRegistration = stubbedRegistration; }

+ (MSIDWPJKeyPairWithCert *)deviceRegistrationForTenantId:(__unused NSString *)tenantId
                                                  context:(__unused id<MSIDRequestContext>)context
{
    return gStubbedRegistration;
}

@end

// Re-declare the private workplace-join lookup seam on the base class so tests can invoke
// its real implementation directly (without going through the overriding mock subclass).
@interface MSIDDeviceTokenUtil (Testing)
+ (nullable MSIDWPJKeyPairWithCert *)deviceRegistrationForTenantId:(nullable NSString *)tenantId
                                                          context:(nullable id<MSIDRequestContext>)context;
@end

#pragma mark - Tests

@interface MSIDDeviceTokenUtilTests : XCTestCase
@end

@implementation MSIDDeviceTokenUtilTests

- (void)tearDown
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = nil;
    [MSIDTestURLSession clearResponses];
    [super tearDown];
}

#pragma mark - Helpers

- (MSIDRequestParameters *)defaultRequestParametersWithCommonAuthority
{
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.clientId = @"my_client_id";
    requestParams.redirectUri = @"my_redirect_uri";
    requestParams.target = @"scope1 scope2";
    requestParams.authScheme = [MSIDAuthenticationScheme new];
    requestParams.correlationId = [NSUUID UUID];
    requestParams.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                          rawTenant:nil
                                                            context:nil
                                                              error:nil];
    return requestParams;
}

- (NSString *)dummyEccCertificate
{
    return @"MIIDNzCCAh-gAwIBAgIQKBcXojifRIxLIuut33ZknzANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTIzMDMxMzIxMjk0OFoXDTMzMDMxMzIxNTk0OFowLzEtMCsGA1UEAxMkOWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRiMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEl-xbT_nXgQkkzQOX7NPrvh9vPMt7yrzLqBthSpZXuIjV77izK_GW91qHTzZImhwbvXG6AcVH9Qs7ilN-VIb9xaOB0DCBzTAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB_wQMMAoGCCsGAQUFBwMCMA4GA1UdDwEB_wQEAwIHgDAiBgsqhkiG9xQBBYIcAgQTBIEQo8MK5pvg9k-6UZTxtj7IITAiBgsqhkiG9xQBBYIcAwQTBIEQj-LgHz1F-kSyqt3J40Sn7zAiBgsqhkiG9xQBBYIcBQQTBIEQkq1F9o3jGk21ENGwmnSoyjAUBgsqhkiG9xQBBYIcCAQFBIECTkEwEwYLKoZIhvcUAQWCHAcEBASBATAwDQYJKoZIhvcNAQELBQADggEBAFYbeUHpPcZj6Z8BcPhQ59dOi3-aGSYKX6Ub6GBv1CgiqU9EJ-P6VOipCL5dR458nMXJ4j97_pOXwPT0sS1rSTJ8_x3YpGLIJXpvkqDEHIoUvX1sR1tOlvXhUiP0O6l35-sil1itUZAKqS7RZtd8TWnMIgw3rCHbDHA9OlagunL6o75YC5Y74VdedZbCUjTy-IuU_VKM5gpa3c6uf_QleYgdQFlDjMH9w4TkqaWNONNoYulLZI8AykT9QtYB0iAsFr4KRL58ot1svOhqMil9vKDTkDrixEyThCcHmyyHeNoBjmXtaubOAiE3cMoJs7bV7I1uOS9aAI-Hm0W9NV-CkeE";
}

- (NSString *)dummyPrivateKey
{
    return @"MIIEowIBAAKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABAoIBAEmRRI3GeQQWpn2h3m11wsPKC/sLYdxJZcFjdrGG2LqCaY0XO4vJjO5MDJlxb+uaQsXascf91sx67QyfbSpirMIy9sUP1LNRHEmtEW4YUDbcjq1aDsB76GyVYPt0VIG/0v4ABcQ97qIyUCeivw5ZU6LBjwUD1ScHiSEfSeCMWyk9YgRUozM3yZOpvugwjOF7efEjVlWvGvIfh9U/Xyeuj+NJ3r8zW87K+ySzGwrPwEmfBBfyd5LOqZzPJAKGJ3og8oaMDf4IWV7iSicCcPCbq6psj+B/i4HZc9u3MqE7YjKVbNG2S6qDsLUxpWfct72ZeKtfZcb3Kqa1nh0RximqUoECgYEA6UfzvsHg283KOTxQqX3v2IDbtwv73wKd/+V8sq8mhtjJhv5SpyJe99L/cuoxTu2ELUPmKIP++b7oyMvdRNyJaLIMRYDGGAKeLXXtWht//tCmHXyOZDhs9oHC3EMNHmqXBDSObL/CbN5puAQbCjofUX5zTNMdmq0qTOPYUezxjHECgYEA6S8JXstQ5RL+pmonoFlPWfuwXL8chpGJH1iOab1WYwjAbszSy1LJBQu5dWhKcqLl3EFywJgWRUKGFlQ/099XRVTHl4YhjEN054GEBxsTkZUhwXh0l0v6lPnsG6daWcTZ44gh4FXtqfPD/5/RcWUfhYQW0NoeIzviWt8MqZ6NIQ0CgYEA1TDpg/qBOb9vQTFq8grix7Szlyx/iYZFyNf8RvwktHWobxM7i/ywV8HfrDB00ZHlCs0TqRFAUxNygBc3Zzg455JX/qi54LV7w0YTnRamucQLG8V6CAM9KWbbIxqwAY0d6DzzsFTrJT151i8CWy1U89AhJSOG2ZXJo61SQ0TMVzECgYA6w8PUw+BLGpJaVf5OhrNctfUoKnGB6ENqRuL8+t4+bwIv6iZlXyORxfajA/lfEnZjH4tPxgQ2yCEKl4jOWEaiDk+OfBsQQh/AB//B2qz/z1mGbFjVmCw6RxGdlntKjDVtBe2jn4QZhHksfpZFwXpEJ5moYI+fyYOt6vBB/tcKMQKBgD7q4f036ad5TeX14vsFSSkGeOJrbUw0UqYeUit9B8DICwrV42/z60kTXxGg+2Wo8gL5Fo2tKCUe34BvvpMP92EKB/qbjoIirbZVnEDP9K1rCdGdEaYzDlRXsQ/p/bM6Tz3X++wpnqcDQhJp6lTDVLaX4faSQjWuVVIHVn1zpvIr";
}

- (MSIDWPJKeyPairWithCert *)dummyRegistration
{
    NSData *certData = [NSData msidDataFromBase64UrlEncodedString:[self dummyEccCertificate]];
    SecCertificateRef certRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);

    NSDictionary *keyAttr = @{(__bridge NSString *)kSecAttrKeyType : (__bridge NSString *)kSecAttrKeyTypeRSA,
                              (__bridge NSString *)kSecAttrKeyClass : (__bridge NSString *)kSecAttrKeyClassPrivate};
    NSData *keyData = [NSData msidDataFromBase64UrlEncodedString:[self dummyPrivateKey]];
    SecKeyRef keyRef = SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)keyAttr, NULL);

    MSIDWPJKeyPairWithCert *registration = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:keyRef
                                                                                 certificate:certRef
                                                                           certificateIssuer:@"issuer"];
    if (certRef) CFRelease(certRef);
    if (keyRef) CFRelease(keyRef);
    return registration;
}

- (NSDictionary *)decodeJwtPayloadSegment:(NSString *)segment
{
    NSData *payloadData = [NSData msidDataFromBase64UrlEncodedString:segment];
    return [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
}

- (NSDictionary *)validDeviceTokenJson
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID } msidBase64UrlJson];
    return @{
        @"token_type" : @"Bearer",
        @"access_token" : @"device-access-token",
        @"expires_in" : @"3600",
        @"scope" : @"scope1 scope2",
        @"client_info" : clientInfoString,
        @"id_token" : [MSIDTestIdTokenUtil defaultV2IdToken]
    };
}

// A permissive request-header matcher: every header the request may send is mapped to an
// ignore sentinel so matching succeeds on URL/body regardless of header values.
- (NSMutableDictionary *)permissiveIgnoreRequestHeaders
{
    NSArray *keys = @[ @"Accept", @"Content-Length", @"Content-Type", @"User-Agent",
                       @"x-client-SKU", @"x-client-OS", @"x-app-name", @"x-app-ver",
                       @"x-ms-PkeyAuth+", @"x-client-Ver", @"x-client-CPU", @"x-client-DM",
                       @"Connection", @"client-request-id", @"return-client-request-id",
                       @"x-client-current-telemetry", @"x-client-last-telemetry",
                       @"x-client-last-endpoint", @"x-client-last-error",
                       @"x-client-last-request", @"x-client-last-response-time",
                       @"X-AnchorMailbox" ];
    NSMutableDictionary *headers = [NSMutableDictionary new];
    for (NSString *key in keys)
    {
        headers[key] = [[MSIDTestIgnoreSentinel alloc] init];
    }
    return headers;
}

#pragma mark - getDeviceTokenEndpoint:tenantId:

- (void)testGetDeviceTokenEndpoint_whenCommonAuthority_shouldReplaceCommonWithTenantIdAndAppendPath
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    NSURL *endpoint = [MSIDDeviceTokenUtil getDeviceTokenEndpoint:requestParams tenantId:@"my-tenant-id"];

    XCTAssertEqualObjects(endpoint.absoluteString, @"https://login.microsoftonline.com/my-tenant-id/oauth2/v2.0/token");
}

- (void)testGetDeviceTokenEndpoint_whenTenantedAuthority_shouldAppendPathWithoutReplacingTenant
{
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"]
                                                          rawTenant:nil
                                                            context:nil
                                                              error:nil];

    NSURL *endpoint = [MSIDDeviceTokenUtil getDeviceTokenEndpoint:requestParams tenantId:@"unused-tenant-id"];

    XCTAssertEqualObjects(endpoint.absoluteString, @"https://login.microsoftonline.com/contoso.com/oauth2/v2.0/token");
}

- (void)testGetDeviceTokenEndpoint_whenRequestParametersNil_shouldReturnNil
{
    MSIDRequestParameters *requestParams = nil;
    NSURL *endpoint = [MSIDDeviceTokenUtil getDeviceTokenEndpoint:requestParams tenantId:@"my-tenant-id"];
    XCTAssertNil(endpoint);
}

- (void)testGetDeviceTokenEndpoint_whenAuthorityUrlNil_shouldReturnNil
{
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.authority = nil;

    NSURL *endpoint = [MSIDDeviceTokenUtil getDeviceTokenEndpoint:requestParams tenantId:@"my-tenant-id"];
    XCTAssertNil(endpoint);
}

- (void)testGetDeviceTokenEndpoint_whenCommonAuthorityAndBlankTenantId_shouldReturnNil
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    NSURL *endpoint = [MSIDDeviceTokenUtil getDeviceTokenEndpoint:requestParams tenantId:@""];
    XCTAssertNil(endpoint);
}

#pragma mark - deviceTokenRequestBodyParametersWithJwt:enrollmentId:extraParameters:

- (void)testDeviceTokenRequestBodyParameters_whenBasic_shouldContainClientInfoGrantTypeAndRequest
{
    NSDictionary *body = [MSIDDeviceTokenUtil deviceTokenRequestBodyParametersWithJwt:@"signed.jwt.value"
                                                                        enrollmentId:nil
                                                                     extraParameters:nil];

    XCTAssertEqualObjects(body[MSID_OAUTH2_CLIENT_INFO], @NO);
    XCTAssertEqualObjects(body[MSID_OAUTH2_GRANT_TYPE], MSID_OAUTH2_JWT_BEARER_VALUE);
    XCTAssertEqualObjects(body[@"request"], @"signed.jwt.value");
    XCTAssertNil(body[MSID_ENROLLMENT_ID]);
}

- (void)testDeviceTokenRequestBodyParameters_whenEnrollmentIdProvided_shouldIncludeEnrollmentId
{
    NSDictionary *body = [MSIDDeviceTokenUtil deviceTokenRequestBodyParametersWithJwt:@"signed.jwt.value"
                                                                        enrollmentId:@"enrollment-123"
                                                                     extraParameters:nil];

    XCTAssertEqualObjects(body[MSID_ENROLLMENT_ID], @"enrollment-123");
}

- (void)testDeviceTokenRequestBodyParameters_whenEnrollmentIdBlank_shouldOmitEnrollmentId
{
    NSDictionary *body = [MSIDDeviceTokenUtil deviceTokenRequestBodyParametersWithJwt:@"signed.jwt.value"
                                                                        enrollmentId:@""
                                                                     extraParameters:nil];

    XCTAssertNil(body[MSID_ENROLLMENT_ID]);
}

- (void)testDeviceTokenRequestBodyParameters_whenExtraParametersProvided_shouldMergeThem
{
    NSDictionary *body = [MSIDDeviceTokenUtil deviceTokenRequestBodyParametersWithJwt:@"signed.jwt.value"
                                                                        enrollmentId:nil
                                                                     extraParameters:@{@"extra_key" : @"extra_value"}];

    XCTAssertEqualObjects(body[@"extra_key"], @"extra_value");
    XCTAssertEqualObjects(body[MSID_OAUTH2_GRANT_TYPE], MSID_OAUTH2_JWT_BEARER_VALUE);
}

#pragma mark - getDeviceTokenRequestJwtForResource:...

- (void)testGetDeviceTokenRequestJwt_whenValidInputs_shouldReturnSignedJwtWithThreeSegments
{
    NSError *error;
    NSString *jwt = [MSIDDeviceTokenUtil getDeviceTokenRequestJwtForResource:@"https://graph.microsoft.com"
                                                                     scopes:[NSSet setWithArray:@[@"scope1", @"scope2"]]
                                                                redirectUri:@"my_redirect_uri"
                                                                   audience:@"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token"
                                                                   clientId:@"my_client_id"
                                                                      nonce:@"test-nonce"
                                                    registrationInformation:[self dummyRegistration]
                                                         extraPayloadClaims:nil
                                                                    context:nil
                                                                      error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(jwt);
    XCTAssertEqual([jwt componentsSeparatedByString:@"."].count, 3);
}

- (void)testGetDeviceTokenRequestJwt_whenValidInputs_shouldContainExpectedPayloadClaims
{
    NSString *jwt = [MSIDDeviceTokenUtil getDeviceTokenRequestJwtForResource:@"https://graph.microsoft.com"
                                                                     scopes:[NSSet setWithArray:@[@"scope1"]]
                                                                redirectUri:@"my_redirect_uri"
                                                                   audience:@"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token"
                                                                   clientId:@"my_client_id"
                                                                      nonce:@"test-nonce"
                                                    registrationInformation:[self dummyRegistration]
                                                         extraPayloadClaims:@{@"custom_claim" : @"custom_value"}
                                                                    context:nil
                                                                      error:nil];

    NSArray *segments = [jwt componentsSeparatedByString:@"."];
    NSDictionary *payload = [self decodeJwtPayloadSegment:segments[1]];

    XCTAssertEqualObjects(payload[MSID_OAUTH2_GRANT_TYPE], MSID_OAUTH2_DEVICE_TOKEN);
    XCTAssertEqualObjects(payload[@"aud"], @"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token");
    XCTAssertEqualObjects(payload[@"iss"], @"my_client_id");
    XCTAssertEqualObjects(payload[MSID_OAUTH2_CLIENT_ID], @"my_client_id");
    XCTAssertEqualObjects(payload[MSID_OAUTH2_REDIRECT_URI], @"my_redirect_uri");
    XCTAssertEqualObjects(payload[@"resource"], @"https://graph.microsoft.com");
    XCTAssertEqualObjects(payload[@"request_nonce"], @"test-nonce");
    XCTAssertEqualObjects(payload[MSID_OAUTH2_SCOPE], @"scope1");
    XCTAssertEqualObjects(payload[@"custom_claim"], @"custom_value");
}

- (void)testGetDeviceTokenRequestJwt_whenNonceBlank_shouldOmitRequestNonceClaim
{
    NSString *jwt = [MSIDDeviceTokenUtil getDeviceTokenRequestJwtForResource:@"https://graph.microsoft.com"
                                                                     scopes:nil
                                                                redirectUri:@"my_redirect_uri"
                                                                   audience:@"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token"
                                                                   clientId:@"my_client_id"
                                                                      nonce:@""
                                                    registrationInformation:[self dummyRegistration]
                                                         extraPayloadClaims:nil
                                                                    context:nil
                                                                      error:nil];

    NSArray *segments = [jwt componentsSeparatedByString:@"."];
    NSDictionary *payload = [self decodeJwtPayloadSegment:segments[1]];

    XCTAssertNil(payload[@"request_nonce"]);
    XCTAssertNil(payload[MSID_OAUTH2_SCOPE]);
}

- (void)testGetDeviceTokenRequestJwt_whenSigningKeyUnusable_shouldReturnNil
{
    // A registration with no signable private key cannot produce a signing algorithm,
    // so JWT creation fails and returns nil.
    NSString *jwt = [MSIDDeviceTokenUtil getDeviceTokenRequestJwtForResource:@"https://graph.microsoft.com"
                                                                     scopes:nil
                                                                redirectUri:@"my_redirect_uri"
                                                                   audience:@"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token"
                                                                   clientId:@"my_client_id"
                                                                      nonce:@"test-nonce"
                                                    registrationInformation:[MSIDWPJKeyPairWithCertMock new]
                                                         extraPayloadClaims:nil
                                                                    context:nil
                                                                      error:nil];

    XCTAssertNil(jwt);
}

#pragma mark - handleDeviceTokenResponse:...

- (void)testHandleDeviceTokenResponse_whenErrorProvided_shouldForwardError
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];
    MSIDDeviceTokenResponseHandler *handler = [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:requestParams
                                                                                                  oauthFactory:[MSIDAADV2Oauth2Factory new]];
    NSError *inputError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"bad grant", nil, nil, nil, nil, nil, NO);

    XCTestExpectation *expectation = [self expectationWithDescription:@"handleDeviceTokenResponse completion called."];
    [MSIDDeviceTokenUtil handleDeviceTokenResponse:nil
                                 requestParameters:requestParams
                                   responseHandler:handler
                                             error:inputError
                                   completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorServerInvalidGrant);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testHandleDeviceTokenResponse_whenNilResponseHandlerAndErrorProvided_shouldForwardError
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];
    NSError *inputError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerInvalidGrant, @"bad grant", nil, nil, nil, nil, nil, NO);

    XCTestExpectation *expectation = [self expectationWithDescription:@"handleDeviceTokenResponse completion called."];
    [MSIDDeviceTokenUtil handleDeviceTokenResponse:nil
                                 requestParameters:requestParams
                                   responseHandler:nil
                                             error:inputError
                                   completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorServerInvalidGrant);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testHandleDeviceTokenResponse_whenValidResponse_shouldReturnTokenResult
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];
    MSIDDeviceTokenResponseHandler *handler = [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:requestParams
                                                                                                  oauthFactory:[MSIDAADV2Oauth2Factory new]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"handleDeviceTokenResponse completion called."];
    [MSIDDeviceTokenUtil handleDeviceTokenResponse:[self validDeviceTokenJson]
                                 requestParameters:requestParams
                                   responseHandler:handler
                                             error:nil
                                   completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.accessToken.accessToken, @"device-access-token");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - getDeviceTokenRequest:...

- (void)testGetDeviceTokenRequest_whenRequestParametersNil_shouldReturnError
{
    MSIDRequestParameters *requestParams = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testGetDeviceTokenRequest_whenResourceBlank_shouldReturnError
{
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@""
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testGetDeviceTokenRequest_whenNoRegistrationFound_shouldReturnWorkplaceJoinRequiredError
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = nil;
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorWorkplaceJoinRequired);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testGetDeviceTokenRequest_whenValidAndNonceSeeded_shouldReturnConfiguredHttpRequest
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [self dummyRegistration];
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    // Seed the nonce cache so the internal nonce request resolves without hitting the network.
    NSString *tokenEndpoint = @"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token";
    NSString *environment = [NSURL URLWithString:tokenEndpoint].msidHostWithPortIfNecessary;
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"cached-device-nonce"];
    [[MSIDNonceTokenRequest.class nonceCache] setObject:cachedNonce forKey:environment];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:@"enrollment-123"
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(deviceTokenRequest);
        XCTAssertEqualObjects(deviceTokenRequest.urlRequest.HTTPMethod, @"POST");
        XCTAssertEqualObjects(deviceTokenRequest.parameters[MSID_OAUTH2_GRANT_TYPE], MSID_OAUTH2_JWT_BEARER_VALUE);
        XCTAssertEqualObjects(deviceTokenRequest.parameters[MSID_ENROLLMENT_ID], @"enrollment-123");
        XCTAssertNotNil(deviceTokenRequest.parameters[@"request"]);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [[MSIDNonceTokenRequest.class nonceCache] removeObjectForKey:environment];
}

- (void)testGetDeviceTokenRequest_whenEndpointCannotBeConstructed_shouldReturnError
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [self dummyRegistration];

    // Request parameters without an authority -> endpoint construction returns nil.
    MSIDRequestParameters *requestParams = [MSIDRequestParameters new];
    requestParams.correlationId = [NSUUID UUID];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testGetDeviceTokenRequest_whenEnrollmentIdNil_shouldLookUpEnrollmentIdAndReturnRequest
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [self dummyRegistration];
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    // Seed the nonce cache so the internal nonce request resolves without hitting the network.
    NSString *tokenEndpoint = @"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token";
    NSString *environment = [NSURL URLWithString:tokenEndpoint].msidHostWithPortIfNecessary;
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"cached-device-nonce"];
    [[MSIDNonceTokenRequest.class nonceCache] setObject:cachedNonce forKey:environment];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    // enrollmentId is nil, forcing the Intune-cache lookup path. No enrollment id is cached in the
    // test environment, so the body should not contain an enrollment id.
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(deviceTokenRequest);
        XCTAssertNil(deviceTokenRequest.parameters[MSID_ENROLLMENT_ID]);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [[MSIDNonceTokenRequest.class nonceCache] removeObjectForKey:environment];
}

- (void)testGetDeviceTokenRequest_whenJwtSigningFails_shouldReturnError
{
    // A registration with no signable private key makes JWT signing fail.
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [MSIDWPJKeyPairWithCertMock new];
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    // Seed the nonce cache so the flow reaches JWT signing.
    NSString *tokenEndpoint = @"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token";
    NSString *environment = [NSURL URLWithString:tokenEndpoint].msidHostWithPortIfNecessary;
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"cached-device-nonce"];
    [[MSIDNonceTokenRequest.class nonceCache] setObject:cachedNonce forKey:environment];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [[MSIDNonceTokenRequest.class nonceCache] removeObjectForKey:environment];
}

- (void)testGetDeviceTokenRequest_whenNonceRequestFails_shouldReturnError
{
    [MSIDTestURLSession clearResponses];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];

    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [self dummyRegistration];
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];

    // Do not seed the nonce cache. The internal nonce request resolves the authority
    // (instance discovery + OIDC metadata) and then requests a nonce, which we fail here.
    NSString *nonceAuthority = @"https://login.microsoftonline.com/common";
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse discoveryResponseForAuthority:nonceAuthority]];
    [MSIDTestURLSession addResponse:[MSIDTestURLResponse oidcResponseForAuthority:nonceAuthority]];

    NSError *nonceNetworkError = [[NSError alloc] initWithDomain:@"TestDomain"
                                                            code:-1
                                                        userInfo:@{@"MSIDErrorDescriptionKey" : @"Nonce endpoint failed."}];
    MSIDTestURLResponse *nonceErrorResponse =
        [MSIDTestURLResponse request:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"]
                    respondWithError:nonceNetworkError];
    [nonceErrorResponse setRequestHeaders:[self permissiveIgnoreRequestHeaders]];
    [MSIDTestURLSession addResponse:nonceErrorResponse];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(deviceTokenRequest);
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [MSIDTestURLSession clearResponses];
    [MSIDAuthority.openIdConfigurationCache removeAllObjects];
}

- (void)testGetDeviceTokenRequest_whenScopeBlank_shouldReturnConfiguredHttpRequest
{
    MSIDDeviceTokenUtilTestMock.stubbedRegistration = [self dummyRegistration];
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithCommonAuthority];
    // No target -> allTokenRequestScopes is blank, exercising the nil-scopesSet branch.
    requestParams.target = nil;

    // Seed the nonce cache so the internal nonce request resolves without hitting the network.
    NSString *tokenEndpoint = @"https://login.microsoftonline.com/tenantId/oauth2/v2.0/token";
    NSString *environment = [NSURL URLWithString:tokenEndpoint].msidHostWithPortIfNecessary;
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"cached-device-nonce"];
    [[MSIDNonceTokenRequest.class nonceCache] setObject:cachedNonce forKey:environment];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called."];
    [MSIDDeviceTokenUtilTestMock getDeviceTokenRequest:requestParams
                                              tenantId:@"tenantId"
                                              resource:@"https://graph.microsoft.com"
                                          enrollmentId:nil
                                       extraParameters:nil
                                            ssoContext:nil
                                       completionBlock:^(MSIDHttpRequest * _Nullable deviceTokenRequest, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(deviceTokenRequest);
        XCTAssertEqualObjects(deviceTokenRequest.urlRequest.HTTPMethod, @"POST");
        XCTAssertNotNil(deviceTokenRequest.parameters[@"request"]);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [[MSIDNonceTokenRequest.class nonceCache] removeObjectForKey:environment];
}

#pragma mark - deviceRegistrationForTenantId:context: (base seam)

- (void)testDeviceRegistrationForTenantId_whenNoRegistrationInKeychain_shouldReturnNil
{
    // Exercises the real seam implementation (workplace-join keychain lookup), which returns
    // nil in the test environment where no device registration is present.
    MSIDWPJKeyPairWithCert *registration = [MSIDDeviceTokenUtil deviceRegistrationForTenantId:@"some-tenant"
                                                                                     context:nil];
    XCTAssertNil(registration);
}

@end

