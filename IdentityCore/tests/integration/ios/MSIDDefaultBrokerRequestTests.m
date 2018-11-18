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
#import "MSIDDefaultBrokerTokenRequest.h"
#import "MSIDVersion.h"
#import "NSURL+MSIDTestUtil.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDDefaultBrokerRequestTests : XCTestCase

@end

@implementation MSIDDefaultBrokerRequestTests

- (void)testInitBrokerRequest_whenValidRequest_shouldSendScopeAndPromptAndProtocolVer
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    
    NSError *error = nil;
    MSIDDefaultBrokerTokenRequest *request = [[MSIDDefaultBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority" : @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id" : @"my_client_id",
                                      @"correlation_id" : [parameters.correlationId UUIDString],
                                      @"redirect_uri" : @"my-redirect://com.microsoft.test",
                                      @"broker_key" : @"brokerKey",
                                      @"client_version" : [MSIDVersion sdkVersion],
                                      @"extra_qp" : @"",
                                      @"intune_enrollment_ids" : @"",
                                      @"intune_mam_resource" : @"",
                                      @"client_capabilities" : @"",
                                      @"client_app_name" : @"MSIDTestsHostApp",
                                      @"client_app_version" : @"1.0",
                                      @"username" : @"",
                                      @"claims" : @"",
                                      //V2 broker protocol specific
                                      @"login_hint" : @"",
                                      @"home_account_id" : @"",
                                      @"extra_consent_scopes" : @"",
                                      @"scope" : @"myscope1 myscope2",
                                      @"prompt" : @"select_account",
                                      @"msg_protocol_ver": @"3",
                                      };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"mybrokerscheme://broker?%@", [expectedRequest msidWWWFormURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               //V2 broker protocol specific
                                               @"scope": @"myscope1 myscope2"
                                               };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenAccountSet_shouldSendHomeAccountIdAndUsername
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"user" homeAccountId:@"myHomeAccountId"];
    
    NSError *error = nil;
    MSIDDefaultBrokerTokenRequest *request = [[MSIDDefaultBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority" : @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id" : @"my_client_id",
                                      @"correlation_id" : [parameters.correlationId UUIDString],
                                      @"redirect_uri" : @"my-redirect://com.microsoft.test",
                                      @"broker_key" : @"brokerKey",
                                      @"client_version" : [MSIDVersion sdkVersion],
                                      @"extra_qp" : @"",
                                      @"intune_enrollment_ids" : @"",
                                      @"intune_mam_resource" : @"",
                                      @"client_capabilities" : @"",
                                      @"client_app_name" : @"MSIDTestsHostApp",
                                      @"client_app_version" : @"1.0",
                                      @"claims" : @"",
                                      @"extra_consent_scopes" : @"",
                                      @"scope" : @"myscope1 myscope2",
                                      @"prompt" : @"select_account",
                                      @"msg_protocol_ver": @"3",
                                      @"login_hint" : @"",
                                      //if account set, both of the following should be set
                                      @"home_account_id" : @"myHomeAccountId",
                                      @"username" : @"user",
                                      
                                      };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"mybrokerscheme://broker?%@", [expectedRequest msidWWWFormURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               //V2 broker protocol specific
                                               @"scope": @"myscope1 myscope2"
                                               };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenLoginHintSet_shouldSendLoginHint
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.loginHint = @"myuser";
    
    NSError *error = nil;
    MSIDDefaultBrokerTokenRequest *request = [[MSIDDefaultBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority" : @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id" : @"my_client_id",
                                      @"correlation_id" : [parameters.correlationId UUIDString],
                                      @"redirect_uri" : @"my-redirect://com.microsoft.test",
                                      @"broker_key" : @"brokerKey",
                                      @"client_version" : [MSIDVersion sdkVersion],
                                      @"extra_qp" : @"",
                                      @"intune_enrollment_ids" : @"",
                                      @"intune_mam_resource" : @"",
                                      @"client_capabilities" : @"",
                                      @"client_app_name" : @"MSIDTestsHostApp",
                                      @"client_app_version" : @"1.0",
                                      @"claims" : @"",
                                      @"extra_consent_scopes" : @"",
                                      @"scope" : @"myscope1 myscope2",
                                      @"prompt" : @"select_account",
                                      @"msg_protocol_ver": @"3",
                                      @"home_account_id" : @"",
                                      @"username" : @"",
                                      //login hint should be set
                                      @"login_hint" : @"myuser",
                                      
                                      };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"mybrokerscheme://broker?%@", [expectedRequest msidWWWFormURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               //V2 broker protocol specific
                                               @"scope": @"myscope1 myscope2"
                                               };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

- (void)testInitBrokerRequest_whenExtraScopesSet_shouldSendExtraScopes
{
    MSIDInteractiveRequestParameters *parameters = [self defaultTestParameters];
    parameters.extraScopesToConsent = @"extraScope1 extraScope2";
    
    NSError *error = nil;
    MSIDDefaultBrokerTokenRequest *request = [[MSIDDefaultBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"brokerKey" error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSDictionary *expectedRequest = @{@"authority" : @"https://login.microsoftonline.com/contoso.com",
                                      @"client_id" : @"my_client_id",
                                      @"correlation_id" : [parameters.correlationId UUIDString],
                                      @"redirect_uri" : @"my-redirect://com.microsoft.test",
                                      @"broker_key" : @"brokerKey",
                                      @"client_version" : [MSIDVersion sdkVersion],
                                      @"extra_qp" : @"",
                                      @"intune_enrollment_ids" : @"",
                                      @"intune_mam_resource" : @"",
                                      @"client_capabilities" : @"",
                                      @"client_app_name" : @"MSIDTestsHostApp",
                                      @"client_app_version" : @"1.0",
                                      @"claims" : @"",
                                      @"scope" : @"myscope1 myscope2",
                                      @"prompt" : @"select_account",
                                      @"msg_protocol_ver": @"3",
                                      @"home_account_id" : @"",
                                      @"username" : @"",
                                      @"login_hint" : @"",
                                      //extra scopes should be set
                                      @"extra_consent_scopes" : @"extraScope1 extraScope2",
                                      };
    
    NSURL *actualURL = request.brokerRequestURL;
    
    NSString *expectedUrlString = [NSString stringWithFormat:@"mybrokerscheme://broker?%@", [expectedRequest msidWWWFormURLEncode]];
    NSURL *expectedURL = [NSURL URLWithString:expectedUrlString];
    XCTAssertTrue([expectedURL matchesURL:actualURL]);
    
    NSDictionary *expectedResumeDictionary = @{@"authority": @"https://login.microsoftonline.com/contoso.com",
                                               @"client_id": @"my_client_id",
                                               @"correlation_id": [parameters.correlationId UUIDString],
                                               @"redirect_uri": @"my-redirect://com.microsoft.test",
                                               @"keychain_group": @"com.microsoft.mygroup",
                                               //V2 broker protocol specific
                                               @"scope": @"myscope1 myscope2"
                                               };
    
    XCTAssertEqualObjects(expectedResumeDictionary, request.resumeDictionary);
}

#pragma mark - Helpers

- (MSIDInteractiveRequestParameters *)defaultTestParameters
{
    MSIDInteractiveRequestParameters *parameters = [MSIDInteractiveRequestParameters new];
    parameters.authority = [MSIDAuthorityFactory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"] context:nil error:nil];
    parameters.clientId = @"my_client_id";
    parameters.target = @"myscope1 myscope2";
    parameters.correlationId = [NSUUID new];
    parameters.redirectUri = @"my-redirect://com.microsoft.test";
    parameters.keychainAccessGroup = @"com.microsoft.mygroup";
    parameters.supportedBrokerProtocolScheme = @"mybrokerscheme";
    parameters.promptType = @"select_account";
    return parameters;
}

@end
