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
#import "MSIDAccountCredentialCache.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDBasicContext.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "MSIDTestSwizzle.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDJsonObject.h"

@interface MSIDFRTEnabledStatusTests : XCTestCase

@property (nonatomic) MSIDAccountCredentialCache *cache;
@property (nonatomic) MSIDBasicContext *context;

@end

@implementation MSIDFRTEnabledStatusTests

- (void)setUp
{
    [super setUp];
    
    MSIDTestCacheDataSource *dataSource = [[MSIDTestCacheDataSource alloc] init];
    self.cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
    self.context = [MSIDBasicContext new];
    
    // Reset FRT settings before each test
    [MSIDAccountCredentialCache setDisableFRT:NO];
}

- (void)tearDown
{
    [MSIDTestSwizzle removeAllSwizzling];
    [super tearDown];
}

#pragma mark - Feature flag enabled tests

- (void)testCheckFRTEnabled_whenFeatureFlagEnabled_andKeychainEnabled_shouldReturnEnabled
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusEnabled);
}

- (void)testCheckFRTEnabled_whenFeatureFlagEnabled_andKeychainDisabled_shouldReturnDisabledByKeychainItem
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    
    [self saveFRTEnabledKeychain:NO];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByKeychainItem);
}

- (void)testCheckFRTEnabled_whenFeatureFlagEnabled_andNoKeychainItem_shouldReturnDisabledByKeychainItem
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByKeychainItem);
}

#pragma mark - Feature flag disabled tests

- (void)testCheckFRTEnabled_whenFeatureFlagDisabled_andKeychainEnabled_shouldReturnDisabledByFeatureFlag
{
    [self setUseSingleFRTFeatureFlagMock:NO];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByFeatureFlag);
}

- (void)testCheckFRTEnabled_whenFeatureFlagDisabled_andKeychainDisabled_shouldReturnDisabledByFeatureFlag
{
    [self setUseSingleFRTFeatureFlagMock:NO];
    
    [self saveFRTEnabledKeychain:NO];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByFeatureFlag);
}

#pragma mark - Client-side disable tests

- (void)testCheckFRTEnabled_whenClientDisabled_shouldReturnDisabledByClientApp
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    [MSIDAccountCredentialCache setDisableFRT:YES];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByClientApp);
}

#pragma mark - Keychain corruption tests

- (void)testCheckFRTEnabled_whenKeychainCorrupted_shouldReturnDisabledByDeserializationError
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    
    // Save corrupted data to keychain
    [self saveCorruptedFRTKeychain];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByDeserializationError);
}

#pragma mark - Feature flag nil/empty tests

- (void)testCheckFRTEnabled_whenFeatureFlagNil_andKeychainEnabled_shouldReturnEnabled
{
    [self setUseSingleFRTFeatureFlagMock:nil];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusEnabled);
}

- (void)testCheckFRTEnabled_whenFeatureFlagEmpty_andKeychainEnabled_shouldReturnEnabled
{
    [self setUseSingleFRTFeatureFlagWithValue:@""];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusEnabled);
}

- (void)testCheckFRTEnabled_whenFeatureFlagInvalidValue_andKeychainEnabled_shouldReturnEnabled
{
    [self setUseSingleFRTFeatureFlagWithValue:@"invalid_value"];
    
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusEnabled);
}

#pragma mark - Update FRT settings tests

- (void)testUpdateFRTSettings_whenEnableFRT_shouldSaveCorrectValue
{
    NSError *error = nil;
    [self.cache updateFRTSettings:YES context:self.context error:&error];
    
    XCTAssertNil(error);
    
    // Verify the settings were saved correctly
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    XCTAssertNil(error);
    // Note: Since no feature flag is set, this will use keychain value
    [self setUseSingleFRTFeatureFlagWithValue:nil];
    result = [self.cache checkFRTEnabled:self.context error:&error];
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusEnabled);
}

- (void)testUpdateFRTSettings_whenDisableFRT_shouldSaveCorrectValue
{
    NSError *error = nil;
    [self.cache updateFRTSettings:NO context:self.context error:&error];
    
    XCTAssertNil(error);
    
    // Verify the settings were saved correctly
    [self setUseSingleFRTFeatureFlagWithValue:nil];
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByKeychainItem);
}

#pragma mark - Error handling tests

- (void)testCheckFRTEnabled_whenDataSourceFails_shouldHandleError
{
    // Use a data source that will fail
    MSIDAccountCredentialCache *failingCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:nil];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [failingCache checkFRTEnabled:self.context error:&error];
    
    // Should still return a valid status even with data source failure
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByKeychainItem);
}

#pragma mark - Combined scenarios tests

- (void)testCheckFRTEnabled_complexScenario_featureFlagEnabledClientDisabled_shouldReturnDisabledByClientApp
{
    [self setUseSingleFRTFeatureFlagMock:YES];
    [MSIDAccountCredentialCache setDisableFRT:YES];
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByClientApp);
}

- (void)testCheckFRTEnabled_complexScenario_featureFlagDisabledKeychainEnabled_shouldReturnDisabledByFeatureFlag
{
    [self setUseSingleFRTFeatureFlagMock:NO];
    [self saveFRTEnabledKeychain:YES];
    
    NSError *error = nil;
    MSIDIsFRTEnabledStatus result = [self.cache checkFRTEnabled:self.context error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result, MSIDIsFRTEnabledStatusDisabledByFeatureFlag);
}

#pragma mark - Helper methods

- (void)setUseSingleFRTFeatureFlagMock:(BOOL)useSingleFRTStatus
{
    [self setUseSingleFRTFeatureFlagWithValue:useSingleFRTStatus ? MSID_FRT_STATUS_ENABLED : MSID_FRT_STATUS_DISABLED];
}

- (void)setUseSingleFRTFeatureFlagMock:(NSString *)flagValue
{
    [self setUseSingleFRTFeatureFlagWithValue:flagValue];
}

- (void)setUseSingleFRTFeatureFlagWithValue:(NSString *)flagValue
{
    [MSIDTestSwizzle instanceMethod:@selector(stringForKey:)
                              class:[MSIDFlightManager class]
                              block:(id)^(__unused id obj, NSString *flightKey)
     {
        if ([flightKey isEqualToString:MSID_FLIGHT_CLIENT_SFRT_STATUS])
        {
            return flagValue;
        }
        
        return @"";
     }];
}

- (void)saveFRTEnabledKeychain:(BOOL)enabled
{
    NSError *error = nil;
    NSDictionary *json = @{MSID_USE_SINGLE_FRT_KEY: @(enabled)};
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:json error:nil];
    
    [self.cache.dataSource saveJsonObject:jsonObject
                               serializer:[MSIDCacheItemJsonSerializer new]
                                      key:[self checkFRTCacheKey]
                                  context:nil
                                    error:&error];
    
    XCTAssertNil(error);
}

- (void)saveCorruptedFRTKeychain
{
    // Save invalid JSON data
    NSData *corruptedData = [@"invalid json" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    
    [self.cache.dataSource saveData:corruptedData
                                key:[self checkFRTCacheKey]
                            context:nil
                              error:&error];
}

- (MSIDCacheKey *)checkFRTCacheKey
{
    static MSIDCacheKey *cacheKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheKey = [[MSIDCacheKey alloc] initWithAccount:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                 service:MSID_USE_SINGLE_FRT_KEYCHAIN
                                                 generic:nil
                                                    type:nil];
    });
    return cacheKey;
}

@end