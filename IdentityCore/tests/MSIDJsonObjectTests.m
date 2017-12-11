//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDJsonObject.h"

@interface MSIDJsonObject (TestUtils)

- (NSMutableDictionary *)json;

@end

@implementation MSIDJsonObject (TestUtils)

- (NSMutableDictionary *)json
{
    return _json;
}

- (void)setJson:(NSDictionary *)json
{
    _json = [json mutableCopy];
}

@end

@interface MSIDJsonObjectTests : XCTestCase

@end

@implementation MSIDJsonObjectTests

- (void)testInitWithJSONData_whenDataProvided_shouldReturnObjectNilError
{
    NSString* testJson = @"{ \"testKey\" : \"testValue\" }";
    NSData* testJsonData = [testJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError* error = nil;
    MSIDJsonObject* obj = [[MSIDJsonObject alloc] initWithJSONData:testJsonData error:&error];
    XCTAssertNotNil(obj);
    XCTAssertNil(error);
    XCTAssertEqualObjects(obj.json, @{ @"testKey" : @"testValue"} );
}

- (void)testSerializeJsonData_whenDataProvided_shouldReturnDeserializableJSONData
{
    NSError *error = nil;
    NSDictionary *testJson = @{ @"testKey" : @"testValue" };
    MSIDJsonObject *obj = [MSIDJsonObject new];
    obj.json = testJson;
    NSData *data = [obj serialize:&error];
    XCTAssertNotNil(data);
    XCTAssertNil(error);
    
    MSIDJsonObject *obj2 = [[MSIDJsonObject alloc] initWithJSONData:data error:&error];
    XCTAssertNotNil(obj2);
    XCTAssertNil(error);
    XCTAssertEqualObjects(obj2.json, testJson);
}

- (void)testInitWithJSONData_whenNilData_shouldReturnNilObjectNonNilError
{
    NSError *error = nil;
    MSIDJsonObject* obj = [[MSIDJsonObject alloc] initWithJSONData:nil error:&error];
    XCTAssertNil(obj);
    XCTAssertNotNil(error);
}

- (void)testInitWithJSONData_whenInvalidJSON_shouldReturnNilObjectNonNilError
{
    NSString* testJson = @"{ sdgahsdujkiohasoldikasjdl;asjmdas }";
    NSData* testJsonData = [testJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError* error = nil;
    MSIDJsonObject* obj = [[MSIDJsonObject alloc] initWithJSONData:testJsonData error:&error];
    XCTAssertNil(obj);
    XCTAssertNotNil(error);
}

@end
