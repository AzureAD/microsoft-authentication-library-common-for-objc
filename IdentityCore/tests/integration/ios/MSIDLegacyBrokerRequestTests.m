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
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDLegacyBrokerTokenRequest.h"
#import "MSIDVersion.h"
#import "NSURL+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDClaimsRequest.h"
#import "NSString+MSIDTestUtil.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDLegacyBrokerRequestTests : XCTestCase

@end

@implementation MSIDLegacyBrokerRequestTests

- (void)testInitBrokerRequest_whenClaimsPassed_shouldSetSkipCacheToYES
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    NSDictionary *claimsJsonDictionary = @{@"access_token":@{@"polids":@{@"values":@[@"5ce770ea-8690-4747-aa73-c5b3cd509cd4"], @"essential":@YES}}};
    parameters.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];

    NSError *error = nil;
    MSIDLegacyBrokerTokenRequest *request = [[MSIDLegacyBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"extra_qp": @"my_eqp1%2C+%2C=my_eqp2&my_eqp3=my_eqp4",
                                      @"claims": @"%7B%22access_token%22%3A%7B%22polids%22%3A%7B%22values%22%3A%5B%225ce770ea-8690-4747-aa73-c5b3cd509cd4%22%5D%2C%22essential%22%3Atrue%7D%7D%7D",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"skip_cache": @"YES",
                                      @"resource": @"myresource",
                                      @"max_protocol_ver": @"2",
                                      @"force": @"NO",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken"
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
                                               @"resource": @"myresource",
                                               @"sdk_name" : @"adal-objc",
                                               @"broker_nonce": brokerNonce
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenUsernameAndTypePassed_shouldSendUsernameAndType
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"username@upn.com" homeAccountId:nil];
    parameters.accountIdentifier.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeRequiredDisplayableId;

    NSError *error = nil;
    MSIDLegacyBrokerTokenRequest *request = [[MSIDLegacyBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"extra_qp": @"my_eqp1%2C+%2C=my_eqp2&my_eqp3=my_eqp4",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"skip_cache": @"NO",
                                      @"resource": @"myresource",
                                      @"username": @"username@upn.com",
                                      @"username_type": @"RequiredDisplayableId",
                                      @"max_protocol_ver": @"2",
                                      @"force": @"NO",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken"
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
                                               @"resource": @"myresource",
                                               @"sdk_name" : @"adal-objc",
                                               @"broker_nonce": brokerNonce
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenLoginHintPassed_shouldSendLoginHintAndType
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.loginHint = @"myloginhint";

    NSError *error = nil;
    MSIDLegacyBrokerTokenRequest *request = [[MSIDLegacyBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"extra_qp": @"my_eqp1%2C+%2C=my_eqp2&my_eqp3=my_eqp4",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"skip_cache": @"NO",
                                      @"resource": @"myresource",
                                      @"username": @"myloginhint",
                                      @"username_type": @"OptionalDisplayableId",
                                      @"max_protocol_ver": @"2",
                                      @"force": @"NO",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken"
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
                                               @"resource": @"myresource",
                                               @"sdk_name" : @"adal-objc",
                                               @"broker_nonce": brokerNonce
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenForcePromptPassed_shouldSendForceYES
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.uiBehaviorType = MSIDUIBehaviorForceType;

    NSError *error = nil;
    MSIDLegacyBrokerTokenRequest *request = [[MSIDLegacyBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSDictionary *expectedRequest = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id": @"my_client_id",
                                      @"correlation_id": [parameters.correlationId UUIDString],
                                      @"redirect_uri": @"my-redirect://com.microsoft.test",
                                      @"broker_key": @"brokerKey",
                                      @"client_version": [MSIDVersion sdkVersion],
                                      @"extra_qp": @"my_eqp1%2C+%2C=my_eqp2&my_eqp3=my_eqp4",
                                      @"client_app_name": @"MSIDTestsHostApp",
                                      @"client_app_version": @"1.0",
                                      @"skip_cache": @"NO",
                                      @"resource": @"myresource",
                                      @"max_protocol_ver": @"2",
                                      @"force": @"YES",
                                      @"broker_nonce" : [MSIDTestIgnoreSentinel sentinel],
                                      @"application_token" : @"brokerApplicationToken"
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
                                               @"resource": @"myresource",
                                               @"sdk_name" : @"adal-objc",
                                               @"broker_nonce": brokerNonce
                                               };

    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

#pragma mark - Helpers

- (MSIDInteractiveRequestParameters *)defaultTestParameters
{
    MSIDInteractiveRequestParameters *parameters = [MSIDInteractiveRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    parameters.clientId = @"my_client_id";
    parameters.target = @"myresource";
    parameters.correlationId = [NSUUID new];
    parameters.redirectUri = @"my-redirect://com.microsoft.test";
    parameters.keychainAccessGroup = @"com.microsoft.mygroup";
    
    MSIDBrokerInvocationOptions *brokerOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeCustomScheme aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    parameters.brokerInvocationOptions = brokerOptions;
    parameters.extraAuthorizeURLQueryParameters = @{@"my_eqp1, ,": @"my_eqp2", @"my_eqp3": @"my_eqp4"};
    return parameters;
}

@end
