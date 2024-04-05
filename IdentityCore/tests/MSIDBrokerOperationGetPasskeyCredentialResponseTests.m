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
#import "MSIDBrokerOperationGetPasskeyCredentialResponse.h"
#import "MSIDBrokerOperationPasskeyCredentialRequest.h"
#import "MSIDPasskeyCredential.h"

@interface MSIDBrokerOperationGetPasskeyCredentialResponseTests : XCTestCase

@end

@implementation MSIDBrokerOperationGetPasskeyCredentialResponseTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testResponseType_shouldBeCorrect
{
    XCTAssertEqualObjects(@"operation_get_passkey_credential_response", [MSIDBrokerOperationGetPasskeyCredentialResponse responseType]);
}

- (void)testJsonDictionary_whenDataExist_shouldBeCorrect
{
    NSData *userHandle = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIHVzZXIgaGFuZGxl" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *credentialKeyId = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIGNyZWRlbnRpYWwga2V5IGlk" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithDeviceInfo:nil];
    response.operation = [MSIDBrokerOperationPasskeyCredentialRequest operation];
    response.success = YES;
    
    response.passkeyCredential = [[MSIDPasskeyCredential alloc] initWithUserHandle:userHandle
                                                                   credentialKeyId:credentialKeyId
                                                                          userName:@"sampleUserName"];

    __auto_type expectedJson = @{@"operation": @"passkey_credential_operation",
                                 @"operation_response_type": @"operation_get_passkey_credential_response",
                                 @"success": @"1",
                                 @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
                                 @"userHandle": @"73616d706c6520757365722068616e646c65",
                                 @"userName": @"sampleUserName"};
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingCredentialKeyId_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_credential_operation",
                                @"operation_response_type": @"operation_get_passkey_credential_response",
                                @"success": @"1",
                                @"userHandle": @"73616d706c6520757365722068616e646c65",
                                @"userName": @"sampleUserName",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"credentialKeyId key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingUserHandle_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_credential_operation",
                                @"operation_response_type": @"operation_get_passkey_credential_response",
                                @"success": @"1",
                                @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
                                @"userName": @"sampleUserName",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"userHandle key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingUserName_shouldReturnNilAndError
{
    __auto_type initialJson = @{@"operation": @"passkey_credential_operation",
                                @"operation_response_type": @"operation_get_passkey_credential_response",
                                @"success": @"1",
                                @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
                                @"userHandle": @"73616d706c6520757365722068616e646c65",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithJSONDictionary:initialJson error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"userName key is missing in dictionary.");
}

- (void)testJsonDictionary_whenInitWithDictionaryMissingData_shouldReturnNil
{
    __auto_type initialJson = @{@"operation": @"passkey_credential_operation",
                                @"operation_response_type": @"operation_get_passkey_credential_response",
                                @"success": @"1",
                                @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
                                @"userName": @"sampleUserName",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithJSONDictionary:initialJson error:nil];
    
    XCTAssertNil(response);
}

- (void)testJsonDictionary_whenInitWithDictionary_shouldBeConvertedBackToDictionary
{
    __auto_type initialJson = @{@"operation": @"passkey_credential_operation",
                                @"operation_response_type": @"operation_get_passkey_credential_response",
                                @"success": @"1",
                                @"credentialKeyId": @"73616d706c652063726564656e7469616c206b6579206964",
                                @"userHandle": @"73616d706c6520757365722068616e646c65",
                                @"userName": @"sampleUserName",
                                @"device_mode": @"personal",
                                @"sso_extension_mode": @"full",
                                @"wpj_status": @"notJoined",
                                @"preferred_auth_config": @"preferredAuthNotConfigured",
#if TARGET_OS_OSX
                                @"platform_sso_status": @"platformSSONotEnabled"
#endif
    };
    
    NSError *error;
    __auto_type response = [[MSIDBrokerOperationGetPasskeyCredentialResponse alloc] initWithJSONDictionary:initialJson error:nil];
    
    XCTAssertEqualObjects(initialJson, [response jsonDictionary]);
    XCTAssertNil(error);
}

@end
