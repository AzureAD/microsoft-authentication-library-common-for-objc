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
#import "MSIDBrokerOperationPasskeyAssertionRequest.h"

@interface MSIDBrokerOperationPasskeyAssertionRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationPasskeyAssertionRequestTests

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testOperation_shouldBeCorrect
{
    XCTAssertEqualObjects(@"passkey_assertion_operation", [MSIDBrokerOperationPasskeyAssertionRequest operation]);
}

- (void)testJsonDictionary_whenDataExist_shouldBeCorrect
{
    __auto_type request = [MSIDBrokerOperationPasskeyAssertionRequest new];
    request.brokerKey = @"some key";
    request.protocolVersion = 1;
    
    request.clientDataHash = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIGNsaWVudCBkYXRhIGhhc2g=" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    request.relyingPartyId = @"login.microsoft.com";
    request.keyId = [[NSData alloc] initWithBase64EncodedString:@"c2FtcGxlIGtleSBJRA==" options:NSDataBase64DecodingIgnoreUnknownCharacters];

    __auto_type expectedJson = @{@"broker_key": @"some key",
                                 @"msg_protocol_ver": @"1",
                                 @"clientDataHash": @"73616d706c6520636c69656e7420646174612068617368",
                                 @"relyingPartyId": @"login.microsoft.com",
                                 @"keyId": @"73616d706c65206b6579204944"};
    XCTAssertEqualObjects(expectedJson, [request jsonDictionary]);
}

- (void)testJsonDictionary_whenInitWithDictionary_shouldBeConvertedBackToDictionary
{
    __auto_type initialJson = @{@"broker_key": @"some key",
                                 @"msg_protocol_ver": @"1",
                                 @"clientDataHash": @"73616d706c6520636c69656e7420646174612068617368",
                                 @"relyingPartyId": @"login.microsoft.com",
                                 @"keyId": @"73616d706c65206b6579204944"};
    
    __auto_type request = [[MSIDBrokerOperationPasskeyAssertionRequest alloc] initWithJSONDictionary:initialJson error:nil];
    
    XCTAssertEqualObjects(initialJson, [request jsonDictionary]);
}

@end
