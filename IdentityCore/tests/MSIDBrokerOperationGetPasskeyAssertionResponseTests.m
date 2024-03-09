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
#import "MSIDBrokerOperationGetPasskeyAssertionResponse.h"
#import "MSIDBrokerOperationPasskeyAssertionRequest.h"
#import "MSIDPasskeyAssertion.h"

@interface MSIDBrokerOperationGetPasskeyAssertionResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetPasskeyAssertionResponseTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testResponseType_shouldBeCorrect
{
    XCTAssertEqualObjects(@"operation_get_passkey_assertion_response", [MSIDBrokerOperationGetPasskeyAssertionResponse responseType]);
}

- (void)testJsonDictionary_whenDataExist_shouldBeCorrect
{
    NSData *signature = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIHNpZ25hdHVyZQ==" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *authenticatorData = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIGF1dGhlbnRpY2F0b3IgZGF0YQ==" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *credentialId = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIGNyZWRlbnRpYWwgaWQ=" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithDeviceInfo:nil];
    response.operation = [MSIDBrokerOperationPasskeyAssertionRequest operation];
    response.success = YES;
    
    response.passkeyAssertion = [[MSIDPasskeyAssertion alloc] initWithSignature:signature
                                                              authenticatorData:authenticatorData
                                                                   credentialId:credentialId];

    __auto_type expectedJson = @{@"operation": @"passkey_assertion_operation",
                                 @"operation_response_type": @"operation_get_passkey_assertion_response",
                                 @"success": @"1",
                                 @"signature": @"73616d706c65207369676e6174757265",
                                 @"authenticatorData": @"73616d706c652061757468656e74696361746f722064617461",
                                 @"credentialId": @"73616d706c652063726564656e7469616c206964"};
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingSignature_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_assertion_operation",
                                @"operation_response_type": @"operation_get_passkey_assertion_response",
                                @"success": @"1",
                                @"authenticatorData": @"73616d706c652061757468656e74696361746f722064617461",
                                @"credentialId": @"73616d706c652063726564656e7469616c206964",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"signature key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingAuthenticatorData_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_assertion_operation",
                                @"operation_response_type": @"operation_get_passkey_assertion_response",
                                @"success": @"1",
                                @"signature": @"73616d706c65207369676e6174757265",
                                @"credentialId": @"73616d706c652063726564656e7469616c206964",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"authenticatorData key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingCredentialId_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_assertion_operation",
                                @"operation_response_type": @"operation_get_passkey_assertion_response",
                                @"success": @"1",
                                @"signature": @"73616d706c65207369676e6174757265",
                                @"authenticatorData": @"73616d706c652061757468656e74696361746f722064617461",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"credentialId key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingData_shouldReturnNil
{
    __auto_type initialJson = @{@"operation": @"passkey_assertion_operation",
                                @"operation_response_type": @"operation_get_passkey_assertion_response",
                                @"success": @"1",
                                @"signature": @"73616d706c65207369676e6174757265",
                                @"credentialId": @"73616d706c652063726564656e7469616c206964",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithJSONDictionary:initialJson error:nil];
    
    XCTAssertNil(response);
}

- (void)testJsonDictionary_whenInitWithDictionary_shouldBeConvertedBackToDictionary
{
    __auto_type initialJson = @{@"operation": @"passkey_assertion_operation",
                                @"operation_response_type": @"operation_get_passkey_assertion_response",
                                @"success": @"1",
                                @"signature": @"73616d706c65207369676e6174757265",
                                @"authenticatorData": @"73616d706c652061757468656e74696361746f722064617461",
                                @"credentialId": @"73616d706c652063726564656e7469616c206964",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
                                @"preferred_auth_config": @"preferredAuthNotConfigured",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyAssertionResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertEqualObjects(initialJson, [response jsonDictionary]);
    XCTAssertNil(error);
}

@end
