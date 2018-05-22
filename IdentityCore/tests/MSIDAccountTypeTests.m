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
#import "MSIDAccountType.h"

@interface MSIDAccountTypeTests : XCTestCase

@end

@implementation MSIDAccountTypeTests

- (void)testAccountTypeAsString_whenAADV1Type_shouldReturnAADTypeString
{
    NSString *result = [MSIDAccountTypeHelpers accountTypeAsString:MSIDAccountTypeAADV1];
    XCTAssertEqualObjects(result, @"AAD");
}

- (void)testAccountTypeAsString_whenAADV2Type_shouldReturnAADV2TypeString
{
    NSString *result = [MSIDAccountTypeHelpers accountTypeAsString:MSIDAccountTypeMSSTS];
    XCTAssertEqualObjects(result, @"MSSTS");
}

- (void)testAccountTypeAsString_whenMSAType_shouldReturnMSATypeString
{
    NSString *result = [MSIDAccountTypeHelpers accountTypeAsString:MSIDAccountTypeMSA];
    XCTAssertEqualObjects(result, @"MSA");
}

- (void)testAccountTypeAsString_whenOtherType_shouldReturnOtherTypeString
{
    NSString *result = [MSIDAccountTypeHelpers accountTypeAsString:MSIDAccountTypeOther];
    XCTAssertEqualObjects(result, @"Other");
}

- (void)testAccountTypeFromString_whenAADV1Type_shouldReturnAADTypeString
{
    MSIDAccountType result = [MSIDAccountTypeHelpers accountTypeFromString:@"AAD"];
    XCTAssertEqual(result, MSIDAccountTypeAADV1);
}

- (void)testAccountTypeFromString_whenAADV2Type_shouldReturnAADV2TypeString
{
    MSIDAccountType result = [MSIDAccountTypeHelpers accountTypeFromString:@"MSSTS"];
    XCTAssertEqual(result, MSIDAccountTypeMSSTS);
}

- (void)testAccountTypeFromString_whenMSAType_shouldReturnMSATypeString
{
    MSIDAccountType result = [MSIDAccountTypeHelpers accountTypeFromString:@"MSA"];
    XCTAssertEqual(result, MSIDAccountTypeMSA);
}

- (void)testAccountTypeFromString_whenOtherType_shouldReturnOtherTypeString
{
    MSIDAccountType result = [MSIDAccountTypeHelpers accountTypeFromString:@"Other"];
    XCTAssertEqual(result, MSIDAccountTypeOther);
}


@end
