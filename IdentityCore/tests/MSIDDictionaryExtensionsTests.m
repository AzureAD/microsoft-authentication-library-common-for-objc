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
#import "NSDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "NSMutableDictionary+MSIDExtensions.h"

@interface MSIDDictionaryExtensionsTests : XCTestCase

@end

@implementation MSIDDictionaryExtensionsTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testmsidDictionaryFromURLEncodedString_whenStringContainsQuery_shouldReturnDictWithoutDecoding
{
    NSString *string = @"key=val+val";
    NSDictionary *dict = [NSDictionary msidDictionaryFromURLEncodedString:string];
    
    XCTAssertTrue([[dict allKeys] containsObject:@"key"]);
    XCTAssertEqualObjects(dict[@"key"], @"val+val");
}

- (void)testmsidDictionaryFromWWWFormURLEncodedString_whenStringContainsQuery_shouldReturnDictWithDecoding
{
    NSString *string = @"key=Some+interesting+test%2F%2B-%29%28%2A%26%5E%25%24%23%40%21~%7C%3D";
    NSDictionary *dict = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:string];
    
    XCTAssertTrue([[dict allKeys] containsObject:@"key"]);
    XCTAssertEqualObjects(dict[@"key"], @"Some interesting test/+-)(*&^%$#@!~|=");
}

- (void)testmsidDictionaryFromURLEncodedString_whenMalformedQuery_shouldReturnDictWithoutBadQuery
{
    NSString *string = @"key=val+val&malformed=v1=v2&=nokey&noval&doubleEqualButEncoded=2%3D2&";
    NSDictionary *dict = [NSDictionary msidDictionaryFromURLEncodedString:string];
    
    XCTAssertTrue(dict.count == 3);
    XCTAssertTrue([dict.allKeys containsObject:@"key"]);
    XCTAssertTrue([dict.allKeys containsObject:@"noval"]);
    XCTAssertTrue([dict.allKeys containsObject:@"doubleEqualButEncoded"]);
    
    XCTAssertFalse([dict.allKeys containsObject:@"malformed"]);
    XCTAssertFalse([dict.allKeys containsObject:@""]);
    
    XCTAssertEqualObjects(dict[@"key"], @"val+val");
    XCTAssertEqualObjects(dict[@"noval"], @"");
    XCTAssertEqualObjects(dict[@"doubleEqualButEncoded"], @"2=2");
}

- (void)testMsidDictionaryByRemovingFields_whenNilKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key":@"",
                                      @"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    NSDictionary *resultDictionary = [inputDictionary msidDictionaryByRemovingFields:nil];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testMsidDictionaryByRemovingFields_whenEmptyKeysArray_shouldNotRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSDictionary *resultDictionary = [inputDictionary msidDictionaryByRemovingFields:@[]];
    XCTAssertEqualObjects(inputDictionary, resultDictionary);
}

- (void)testMsidDictionaryByRemovingFields_whenDictionaryWithFields_shouldRemoveFields
{
    NSDictionary *inputDictionary = @{@"key1": @"value1",
                                      @"key2": @"value2",
                                      @"key3": @"value3"};
    
    NSArray *keysArray = @[@"key2", @"key1"];
    NSDictionary *resultDictionary = [inputDictionary msidDictionaryByRemovingFields:keysArray];
    
    NSDictionary *expectedDictionary = @{@"key3": @"value3"};
    XCTAssertEqualObjects(resultDictionary, expectedDictionary);
}

- (void)testMsidSetObjectIfNotNil_whenNilKey_shouldDoNothingAndReturnFalse
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertFalse([dic msidSetObjectIfNotNil:@"value" forKey:nil]);
    XCTAssertTrue(dic.count==0);
}

- (void)testMsidSetObjectIfNotNil_whenNilValue_shouldDoNothingAndReturnFalse
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertFalse([dic msidSetObjectIfNotNil:nil forKey:@"key"]);
    XCTAssertTrue(dic.count==0);
}

