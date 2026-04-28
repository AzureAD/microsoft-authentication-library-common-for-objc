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
#import "MSIDWebMDMEnrollmentCompletionResponse.h"

@interface MSIDMDMEnrollmentCompletionResponseTests : XCTestCase

@end

@implementation MSIDMDMEnrollmentCompletionResponseTests

#pragma mark - Init Tests

- (void)testInit_whenWrongScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"https://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenWrongHost_shouldReturnNilWithError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://wrong_host?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenNilURL_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:nil
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenValidURLWithSuccessStatus_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"success");
    XCTAssertNil(response.errorUrl);
    XCTAssertTrue(response.isSuccess);
}

- (void)testInit_whenValidURLWithSuccessStatusUpperCase_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=SUCCESS"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"SUCCESS");
    XCTAssertTrue(response.isSuccess);
}

- (void)testInit_whenValidURLWithCheckInTimedOutStatus_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=check_in_timed_out"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"check_in_timed_out");
    XCTAssertNil(response.errorUrl);
    XCTAssertTrue(response.isSuccess);
}

- (void)testInit_whenValidURLWithCheckInTimedOutStatusUpperCase_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=CHECK_IN_TIMED_OUT"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"CHECK_IN_TIMED_OUT");
    XCTAssertTrue(response.isSuccess);
}

- (void)testInit_whenValidURLWithErrorUrl_shouldReturnResponseWithErrorUrl
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success&errorUrl=https://example.com/error"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"success");
    XCTAssertEqualObjects(response.errorUrl, @"https://example.com/error");
    XCTAssertTrue(response.isSuccess);
}

- (void)testInit_whenValidURLWithNoStatus_shouldReturnResponseWithNoStatus
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertNil(response.status);
    XCTAssertFalse(response.isSuccess);
}

- (void)testInit_whenValidURLWithEmptyStatus_shouldReturnResponseWithEmptyStatus
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status="];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"");
    XCTAssertFalse(response.isSuccess);
}

- (void)testInit_whenValidURLWithFailureStatus_shouldReturnResponseWithFailureStatus
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=failed"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"failed");
    XCTAssertFalse(response.isSuccess);
}

- (void)testInit_whenHostIsCaseInsensitive_shouldReturnResponse
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://In_App_Enrollment_Complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.status, @"success");
    XCTAssertTrue(response.isSuccess);
}

#pragma mark - isSuccess Tests

- (void)testIsSuccess_whenStatusIsSuccess_shouldReturnYES
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=success"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertTrue(response.isSuccess);
}

- (void)testIsSuccess_whenStatusIsCheckInTimedOut_shouldReturnYES
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=check_in_timed_out"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertTrue(response.isSuccess);
}

- (void)testIsSuccess_whenStatusIsNil_shouldReturnNO
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertFalse(response.isSuccess);
}

- (void)testIsSuccess_whenStatusIsEmpty_shouldReturnNO
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status="];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertFalse(response.isSuccess);
}

- (void)testIsSuccess_whenStatusIsFailed_shouldReturnNO
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=failed"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertFalse(response.isSuccess);
}

- (void)testIsSuccess_whenStatusIsUnknown_shouldReturnNO
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:@"msauth://in_app_enrollment_complete?status=unknown"];
    MSIDWebMDMEnrollmentCompletionResponse *response = [[MSIDWebMDMEnrollmentCompletionResponse alloc] initWithURL:url
                                                                                                            context:nil
                                                                                                              error:&error];
    
    XCTAssertFalse(response.isSuccess);
}

#pragma mark - Operation Tests

- (void)testOperation_shouldReturnCorrectOperationString
{
    NSString *operation = [MSIDWebMDMEnrollmentCompletionResponse operation];
    XCTAssertEqualObjects(operation, @"mdm_enrollment_completion_operation");
}

@end
