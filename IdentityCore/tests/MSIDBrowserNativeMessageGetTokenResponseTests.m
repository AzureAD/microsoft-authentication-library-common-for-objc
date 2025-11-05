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
#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTokenResponse.h"
#import "MSIDTestIdentifiers.h"

@interface MSIDTokenResponseMock : MSIDTokenResponse

@property (nonatomic) NSDictionary *responseJson;
@property (nonatomic) BOOL returnNilAccounUpn;

@end

@implementation MSIDTokenResponseMock

- (NSString *)accountUpn
{
    if (self.returnNilAccounUpn) return nil;
    
    return [super accountUpn];
}

- (NSDictionary *)jsonDictionary
{
    return self.responseJson;
}

@end

@interface MSIDBrowserNativeMessageGetTokenResponseTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetTokenResponseTests

- (void)testResponseType_shouldBeGenericResponse
{
    // We don't use this operation directly, it is wrapped by "BrokerOperationBrowserNativeMessage" operation, so we don't care about response type and return generic response.
    XCTAssertEqualObjects(@"operation_generic_response", [MSIDBrowserNativeMessageGetTokenResponse responseType]);
}

- (void)testJsonDictionary_whenNoResposne_shouldReturnNil
{
    __auto_type tokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:tokenResponse];
    
    XCTAssertNil([response jsonDictionary]);
}

- (void)testJsonDictionary_whenPayloadExist_shouldBeCorrect
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    NSDictionary *jsonInput = @{@"id_token": idToken};
    
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:jsonInput error:nil];
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};
    
    __auto_type operationTokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
    operationTokenResponse.tokenResponse = tokenResponseMock;
    
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:operationTokenResponse];
    response.state = @"1234";
    
    __auto_type expectedJson = @{
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": tokenResponseMock.idTokenObj.username
        },
        @"properties": @{
            @"UPN": tokenResponseMock.idTokenObj.username
        },
        @"state": @"1234",
        @"some_key": @"some_value"
    };
    
    XCTAssertNotNil([response jsonDictionary]);
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

- (void)testJsonDictionary_whenNoUpnInReponse_shouldUseProvidedUpn
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithPreferredUsername:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                  subject:DEFAULT_TEST_ID_TOKEN_SUBJECT];
    
    NSDictionary *jsonInput = @{@"id_token": idToken};
    
    MSIDTokenResponseMock *tokenResponseMock = [[MSIDTokenResponseMock alloc] initWithJSONDictionary:jsonInput error:nil];
    tokenResponseMock.returnNilAccounUpn = YES;
    tokenResponseMock.responseJson = @{@"some_key": @"some_value"};
    
    __auto_type operationTokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
    operationTokenResponse.tokenResponse = tokenResponseMock;
    
    __auto_type response = [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:operationTokenResponse];
    response.state = @"1234";
    response.requestAccountUpn = @"a@b.c";
    
    __auto_type expectedJson = @{
        @"account": @{
            @"id": tokenResponseMock.accountIdentifier,
            @"userName": @"a@b.c"
        },
        @"properties": @{
            @"UPN": @"a@b.c"
        },
        @"state": @"1234",
        @"some_key": @"some_value"
    };
    
    XCTAssertNotNil([response jsonDictionary]);
    XCTAssertEqualObjects(expectedJson, [response jsonDictionary]);
}

@end
