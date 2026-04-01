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
#import "MSIDResponseHeaderStore.h"

@interface MSIDResponseHeaderStoreTests : XCTestCase

@end

@implementation MSIDResponseHeaderStoreTests

- (void)testInit_shouldHaveNoHeaders
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    XCTAssertNotNil(store);
    XCTAssertEqual(store.allHeaders.count, 0);
}

- (void)testSetHeader_shouldStoreHeader
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:@"token123" forKey:@"X-Intune-AuthToken"];
    
    XCTAssertEqualObjects([store headerForKey:@"X-Intune-AuthToken"], @"token123");
}

- (void)testSetHeader_duplicateKey_shouldOverwrite
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:@"oldValue" forKey:@"X-Custom-Header"];
    [store setHeader:@"newValue" forKey:@"X-Custom-Header"];
    
    XCTAssertEqualObjects([store headerForKey:@"X-Custom-Header"], @"newValue");
}

- (void)testSetHeader_withNilValue_shouldNotStore
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:nil forKey:@"X-Custom-Header"];
    
    XCTAssertNil([store headerForKey:@"X-Custom-Header"]);
    XCTAssertEqual(store.allHeaders.count, 0);
}

- (void)testSetHeader_withNilKey_shouldNotStore
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:@"value" forKey:nil];
    
    XCTAssertEqual(store.allHeaders.count, 0);
}

- (void)testHeaderForKey_nonExistentKey_shouldReturnNil
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    NSString *value = [store headerForKey:@"NonExistent"];
    
    XCTAssertNil(value);
}

- (void)testAllHeaders_shouldReturnAllStoredHeaders
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:@"token123" forKey:@"X-Intune-AuthToken"];
    [store setHeader:@"https://install.com" forKey:@"X-Install-Url"];
    [store setHeader:@"telemetry" forKey:@"x-ms-clitelem"];
    
    NSDictionary *headers = store.allHeaders;
    
    XCTAssertEqual(headers.count, 3);
    XCTAssertEqualObjects(headers[@"X-Intune-AuthToken"], @"token123");
    XCTAssertEqualObjects(headers[@"X-Install-Url"], @"https://install.com");
    XCTAssertEqualObjects(headers[@"x-ms-clitelem"], @"telemetry");
}

- (void)testClearHeaders_shouldRemoveAllHeaders
{
    MSIDResponseHeaderStore *store = [[MSIDResponseHeaderStore alloc] init];
    
    [store setHeader:@"token123" forKey:@"X-Intune-AuthToken"];
    [store setHeader:@"https://install.com" forKey:@"X-Install-Url"];
    XCTAssertEqual(store.allHeaders.count, 2);
    
    [store clearHeaders];
    
    XCTAssertEqual(store.allHeaders.count, 0);
    XCTAssertNil([store headerForKey:@"X-Intune-AuthToken"]);
    XCTAssertNil([store headerForKey:@"X-Install-Url"]);
}

@end
