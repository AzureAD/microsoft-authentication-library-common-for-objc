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

NSString *symmetericKeyString = @"Zfb98mJBAt/UOpnCI/CYdQ==";
NSString *message = @"Sample Message To Encrypt/Decrypt";
NSString *context = @"y00sIKRcF2bPFDgbeOques0ymB+R0FP";
NSString *expectedSignature = @"cspzWzvtSNOJUUzThP3FWWV-9q7mJ_ZB6PYzRcQwe54";

@implementation MSIDSymmetricKeyTests

- (void)testGenerateSymmetericKey_andGetRaw{
    MSIDSymmetricKey *symmetricKey = [[MSIDSymmetricKey alloc] initWithSymmetericKeyBase64:symmetericKeyString];
    XCTAssertNotNil(symmetricKey);

    NSString *rawKey = [symmetricKey getRaw];
    XCTAssertEqualObjects(symmetericKeyString, rawKey);
}

- (void)testCreateVerifySignature
{
    NSData *symmetericKeyBytes = [[NSData alloc] initWithBase64EncodedString:symmetericKeyString options:0];
    MSIDSymmetricKey *symmetricKey = [[MSIDSymmetricKey alloc] initWithSymmetericKeyBytes:symmetericKeyBytes];
    XCTAssertNotNil(symmetricKey);

    NSData *contextData = [NSData msidDataFromBase64UrlEncodedString:context];
    NSString *signature = [symmetricKey createVerifySignature:contextData dataToSign:message];
    XCTAssertEqualObjects(expectedSignature, signature);
}

@end
