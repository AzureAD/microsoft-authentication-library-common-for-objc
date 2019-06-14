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
#import "MSIDMaskedLogParameter.h"
#import "MSIDLogger+Internal.h"

@interface MSIDMaskedLogParameterTests : XCTestCase

@end

@implementation MSIDMaskedLogParameterTests

- (void)testDescription_whenPIIDisabled_andParameterOfNSStringType_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:@"secret-test"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Masked(not-null)");
}

- (void)testDescription_whenPIIEnabled_andParameterOfNSStringType_shouldReturnRawValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:@"secret-test"];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"secret-test");
}

- (void)testDescription_whenPIIDisabled_andParameterOfArrayType_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    NSArray *param = @[@"1", @"2", @"3"];
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:param];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"MaskedArray(count=3)");
}

- (void)testDescription_whenPIIDisabled_andParameterOfErrorType_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    NSError *error = MSIDCreateError(MSIDErrorDomain, -10003, @"test", @"invalid_grant", @"bad_token", nil, nil, nil);
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:error];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"MaskedError(MSIDErrorDomain, -10003)");
}

- (void)testDescription_whenPIIEnabled_andParameterOfErrorType_shouldReturnNonMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    NSError *error = MSIDCreateError(MSIDErrorDomain, -10003, @"test", @"invalid_grant", @"bad_token", nil, nil, nil);
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:error];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Error Domain=MSIDErrorDomain Code=-10003 \"(null)\" UserInfo={MSIDOAuthErrorKey=invalid_grant, MSIDOAuthSubErrorKey=bad_token, MSIDErrorDescriptionKey=test}");
}

- (void)testDescription_whenPIIDisabled_andParameterOfNSNullType_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:[NSNull null]];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Masked(not-null)");
}

- (void)testDescription_whenPIIEnabled_andParameterOfNSNullType_shouldReturnNonMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:[NSNull null]];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"<null>");
}

- (void)testDescription_whenPIIEnabled_andNilParameter_shouldReturnNonMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    NSString *param = nil;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:param];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"Masked(null)");
}

- (void)testDescription_whenPIIEnabled_andNilParameter_shouldReturnMaskedValue
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    NSString *param = nil;
    MSIDMaskedLogParameter *logParameter = [[MSIDMaskedLogParameter alloc] initWithParameterValue:param];
    NSString *description = [logParameter description];
    XCTAssertEqualObjects(description, @"(null)");
}

@end
