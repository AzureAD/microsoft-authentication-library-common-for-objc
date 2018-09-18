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
#import "NSError+MSIDExtensions.h"

@interface MSIDErrorExtensionsTests : XCTestCase

@end

@implementation MSIDErrorExtensionsTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testErrorWithFilteringOptions_whenOptionIsFailingURLAndErrorContainsFailedUrlKey_shouldRemoveParametersFromUrl
{
    __auto_type failedUrl = [[NSURL alloc] initWithString:@"myapp://com.myapp/?code=some_code_value&session_state=12345678&x-client-Ver=2.6.4"];
    __auto_type userInfo = @{
                             NSLocalizedDescriptionKey: @"unsupported URL",
                             NSURLErrorFailingURLErrorKey: failedUrl,
                             NSURLErrorFailingURLStringErrorKey: failedUrl.absoluteString,
                             };
    __auto_type errorWithSensitiveInfo = [[NSError alloc] initWithDomain:@"domain" code:0 userInfo:userInfo];
    
    __auto_type resultError = [errorWithSensitiveInfo msidErrorWithFilteringOptions:MSIDErrorFilteringOptionRemoveUrlParameters];
    
    __auto_type expectedUrl = [[NSURL alloc] initWithString:@"myapp://com.myapp/"];
    __auto_type expectedUserInfo = @{
                                     NSLocalizedDescriptionKey: @"unsupported URL",
                                     NSURLErrorFailingURLErrorKey: expectedUrl,
                                     NSURLErrorFailingURLStringErrorKey: expectedUrl.absoluteString,
                                     };
    XCTAssertEqualObjects(expectedUserInfo, resultError.userInfo);
}

- (void)testErrorWithFilteringOptions_whenOptionIsNoneAndErrorContainsFailedUrlKey_shouldNotRemoveParametersFromUrl
{
    __auto_type failedUrl = [[NSURL alloc] initWithString:@"myapp://com.myapp/?code=some_code_value&session_state=12345678&x-client-Ver=2.6.4"];
    __auto_type userInfo = @{
                             NSLocalizedDescriptionKey: @"unsupported URL",
                             NSURLErrorFailingURLErrorKey: failedUrl,
                             NSURLErrorFailingURLStringErrorKey: failedUrl.absoluteString,
                             };
    __auto_type errorWithSensitiveInfo = [[NSError alloc] initWithDomain:@"domain" code:0 userInfo:userInfo];
    
    __auto_type resultError = [errorWithSensitiveInfo msidErrorWithFilteringOptions:MSIDErrorFilteringOptionNone];
    
    XCTAssertEqualObjects(userInfo, resultError.userInfo);
}

@end
