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
#import "MSIDMaskedUsernameLogParameter.h"

@interface MSIDMaskedUsernameLogParameterTests : XCTestCase

@end

@implementation MSIDMaskedUsernameLogParameterTests

- (void)testDescription_whenPIINotEnabled_andNilParameter_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    NSString *param = nil;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:param];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Masked(null)");
}

- (void)testDescription_whenPIINotEnabled_andNsNullParameter_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:[NSNull null]];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Masked(not-null)");
}

- (void)testDescription_whenPIINotEnabled_andEmailParameter_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"test@email.com"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"auth.placeholder-9f86d081__email.com");
}

- (void)testDescription_whenPIINotEnabled_andEmailParameterWithoutUsername_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"@email.com"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"auth.placeholder-e3b0c442__email.com");
}


- (void)testDescription_whenPIINotEnabled_andEmailParameterWithoutEmailSign_shouldReturnHashedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"contoso.email.com"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"2bf9fb0e");
}

- (void)testDescription_whenPIINotEnabled_andEmailParameterWithNoDomain_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"test@"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"auth.placeholder-9f86d081__");
}

- (void)testDescription_whenPIINotEnabled_andEmailParameterWithNoDomain_andSpaceChar_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"test@ "];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"auth.placeholder-9f86d081__ ");
}

- (void)testDescription_whenPIINotEnabled_andEmailParameterWithDomain_shouldReturnSameMaskedValueForDifferentCase
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDMaskedUsernameLogParameter *logParameter = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"username@domain.com"];
    MSIDMaskedUsernameLogParameter *logParameter1 = [[MSIDMaskedUsernameLogParameter alloc] initWithParameterValue:@"UserNamE@domAIN.com"];
    NSString *description = [logParameter description];
    NSString *description1 = [logParameter1 description];
    XCTAssertEqualObjects(description, @"auth.placeholder-16f78a7d__domain.com");
    XCTAssertEqualObjects(description, description1);
}

@end
