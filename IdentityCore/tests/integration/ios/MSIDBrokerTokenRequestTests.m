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
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDBrokerTokenRequest.h"
#import "MSIDVersion.h"
#import "NSURL+MSIDTestUtil.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDClaimsRequest.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDAuthenticationSchemeSshCert.h"
@interface MSIDBrokerTokenRequestTests : XCTestCase

@end

@implementation MSIDBrokerTokenRequestTests

- (void)tearDown
{
    [MSIDIntuneEnrollmentIdsCache setSharedCache:[[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:[[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:[MSIDCache new]]]];
    [MSIDIntuneMAMResourcesCache setSharedCache:[[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:[[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:[MSIDCache new]]]];

    [super tearDown];
}

- (MSIDInteractiveTokenRequestParameters *)defaultTestParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"mytarget mytarget2";
    parameters.correlationId = [NSUUID new];
    parameters.redirectUri = @"my-redirect://com.microsoft.test";
    parameters.keychainAccessGroup = @"com.microsoft.mygroup";
    
#if TARGET_OS_OSX
    parameters.clientSku = MSID_CLIENT_SKU_MSAL_OSX;
#else
    parameters.clientSku = MSID_CLIENT_SKU_MSAL_IOS;
#endif
    
    parameters.skipValidateResultAccount = NO;
    MSIDBrokerInvocationOptions *brokerOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeCustomScheme aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    parameters.brokerInvocationOptions = brokerOptions;
    return parameters;
}

- (MSIDInteractiveTokenRequestParameters *)defaultTestParametersATPop
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    NSDictionary *schemeParams = @{
        @"token_type":@"Pop",
        @"req_cnf":@"eyJraWQiOiJlQWkyNE9leml1czc5VlRadDhsZlhldFJTejdsR2thSmloWEJFWkIwMnV3In0"
    };
    parameters.authScheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:schemeParams];
    return parameters;
}

- (MSIDInteractiveTokenRequestParameters *)defaultTestParametersSshCert
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    NSDictionary *schemeParams = @{
        @"token_type":@"ssh-cert",
        @"key_id":@"key_id_value",
        @"req_cnf":[NSString stringWithFormat:@"{\"kty\":\"RSA\",\"n\":\"%@\",\"e\":\"%@\"}", modulus, exponent]
    };
    parameters.authScheme = [[MSIDAuthenticationSchemeSshCert alloc] initWithSchemeParameters:schemeParams];
    return parameters;
}

- (NSString *)clientSku
{
    NSString *clientSku = nil;
#if TARGET_OS_OSX
    clientSku = MSID_CLIENT_SKU_MSAL_OSX;
#else
    clientSku = MSID_CLIENT_SKU_MSAL_IOS;
#endif
    return clientSku;
}

#pragma mark - Error cases

- (void)testInitBrokerRequest_whenAuthorityMissing_shouldReturnNOAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.authority = nil;

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitBrokerRequest_whenBrokerKeyMissing_shouldReturnNOAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];

    NSError *error = nil;
    NSString *brokerKey = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:brokerKey brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitBrokerRequest_whenTargetMissing_shouldReturnNOAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.target = nil;

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitBrokerRequest_whenRedirectUriMissing_shouldReturnNOAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.redirectUri = nil;

    NSError *error = nil;
        MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testInitBrokerRequest_whenClientIdMissing_shouldReturnNOAndFillError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.clientId = nil;

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
}

#pragma mark - Payload

- (void)testInitBrokerRequest_whenValidParameters_shouldReturnValidPayload
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
                                      };

    NSURL *actualURL = request.brokerRequestURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);

    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenValidParameters_shouldReturnValidPayload_ATPopFlow
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParametersATPop];
    
    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"req_cnf" : @"eyJraWQiOiJlQWkyNE9leml1czc5VlRadDhsZlhldFJTejdsR2thSmloWEJFWkIwMnV3In0",
                                      @"token_type" : @"Pop",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
    };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"req_cnf" : @"eyJraWQiOiJlQWkyNE9leml1czc5VlRadDhsZlhldFJTejdsR2thSmloWEJFWkIwMnV3In0",
                                               @"token_type" : @"Pop",
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
    };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenValidParameters_shouldReturnValidPayload_SshCertFlow
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParametersSshCert];
    
    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSString *modulus = @"2tNr73xwcj6lH7bqRZrFzgSLj7OeLfbn8";
    NSString *exponent = @"AQAB";
    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"key_id":@"key_id_value",
                                      @"req_cnf" : [NSString stringWithFormat:@"{\"kty\":\"RSA\",\"n\":\"%@\",\"e\":\"%@\"}", modulus, exponent],
                                      @"token_type" : @"ssh-cert",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
    };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"key_id":@"key_id_value",
                                               @"req_cnf" : [NSString stringWithFormat:@"{\"kty\":\"RSA\",\"n\":\"%@\",\"e\":\"%@\"}", modulus, exponent],
                                               @"token_type" : @"ssh-cert",
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
    };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenValidParameters_andUniversalLinkRequest_shouldReturnUniversalLinkPayload
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.brokerInvocationOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeUniversalLink aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    
    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
                                      };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"https://login.microsoftonline.com/applebroker/msauthv2?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
}

