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
#import "NSString+MSIDTelemetryExtensions.h"
#import "MSIDTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDTelemetryExtensionsTests : XCTestCase

@end

@implementation MSIDTelemetryExtensionsTests

- (void)testParsedClientTelemetry_whenBlankTelemetry_shouldReturnEmptyDictionary
{
    NSString *clientTelemetry = @" ";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertTrue([parsedTelemetry count] == 0);
}

- (void)testParsedClientTelemetry_whenTooLittleComponents_shouldReturnEmptyDictionary
{
    NSString *clientTelemetry = @"1,0,0";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertTrue([parsedTelemetry count] == 0);
}

- (void)testParsedClientTelemetry_whenTooManyComponents_shouldReturnDictionaryWithFirstElements
{
    NSString *clientTelemetry = @"1,123,1234,255.0643,0,0,1234,";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO], @"0");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE], @"123");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE], @"1234");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE], @"255.0643");
}

- (void)testParsedClientTelemetry_whenWrongVersionNumberButEnoughElements_shouldReturnDictionaryWithFirstElements
{
    NSString *clientTelemetry = @"2,123,1234,255.0643,";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO]);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE], @"123");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE], @"1234");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE], @"255.0643");
}

- (void)testParsedClientTelemetry_whenAllComponentsNoSPEInfo_shouldReturnAllOtherPropertiesNilSPEInfo
{
    NSString *clientTelemetry = @"1,123,1234,255.0643,";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO]);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE], @"123");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE], @"1234");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE], @"255.0643");
}

- (void)testParsedClientTelemetry_whenAllComponentsNoSPEInfoNoRTAge_shouldReturnAllOtherPropertiesNilSPEInfoNilRTAge
{
    NSString *clientTelemetry = @"1,123,1234,,";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO]);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE]);
}

- (void)testParsedClientTelemetry_whenAllComponentsWithSPEInfo_shouldReturnAllProperties
{
    NSString *clientTelemetry = @"1,123,1234,255.0643,I";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE], @"123");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE], @"1234");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE], @"255.0643");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO], @"I");
}

- (void)testParsedClientTelemetry_whenErrorSubErrorHaveZeroesRtAgeEmpty_shouldReturnOnlySpeInfo
{
    NSString *clientTelemetry = @"1,0,0,,I";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE]);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE]);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE]);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO], @"I");
}

- (void)testParsedClientTelemetry_whenErrorHasZeroes_shouldReturnAllPropertiesButErrorCode
{
    NSString *clientTelemetry = @"1,0,5,200.5,I";
    
    NSDictionary *parsedTelemetry = [clientTelemetry msidParsedClientTelemetry];
    
    XCTAssertNotNil(parsedTelemetry);
    XCTAssertNil([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE]);
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE], @"5");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_RT_AGE], @"200.5");
    XCTAssertEqualObjects([parsedTelemetry objectForKey:MSID_TELEMETRY_KEY_SPE_INFO], @"I");
}

@end
