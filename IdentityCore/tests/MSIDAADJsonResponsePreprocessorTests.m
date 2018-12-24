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
#import "MSIDAADJsonResponsePreprocessor.h"

@interface MSIDAADJsonResponsePreprocessorTests : XCTestCase

@property (nonatomic) MSIDAADJsonResponsePreprocessor *preprocessor;

@end

@implementation MSIDAADJsonResponsePreprocessorTests

- (void)setUp
{
    [super setUp];
    
    self.preprocessor = [MSIDAADJsonResponsePreprocessor new];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testResponseObjectForResponse_shouldParseClientTelementry
{
    __auto_type jsonData = @{@"p" : @"v"};
    __auto_type data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:nil];
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type clientTelemetry = @"1,123,1234,255.0643,I";
    __auto_type headers = @{MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE : @"correlation_id_value",
                            MSID_OAUTH2_CLIENT_TELEMETRY : clientTelemetry};
    __auto_type response = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:0 HTTPVersion:nil headerFields:headers];
    
    id serializedResponse = [self.preprocessor responseObjectForResponse:response data:data context:nil error:nil];
    
    XCTAssertEqualObjects(serializedResponse[@"spe_info"], @"I");
    XCTAssertEqualObjects(serializedResponse[@"correlation_id"], @"correlation_id_value");
    XCTAssertEqualObjects(serializedResponse[@"p"], @"v");
}

- (void)testResponseObjectForResponse_whenJsonIsArray_shouldReturnError
{
    __auto_type jsonData = @[@{@"p" : @"v"}];
    __auto_type data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:nil];
    __auto_type baseUrl = [[NSURL alloc] initWithString:@"https://fake.url"];
    __auto_type response = [[NSHTTPURLResponse alloc] initWithURL:baseUrl statusCode:0 HTTPVersion:nil headerFields:nil];
    
    NSError *error;
    id serializedResponse = [self.preprocessor responseObjectForResponse:response data:data context:nil error:&error];
    
    XCTAssertNil(serializedResponse);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

@end
