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
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDBrowserNativeMessageGetTokenRequestTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetTokenRequestTests

- (void)setUp 
{
}

- (void)tearDown 
{
}

- (void)testOperation_shouldBeCorrect
{
    XCTAssertEqualObjects(@"GetToken", [MSIDBrowserNativeMessageGetTokenRequest operation]);
}

- (void)testJsonDictionary_shouldThrow
{
    __auto_type request = [MSIDBrowserNativeMessageGetTokenRequest new];

    XCTAssertThrows([request jsonDictionary]);
}

- (void)testInitWithJSONDictionary_whenJsonValidAndAllFieldsProvided_shouldInit
{
    __auto_type extraParameters = @{
        @"k1": @"v1",
        @"k2": @"v2"
    };
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
        @"request": @{
            @"accountId": @"uid.utid",
            @"clientId": @"29a788ca-7bcf-4732-b23c-c8d294347e5b",
            @"authority": @"https://login.microsoftonline.com/common",
            @"scope": @"user.read openid profile offline_access",
            @"redirectUri": @"https://login.microsoft.com",
            @"correlationId": @"9BBCA391-33A9-4EC9-A00E-A0FBFA71013D",
            @"prompt": @"login",
            @"isSts": @(YES),
            @"nonce": @"e98aba90-bc47-4ff9-8809-b6e1c7e7cd47",
            @"state": @"state1",
            @"loginHint": @"user@microsoft.com",
            @"instance_aware": @(YES),
            @"extraParameters": extraParameters
        }
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(@"https://login.microsoft.com", request.sender.absoluteString);
    XCTAssertEqualObjects(@"uid", request.accountId.uid);
    XCTAssertEqualObjects(@"utid", request.accountId.utid);
    XCTAssertEqualObjects(@"29a788ca-7bcf-4732-b23c-c8d294347e5b", request.clientId);
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", request.authority.url.absoluteString);
    XCTAssertEqualObjects(@"user.read openid profile offline_access", request.scopes);
    XCTAssertEqualObjects(@"https://login.microsoft.com", request.redirectUri);
    XCTAssertEqualObjects(@"9BBCA391-33A9-4EC9-A00E-A0FBFA71013D", request.correlationId.UUIDString);
    XCTAssertEqual(MSIDPromptTypeLogin, request.prompt);
    XCTAssertTrue(request.isSts);
    XCTAssertEqualObjects(@"e98aba90-bc47-4ff9-8809-b6e1c7e7cd47", request.nonce);
    XCTAssertEqualObjects(@"state1", request.state);
    XCTAssertEqualObjects(@"user@microsoft.com", request.loginHint);
    XCTAssertTrue(request.instanceAware);
    XCTAssertEqualObjects(extraParameters, request.extraParameters);
}

- (void)testInitWithJSONDictionary_whenJsonValidAndRequiredOnlyFieldsProvided_shouldInit
{
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
        @"request": @{
            @"clientId": @"29a788ca-7bcf-4732-b23c-c8d294347e5b",
            @"scope": @"user.read openid profile offline_access",
            @"redirectUri": @"https://login.microsoft.com",
        }
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(@"29a788ca-7bcf-4732-b23c-c8d294347e5b", request.clientId);
    XCTAssertEqualObjects(@"user.read openid profile offline_access", request.scopes);
    XCTAssertEqualObjects(@"https://login.microsoft.com", request.redirectUri);
    XCTAssertNotNil(request.correlationId.UUIDString);
}

- (void)testInitWithJSONDictionary_whenAuthorityInvalid_shouldFail
{
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
        @"request": @{
            @"clientId": @"29a788ca-7bcf-4732-b23c-c8d294347e5b",
            @"scope": @"user.read openid profile offline_access",
            @"redirectUri": @"https://login.microsoft.com",
            @"authority": @"https://login.microsoftonline.com",
        }
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"authority must have AAD tenant.");
}

- (void)testInitWithJSONDictionary_whenAccountIdInvalid_shouldFail
{
    __auto_type json = @{
        @"sender": @"https://login.microsoft.com",
        @"request": @{
            @"clientId": @"29a788ca-7bcf-4732-b23c-c8d294347e5b",
            @"scope": @"user.read openid profile offline_access",
            @"redirectUri": @"https://login.microsoft.com",
            @"accountId": @"uidutid",
        }
    };
    
    NSError *error;
    __auto_type request = [[MSIDBrowserNativeMessageGetTokenRequest alloc] initWithJSONDictionary:json error:&error];
    
    XCTAssertNil(request);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"account Id is invalid.");
}


@end
