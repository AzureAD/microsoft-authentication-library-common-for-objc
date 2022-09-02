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
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDWebOpenBrowserAdditionalParameters.h"

@interface MSIDWebBrowserResponseTests : XCTestCase
@end

@implementation MSIDWebBrowserResponseTests
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[[MSIDWebOpenBrowserAdditionalParameters sharedInstance] queryParameters] removeAllObjects];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit_whenNoBrowserScheme_shouldReturnNilWithError
{
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://somehost"]]
                                                                                   context:nil
                                                                                     error:&error];
    
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqualObjects(error.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInit_whenBrowserInput_shouldReturnResponseWithNoError
{
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"browser://somehost"]]
                                                                                   context:nil
                                                                                     error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.browserURL.absoluteString, @"https://somehost");
}

- (void)testInit_whenBrowserInputWithNoQueryAndExtraQueryParameters_shouldReturnResponseWithNoError
{
    MSIDWebOpenBrowserAdditionalParameters *additionalParameters = [MSIDWebOpenBrowserAdditionalParameters sharedInstance];
    [additionalParameters addQueryParameterForKey:@"objectId" value:@"object-1234"];
    [additionalParameters addQueryParameterForKey:@"mdmId" value:@"mdm-1234"];
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"browser://somehost"]]
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.browserURL.scheme, @"https");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"objectId"], @"object-1234");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"mdmId"], @"mdm-1234");
    XCTAssertNil(response.browserURL.msidQueryParameters[@"not-existing-key"]);
    XCTAssertEqual([response.browserURL.msidQueryParameters count], 2);
}

- (void)testInit_whenBrowserInputWithExistingQueryAndExtraQueryParameters_shouldReturnResponseWithNoError
{
    MSIDWebOpenBrowserAdditionalParameters *additionalParameters = [MSIDWebOpenBrowserAdditionalParameters sharedInstance];
    [additionalParameters addQueryParameterForKey:@"new-objectId" value:@"object-1234"];
    [additionalParameters addQueryParameterForKey:@"mdmId" value:@"mdm-1234"];
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"browser://somehost?existing=1"]]
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.browserURL.scheme, @"https");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"new-objectId"], @"object-1234");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"mdmId"], @"mdm-1234");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"existing"], @"1");
    XCTAssertNil(response.browserURL.msidQueryParameters[@"not-existing-key"]);
    XCTAssertEqual([response.browserURL.msidQueryParameters count], 3);
}

- (void)testInit_whenBrowserInputWithExistingQueryAndExtraDuplicatedQueryParameters_shouldUpdateParameterAndReturnResponseWithNoError
{
    MSIDWebOpenBrowserAdditionalParameters *additionalParameters = [MSIDWebOpenBrowserAdditionalParameters sharedInstance];
    [additionalParameters addQueryParameterForKey:@"new-objectId" value:@"object-1234"];
    [additionalParameters addQueryParameterForKey:@"mdmId" value:@"mdm-1234"];
    [additionalParameters addQueryParameterForKey:@"new-objectId" value:@"new-value"];
    NSError *error = nil;
    MSIDWebOpenBrowserResponse *response = [[MSIDWebOpenBrowserResponse alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"browser://somehost?existing=1"]]
                                                                                   context:nil
                                                                                     error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.browserURL.scheme, @"https");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"new-objectId"], @"new-value");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"mdmId"], @"mdm-1234");
    XCTAssertEqualObjects(response.browserURL.msidQueryParameters[@"existing"], @"1");
    XCTAssertNil(response.browserURL.msidQueryParameters[@"not-existing-key"]);
    XCTAssertEqual([response.browserURL.msidQueryParameters count], 3);
}

@end