- (void)testMsidSetObjectIfNotNil_whenNonEmptyValue_shouldSetItAndReturnYes
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertTrue([dic msidSetObjectIfNotNil:@"value" forKey:@"key"]);
    XCTAssertTrue(dic.count==1);
}

- (void)testMsidSetNonEmptyString_whenNilKey_shouldDoNothingAndReturnFalse
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertFalse([dic msidSetNonEmptyString:@"value" forKey:nil]);
    XCTAssertTrue(dic.count==0);
}

- (void)testMsidSetNonEmptyString_whenNilValue_shouldDoNothingAndReturnFalse
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertFalse([dic msidSetNonEmptyString:nil forKey:@"key"]);
    XCTAssertTrue(dic.count==0);
}

- (void)testMsidSetNonEmptyString_whenEmptyValue_shouldDoNothingAndReturnFalse
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertFalse([dic msidSetNonEmptyString:@"" forKey:@"key"]);
    XCTAssertTrue(dic.count==0);
}

- (void)testMsidSetNonEmptyString_whenNonEmptyValue_shouldSetItAndReturnYes
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    XCTAssertTrue([dic msidSetNonEmptyString:@"value" forKey:@"key"]);
    XCTAssertTrue(dic.count==1);
}
    
- (void)testMsidStringForKey_whenNilKey_shouldReturnNil
{
    NSDictionary *dictionary = [NSDictionary new];
    NSString *result = [dictionary msidStringObjectForKey:nil];
    XCTAssertNil(result);
}

- (void)testMsidStringForKey_whenValueMissing_shouldReturnNil
{
    NSDictionary *dictionary = @{@"key1": @"value2"};
    NSString *result = [dictionary msidStringObjectForKey:@"missing"];
    XCTAssertNil(result);
}

- (void)testMsidStringForKey_whenNullValuePresent_andIsBlank_shouldReturnNil
{
    NSDictionary *dictionary = @{@"key1": [NSNull null]};
    NSString *result = [dictionary msidStringObjectForKey:@"key1"];
    XCTAssertNil(result);
}

- (void)testMsidStringForKey_whenValuePresent_andIsString_shouldReturnValue
{
    NSDictionary *dictionary = @{@"key1": @"value1"};
    NSString *result = [dictionary msidStringObjectForKey:@"key1"];
    XCTAssertEqualObjects(result, @"value1");
}

- (void)testMsidStringForKey_whenValuePresent_andNotString_shouldReturnNil
{
    NSDictionary *dictionary = @{@"key1": [NSNull null]};
    NSString *result = [dictionary msidStringObjectForKey:@"key1"];
    XCTAssertNil(result);
}

- (void)testMSIDNormalizedDictionary_whenNoNulls_returnDictionary
{
    NSDictionary *input = @{@"test1": @"test2", @"tets3": @"test4"};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(input, result);
}

- (void)testMSIDNormalizedDictionary_whenDictionaryContainsNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"test1": @"test2", @"test3": @"test4", @"null-test": [NSNull null]};
    NSDictionary *expectedResult = @{@"test1": @"test2", @"test3": @"test4"};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

- (void)testMSIDNormalizedDictionary_whenDictionaryContainsDictionariesWithNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"test1":@"test2", @"test3": @"test4", @"test5": @{@"test1": [NSNull null], @"test2": @"test3", @"test4": @{@"test5": [NSNull null]}}};
    NSDictionary *expectedResult = @{@"test1":@"test2", @"test3": @"test4", @"test5": @{@"test2": @"test3", @"test4": @{}}};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

- (void)testMSIDNornalizedDictionary_whenDictionaryContainsArraysWithDictionariesWithNulls_returnNormalizedDictionary
{
    NSDictionary *input = @{@"input1": @"test2", @"test3": @[[NSNull null], @{@"test1": @{@"test1": [NSNull null], @"test3": @"test4"}}]};
    NSDictionary *expectedResult = @{@"input1": @"test2", @"test3": @[@{@"test1": @{@"test3": @"test4"}}]};
    NSDictionary *result = [input msidNormalizedJSONDictionary];
    XCTAssertEqualObjects(expectedResult, result);
}