- (void)testInitBrokerRequest_whenParametersWithOptionalParameters_shouldReturnValidPayload
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.extraAuthorizeURLQueryParameters = @{@"my_eqp1, ,": @"my_eqp2", @"my_eqp3": @"my_eqp4"};
    
    NSDictionary *claimsJsonDictionary = @{@"access_token":@{@"polids":@{@"values":@[@"5ce770ea-8690-4747-aa73-c5b3cd509cd4"], @"essential":@YES}}};
    parameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];
    parameters.clientCapabilities = @[@"cp1", @"cp2"];

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"claims": @"%7B%22access_token%22%3A%7B%22polids%22%3A%7B%22essential%22%3Atrue%2C%22values%22%3A%5B%225ce770ea-8690-4747-aa73-c5b3cd509cd4%22%5D%7D%7D%7D",
                                      @"client_capabilities": @"cp1,cp2",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
                                      };

    NSURL *actualURL = request.brokerRequestURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);

    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenValidParameters_andSDKCapabilities_shouldReturnValidPayload_withSDKCapabilitiesIncluded
{
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:@[@"capability1", @"capability2"] error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"sdk_broker_capabilities": @"capability1,capability2",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
                                      };

    NSURL *actualURL = request.brokerRequestURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);

    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenParametersWithIntuneItems_shouldReturnValidPayload
{
    MSIDCache *inMemoryStorage = [MSIDCache new];
    __auto_type dictionary = @{
                               @"enrollment_ids": @[
                                       @{
                                           @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                           @"oid": @"6eec576f-dave-416a-9c4a-536b178a194a",
                                           @"home_account_id": @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                                           @"user_id": @"dave@contoso.com",
                                           @"enrollment_id": @"64d0557f-dave-4193-b630-8491ffd3b180"
                                           },
                                       @{
                                           @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                           @"oid": @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                           @"home_account_id": @"60406d5d-mike-41e1-aa70-e97501076a22",
                                           @"user_id": @"mike@contoso.com",
                                           @"enrollment_id": @"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                           },
                                       ]
                               };
    [inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];

    __auto_type dataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:inMemoryStorage];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:[[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:dataSource]];

    MSIDCache *resourceInMemoryStorage = [MSIDCache new];
    __auto_type resourceDict = @{
                               @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
                               @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
                               @"login.windows.net": @"https://www.microsoft.com/windowsIntune"
                               };
    [resourceInMemoryStorage setObject:resourceDict forKey:@"intune_mam_resource_V1"];

    __auto_type resourceDataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:resourceInMemoryStorage];
    [MSIDIntuneMAMResourcesCache setSharedCache:[[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:resourceDataSource]];

    // Run the test
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"intune_enrollment_ids": @"{\"enrollment_ids\":[{\"enrollment_id\":\"64d0557f-dave-4193-b630-8491ffd3b180\",\"home_account_id\":\"1e4dd613-dave-4527-b50a-97aca38b57ba\",\"oid\":\"6eec576f-dave-416a-9c4a-536b178a194a\",\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\",\"user_id\":\"dave@contoso.com\"},{\"enrollment_id\":\"adf79e3f-mike-454d-9f0f-2299e76dbfd5\",\"home_account_id\":\"60406d5d-mike-41e1-aa70-e97501076a22\",\"oid\":\"d3444455-mike-4271-b6ea-e499cc0cab46\",\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\",\"user_id\":\"mike@contoso.com\"}]}",
                                       @"intune_mam_resource": @"{\"login.microsoftonline.com\":\"https:\\/\\/www.microsoft.com\\/intune\",\"login.microsoftonline.de\":\"https:\\/\\/www.microsoft.com\\/intune-de\",\"login.windows.net\":\"https:\\/\\/www.microsoft.com\\/windowsIntune\"}",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken",
                                      @"client_sku" : [self clientSku],
                                      @"skip_validate_result_account" : @"NO"
                                      };

    NSURL *actualURL = request.brokerRequestURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);

    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               @"broker_nonce": brokerNonce,
                                               @"client_sku" : [self clientSku],
                                               @"skip_validate_result_account" : @"NO"
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenParametersWithNestedAuthItems_shouldReturnValidPayload
{
    MSIDCache *inMemoryStorage = [MSIDCache new];
    __auto_type dictionary = @{
            @"enrollment_ids": @[
                    @{
                            @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                            @"oid": @"6eec576f-dave-416a-9c4a-536b178a194a",
                            @"home_account_id": @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                            @"user_id": @"dave@contoso.com",
                            @"enrollment_id": @"64d0557f-dave-4193-b630-8491ffd3b180"
                    },
                    @{
                            @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                            @"oid": @"d3444455-mike-4271-b6ea-e499cc0cab46",
                            @"home_account_id": @"60406d5d-mike-41e1-aa70-e97501076a22",
                            @"user_id": @"mike@contoso.com",
                            @"enrollment_id": @"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                    },
            ]
    };
    [inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];

    __auto_type dataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:inMemoryStorage];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:[[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:dataSource]];

    MSIDCache *resourceInMemoryStorage = [MSIDCache new];
    __auto_type resourceDict = @{
            @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
            @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
            @"login.windows.net": @"https://www.microsoft.com/windowsIntune"
    };
    [resourceInMemoryStorage setObject:resourceDict forKey:@"intune_mam_resource_V1"];

    __auto_type resourceDataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:resourceInMemoryStorage];
    [MSIDIntuneMAMResourcesCache setSharedCache:[[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:resourceDataSource]];

    // Run the test
    MSIDInteractiveTokenRequestParameters *parameters = [self defaultTestParameters];
    parameters.nestedAuthBrokerClientId = @"123-456-7890-123";
    parameters.nestedAuthBrokerRedirectUri = @"msauth.com.app.id://auth";

    NSError *error = nil;
    MSIDBrokerTokenRequest *request = [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
            @"client_id": @"my_client_id",
            @"correlation_id": [parameters.correlationId UUIDString],
            @"redirect_uri": @"my-redirect://com.microsoft.test",
            @"broker_key": @"brokerKey",
            @"client_version": [MSIDVersion sdkVersion],
            @"intune_enrollment_ids": @"{\"enrollment_ids\":[{\"enrollment_id\":\"64d0557f-dave-4193-b630-8491ffd3b180\",\"home_account_id\":\"1e4dd613-dave-4527-b50a-97aca38b57ba\",\"oid\":\"6eec576f-dave-416a-9c4a-536b178a194a\",\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\",\"user_id\":\"dave@contoso.com\"},{\"enrollment_id\":\"adf79e3f-mike-454d-9f0f-2299e76dbfd5\",\"home_account_id\":\"60406d5d-mike-41e1-aa70-e97501076a22\",\"oid\":\"d3444455-mike-4271-b6ea-e499cc0cab46\",\"tid\":\"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1\",\"user_id\":\"mike@contoso.com\"}]}",
            @"intune_mam_resource": @"{\"login.microsoftonline.com\":\"https:\\/\\/www.microsoft.com\\/intune\",\"login.microsoftonline.de\":\"https:\\/\\/www.microsoft.com\\/intune-de\",\"login.windows.net\":\"https:\\/\\/www.microsoft.com\\/windowsIntune\"}",
            @"client_app_name": @"MSIDTestsHostApp",
            @"client_app_version": @"1.0",
            @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
            @"application_token" : @"brokerApplicationToken",
            @"brk_client_id" : @"123-456-7890-123",
            @"brk_redirect_uri" : @"msauth.com.app.id://auth",
            @"client_sku" : [self clientSku],
            @"skip_validate_result_account" : @"NO"
    };

    NSURL *actualURL = request.brokerRequestURL;

    NSString *expectedUrlString = [NSString stringWithFormat:@"msauthv2://broker?%@", [expectedRequest msidURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);

    NSString *brokerNonce = [actualURL msidQueryParameters][@"broker_nonce"];
    XCTAssertNotNil(brokerNonce);

    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
            @"client_id": @"my_client_id",
            @"correlation_id": [parameters.correlationId UUIDString],
            @"redirect_uri": @"my-redirect://com.microsoft.test",
            @"keychain_group": @"com.microsoft.mygroup",
            @"broker_nonce": brokerNonce,
            @"brk_client_id" : @"123-456-7890-123",
            @"brk_redirect_uri" : @"msauth.com.app.id://auth",
            @"client_sku" : [self clientSku],
            @"skip_validate_result_account" : @"NO"
    };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

@end
