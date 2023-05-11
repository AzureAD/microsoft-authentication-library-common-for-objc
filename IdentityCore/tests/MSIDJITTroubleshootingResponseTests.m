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

#if !EXCLUDE_FROM_MSALCPP

#import <XCTest/XCTest.h>
#import "MSIDJITTroubleshootingResponse.h"
#import "MSIDBrokerConstants.h"

@interface MSIDJITTroubleshootingResponseTests : XCTestCase

@end

@implementation MSIDJITTroubleshootingResponseTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIsJITTroubleshootingResponse_whenUrlNil_shouldReturnNil
{
    NSURL *url = nil;
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testIsJITTroubleshootingResponse_whenSchemeIncorrect_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"someother://code?querystring"];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testIsJITTroubleshootingResponse_whenHostIncorrect_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"msauth://code?querystring"];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNil(response);
    XCTAssertNotNil(error);
}

- (void)testIsJITTroubleshootingResponse_whenQueryIncorrect_shouldReturnNilStatusAndUnknownError
{
    NSURL *url = [NSURL URLWithString:@"msauth://compliance_status?querystring"];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(response.status);
    XCTAssertNil(error);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSError *errorFromResponse = [response getErrorFromResponseWithContext:nil];
#pragma clang diagnostic pop

    XCTAssertNotNil(errorFromResponse);
    XCTAssertEqual(errorFromResponse.code, MSIDErrorJITUnknownStatusWebCP);
}

- (void)testIsJITTroubleshootingResponse_whenQueryIncorrectValue_shouldReturnStatusAndUnknownError
{
    NSURL *url = [NSURL URLWithString:@"msauth://compliance_status?status=982634"];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertEqual([response.status intValue], 982634);
    XCTAssertNil(error);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSError *errorFromResponse = [response getErrorFromResponseWithContext:nil];
#pragma clang diagnostic pop

    XCTAssertNotNil(errorFromResponse);
    XCTAssertEqual(errorFromResponse.code, MSIDErrorJITUnknownStatusWebCP);
}

- (void)testIsJITTroubleshootingResponse_whenQueryCorrectValue_shouldReturnStatusAndJITRetryRequiredError
{
    NSURL *url = [NSURL URLWithString:@"msauth://compliance_status?status=4"];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertEqual([response.status intValue], 4);
    XCTAssertNil(error);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSError *errorFromResponse = [response getErrorFromResponseWithContext:nil];
#pragma clang diagnostic pop

    XCTAssertNotNil(errorFromResponse);
    XCTAssertEqual(errorFromResponse.code, MSIDErrorJITRetryRequired);
}

- (void)testIsJITTroubleshootingResponse_whenIsJITTroubleshootingResponse_shouldReturnStatusAndJITTTroubleshootingRequiredError
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"msauth://%@", JIT_TROUBLESHOOTING_HOST]];
    NSError *error;
    MSIDJITTroubleshootingResponse *response = [[MSIDJITTroubleshootingResponse alloc] initWithURL:url context:nil error:&error];

    XCTAssertNotNil(response);
    XCTAssertEqual([response.status intValue], 0);
    XCTAssertNil(error);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSError *errorFromResponse = [response getErrorFromResponseWithContext:nil];
#pragma clang diagnostic pop

    XCTAssertNotNil(errorFromResponse);
    XCTAssertEqual(errorFromResponse.code, MSIDErrorJITTroubleshootingRequired);
}


@end

#endif
