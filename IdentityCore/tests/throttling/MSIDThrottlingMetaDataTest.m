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
#import "NSDate+MSIDExtensions.h"
#import "MSIDThrottlingMetaData.h"
#import "MSIDCacheItemJsonSerializer.h"

@interface MSIDThrottlingMetaDataTest : XCTestCase

@end

@implementation MSIDThrottlingMetaDataTest

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testMetadataFromJSON_WhenValidJSON_shouldReturnMetadataObject
{
    NSDate *date = [NSDate new];
    NSDictionary *json = @{@"last_refresh_time": [date msidDateToTimestamp]};
    NSError *error;
    MSIDThrottlingMetaData *metadata = [[MSIDThrottlingMetaData alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(metadata);
    XCTAssertNil(error);
}

- (void)testMetadataFromJSON_WhenInvalidJSON_shouldReturnError
{
    NSDictionary *json = nil;
    NSError *error;
    MSIDThrottlingMetaData *metadata = [[MSIDThrottlingMetaData alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(metadata);
    XCTAssertNotNil(error);
}

- (void)test_whenValidMetadataObject_shouldReturnValidJSONDataOutput
{
    MSIDThrottlingMetaData *metadata = [MSIDThrottlingMetaData new];
    metadata.lastRefreshTime = [[NSDate new] msidDateToTimestamp];
    id<MSIDExtendedCacheItemSerializing> serializer = [MSIDCacheItemJsonSerializer new];
    NSData *itemData = [serializer serializeCacheItem:metadata];
    XCTAssertNotNil(itemData);
    
    //convert back to metadata object;
    NSError *error;
    MSIDThrottlingMetaData *convertBackMetadata = [[MSIDThrottlingMetaData alloc] initWithJSONData:itemData error:&error];
    XCTAssertNotNil(convertBackMetadata);
    XCTAssertNil(error);
}
@end