- (void)testMSIDAssertTypeIsOneOf_whenTypeIsWrong_shouldReturnError
{
    NSDictionary *json = @{@"some_key": @4};
    
    NSError *error;
    BOOL result = [json msidAssertTypeIsOneOf:@[NSString.class] ofKey:@"some_key" required:YES context:nil errorCode:5 error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 5);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"some_key key in dictionary is not of expected type. Allowed types: NSString.");
}

- (void)testMSIDAssertTypeIsOneOf_whenTypeCorrect_shouldReturnTrue
{
    NSDictionary *json = @{@"some_key": @"4"};
    
    NSError *error;
    BOOL result = [json msidAssertTypeIsOneOf:@[NSString.class] ofKey:@"some_key" required:YES context:nil errorCode:5 error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testMSIDAssertTypeIsOneOf_whenFieldIsOptionalAndMissed_shouldReturnTrue
{
    NSDictionary *json = @{@"some_key_2": @"4"};
    
    NSError *error;
    BOOL result = [json msidAssertTypeIsOneOf:@[NSString.class] ofKey:@"some_key" required:NO context:nil errorCode:5 error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testMSIDAssertTypeIsOneOf_whenFieldIsRequiredAndMissed_shouldReturnTrue
{
    NSDictionary *json = @{@"some_key_2": @"4"};
    
    NSError *error;
    BOOL result = [json msidAssertTypeIsOneOf:@[NSString.class] ofKey:@"some_key" required:YES context:nil errorCode:5 error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, 5);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"some_key key is missing in dictionary.");
}

- (void)testMsidArrayOfIntegersForKey_whenTypeIsWrong_shouldReturnNil
{
    NSString *key = @"key1";
    
    NSDictionary *dictionaryWithString = @{key: @"test"};
    NSArray<NSNumber *> *resultWithString = [dictionaryWithString msidArrayOfIntegersForKey:key];
    XCTAssertNil(resultWithString);
    
    NSDictionary *dictionaryWithInteger = @{key: @1};
    NSArray<NSNumber *> *resultWithInteger = [dictionaryWithInteger msidArrayOfIntegersForKey:key];
    XCTAssertNil(resultWithInteger);
    
    NSDictionary *dictionaryWithBool = @{key: @true};
    NSArray<NSNumber *> *resultWithBool = [dictionaryWithBool msidArrayOfIntegersForKey:key];
    XCTAssertNil(resultWithBool);
}

- (void)testMsidArrayOfIntegersForKey_whenArrayContentIsWrong_shouldReturnNil
{
    NSString *key = @"key1";
    
    NSDictionary *dictionaryWithString = @{key: @[@"test"]};
    NSArray<NSNumber *> *resultWithString = [dictionaryWithString msidArrayOfIntegersForKey:key];
    XCTAssertNil(resultWithString);
    
    NSDictionary *dictionary = @{key: @[@1, @"test"]};
    NSArray<NSNumber *> *result = [dictionary msidArrayOfIntegersForKey:key];
    XCTAssertNil(result);
}

- (void)testMsidArrayOfIntegersForKey_whenTypeIsCorrect_shouldReturnValue
{
    NSString *key = @"key1";
    
    NSDictionary *dictionary = @{key: @[@1, @2, @3]};
    NSArray<NSNumber *> *result = [dictionary msidArrayOfIntegersForKey:key];
    NSArray<NSNumber *> *expectedResult = @[@1, @2, @3];
    XCTAssertEqualObjects(result, expectedResult);
    
    NSDictionary *dictionaryEmptyArray = @{key: @[]};
    NSArray<NSNumber *> *resultEmptyArray = [dictionaryEmptyArray msidArrayOfIntegersForKey:key];
    NSArray<NSNumber *> *expectedResultEmptyArray = @[];
    XCTAssertEqualObjects(resultEmptyArray, expectedResultEmptyArray);
}

@end
