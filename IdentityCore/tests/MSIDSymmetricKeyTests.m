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
#import "MSIDSymmetricKey.h"
#import "NSData+MSIDExtensions.h"

@interface MSIDSymmetricKeyTests : XCTestCase

@end

@implementation MSIDSymmetricKeyTests

- (void)testGenerateSymmetericKey
{
    NSString *symmetericKeyString = @"Zfb98mJBAt/UOpnCI/CYdQ==";
    NSData *symmetericKeyBytes = [[NSData alloc] initWithBase64EncodedString:symmetericKeyString options:0];
    MSIDSymmetricKey *symmetricKey = [[MSIDSymmetricKey alloc] initWithSymmetericKeyBytes:symmetericKeyBytes];
    XCTAssertNotNil(symmetricKey);
    NSString *rawKey = [symmetricKey getRaw];
    XCTAssertNotNil(rawKey);
    
    NSString *message = @"Sample Message To Encrypt/Decrypt";
    NSString *context = @"y00sIKRcF2bPFDgbeOques0ymB+R0FP";
    NSString *iv = @"4JYp0efd0Wxokdl3";
    NSString *authData = @"eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIiwiY3R4IjoieTAwc0lLUmNGMmJQRkRnYmVPcXVlczBZUG1CK1IwRlAifQ";
    
    NSData* messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSData* contextData = [NSData msidDataFromBase64UrlEncodedString:context];
    NSData* ivData = [NSData msidDataFromBase64UrlEncodedString:iv];
    NSData* authDataData = [authData dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAesGcmInfo *aesGcmInfo = [symmetricKey encryptUsingAuthenticatedAesForTest:messageData contextBytes:contextData iv:ivData authenticationData:authDataData];
    XCTAssertNotNil(aesGcmInfo);
    
    NSData* cipherText = [aesGcmInfo cipherText];
    NSData* authTag = [aesGcmInfo authTag];
    NSString* decryptedMessage = [symmetricKey decryptUsingAuthenticatedAes:cipherText contextBytes:contextData iv:ivData authenticationTag:authTag authenticationData:authDataData];
    XCTAssertNotNil(decryptedMessage);
    
    XCTAssertEqualObjects(message, decryptedMessage);
}

@end
