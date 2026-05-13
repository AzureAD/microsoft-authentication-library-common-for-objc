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
#import "MSIDIntuneDeviceIdCache.h"
#import "MSIDTestCacheDataSource.h"

@interface MSIDIntuneDeviceIdCacheTests : XCTestCase

@property (nonatomic) MSIDIntuneDeviceIdCache *cache;
@property (nonatomic) MSIDTestCacheDataSource *dataSource;

@end

@implementation MSIDIntuneDeviceIdCacheTests

- (void)setUp
{
    self.dataSource = [MSIDTestCacheDataSource new];
    self.cache = [[MSIDIntuneDeviceIdCache alloc] initWithDataSource:self.dataSource];
}

- (void)tearDown
{
    [self.dataSource reset];
}

#pragma mark - setIntuneDeviceId

- (void)testSetIntuneDeviceId_whenDeviceIdIsNil_shouldReturnNOAndError
{
    NSError *error;
    BOOL result = [self.cache setIntuneDeviceId:nil context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetIntuneDeviceId_whenDeviceIdIsEmpty_shouldReturnNOAndError
{
    NSError *error;
    BOOL result = [self.cache setIntuneDeviceId:@"" context:nil error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
}

- (void)testSetIntuneDeviceId_whenDeviceIdIsValid_shouldReturnYESAndNoError
{
    NSError *error;
    BOOL result = [self.cache setIntuneDeviceId:@"test-device-id" context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testSetIntuneDeviceId_whenCalledTwice_shouldOverwritePreviousValue
{
    NSError *error;
    [self.cache setIntuneDeviceId:@"first-device-id" context:nil error:&error];

    error = nil;
    BOOL result = [self.cache setIntuneDeviceId:@"second-device-id" context:nil error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    NSString *stored = [self.cache intuneDeviceIdWithContext:nil error:&error];
    XCTAssertEqualObjects(stored, @"second-device-id");
}

#pragma mark - intuneDeviceIdWithContext

- (void)testIntuneDeviceId_whenNothingCached_shouldReturnNil
{
    NSError *error;
    NSString *deviceId = [self.cache intuneDeviceIdWithContext:nil error:&error];

    XCTAssertNil(deviceId);
    XCTAssertNil(error);
}

- (void)testIntuneDeviceId_afterSuccessfulSet_shouldReturnStoredValue
{
    NSError *error;
    [self.cache setIntuneDeviceId:@"my-device-id" context:nil error:nil];

    NSString *deviceId = [self.cache intuneDeviceIdWithContext:nil error:&error];

    XCTAssertEqualObjects(deviceId, @"my-device-id");
    XCTAssertNil(error);
}

#pragma mark - clear

- (void)testClear_whenCacheIsEmpty_shouldNotCrash
{
    XCTAssertNoThrow([self.cache clear]);
}

- (void)testClear_whenDeviceIdIsStored_shouldRemoveIt
{
    [self.cache setIntuneDeviceId:@"device-to-clear" context:nil error:nil];

    [self.cache clear];

    NSError *error;
    NSString *deviceId = [self.cache intuneDeviceIdWithContext:nil error:&error];
    XCTAssertNil(deviceId);
    XCTAssertNil(error);
}

@end
