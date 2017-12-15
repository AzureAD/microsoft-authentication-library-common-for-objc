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
#import "MSIDURLFormObject.h"

@interface MSIDURLFormObject (TestUtils)

- (NSMutableDictionary *)form;

@end

@implementation MSIDURLFormObject (TestUtils)

- (NSMutableDictionary *)form
{
    return _urlForm;
}

- (void)setForm:(NSDictionary *)form
{
    _urlForm = [form mutableCopy];
}

@end

@interface MSIDURLFormObjectTests : XCTestCase

@end

@implementation MSIDURLFormObjectTests

- (void)testInitWithEncodedString_whenNilString_shouldReturnNilErrorNotNil
{
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithEncodedString:nil error:&error];
    
    XCTAssertNil(obj);
    XCTAssertNotNil(error);
}

- (void)testInitWithEncodedString_whenNonNilString_shouldReturnObjectNilError
{
    NSString *input = @"testkey2=value2&testkey1=value1";
    NSDictionary *outputDictionary = @{@"testkey1":@"value1", @"testkey2":@"value2"};
    
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithEncodedString:input error:&error];
    
    XCTAssertNotNil(obj);
    XCTAssertNil(error);
    XCTAssertEqualObjects(obj.form, outputDictionary);
}

- (void)testInitWithEncodedString_whenInvalidInputString_shouldReturnObjectEmptyForm
{
    NSString *input = @"testkey2=value2 testkey1=value1";
    
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithEncodedString:input error:&error];
    
    XCTAssertNotNil(obj);
    XCTAssertNil(error);
    XCTAssertEqualObjects(obj.form, @{});
}

- (void)testInitWithDictionary_whenNilDictionary_shouldReturnNilErrorNotNil
{
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithDictionary:nil error:&error];
    
    XCTAssertNil(obj);
    XCTAssertNotNil(error);
}

- (void)testInitWithDictionary_whenNonNilDictionary_shouldReturnObjectNilError
{
    NSDictionary *dictionary = @{@"testkey1":@"value1", @"testkey2":@"value2"};
    
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithDictionary:dictionary error:&error];
    
    XCTAssertNotNil(obj);
    XCTAssertNil(error);
    XCTAssertEqualObjects(obj.form, dictionary);
}

- (void)testEncode_whenNonNilInput_shouldReturnSerializedOutput
{
    NSDictionary *inputDictionary = @{@"test key1":@"value1 value 2", @"testkey2":@"value2"};
    NSString *encodedString = @"testkey2=value2&test+key1=value1+value+2";
    
    NSError *error = nil;
    MSIDURLFormObject *obj = [[MSIDURLFormObject alloc] initWithDictionary:inputDictionary error:&error];
    
    XCTAssertNotNil(obj);
    XCTAssertNil(error);
    XCTAssertEqualObjects([obj encode], encodedString);
}

@end
