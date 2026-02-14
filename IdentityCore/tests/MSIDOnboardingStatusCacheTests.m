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
#import "MSIDOnboardingStatusCache.h"
#import "MSIDOnboardingStatus.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDBrokerConstants.h"

@interface MSIDOnboardingStatusCache ()

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;
@property (nonatomic) MSIDCacheItemJsonSerializer *serializer;

- (BOOL)isOwnerOverride:(MSIDOnboardingStatus *)status;

@end

@interface MSIDOnboardingStatusCacheTests : XCTestCase

@property (nonatomic) MSIDOnboardingStatusCache *cache;
@property (nonatomic) MSIDTestCacheDataSource *testDataSource;

@end

@implementation MSIDOnboardingStatusCacheTests

- (void)setUp
{
    [super setUp];
    self.cache = MSIDOnboardingStatusCache.sharedInstance;
    self.testDataSource = [MSIDTestCacheDataSource new];
    self.cache.dataSource = self.testDataSource;
}

- (void)tearDown
{
    // Reset to clean state
    [self.testDataSource reset];
    [super tearDown];
}

#pragma mark - Helper

- (MSIDOnboardingStatus *)statusWithOwner:(NSString *)ownerBundleId
                                    phase:(MSIDOnboardingPhase)phase
                               ttlSeconds:(NSInteger)ttl
                                startedAt:(NSDate *)startedAt
{
    return [self statusWithOwner:ownerBundleId
                     originating:@"com.microsoft.teams"
                           phase:phase
                      ttlSeconds:ttl
                       startedAt:startedAt];
}

- (MSIDOnboardingStatus *)statusWithOwner:(NSString *)ownerBundleId
                              originating:(NSString *)originatingBundleId
                                    phase:(MSIDOnboardingPhase)phase
                               ttlSeconds:(NSInteger)ttl
                                startedAt:(NSDate *)startedAt
{
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"version"] = @1;
    json[@"phase"] = [MSIDOnboardingStatus stringFromPhase:phase];
    json[@"context"] = [MSIDOnboardingStatus stringFromContext:MSIDOnboardingContextBroker];
    json[@"ownerBundleId"] = ownerBundleId;
    json[@"originatingBundleId"] = originatingBundleId;
    json[@"originatingDisplayName"] = @"Teams";
    json[@"correlationId"] = @"00000000-0000-0000-0000-000000000000";
    json[@"ttlSeconds"] = @(ttl);
    
    if (startedAt)
    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        json[@"startedAt"] = [formatter stringFromDate:startedAt];
    }
    
    json[@"reason"] = @{@"code": @"none", @"message": @""};
    
    NSError *error = nil;
    MSIDOnboardingStatus *status = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];
    NSAssert(status != nil, @"Failed to create status: %@", error);
    return status;
}

#pragma mark - getOnboardingStatus

- (void)testGetOnboardingStatus_whenNothingCached_shouldReturnDefaultStatus
{
    MSIDOnboardingStatus *status = [self.cache getOnboardingStatus];

    XCTAssertNotNil(status);
    XCTAssertEqual(status.phase, MSIDOnboardingPhaseNone);
}

- (void)testGetOnboardingStatus_whenStatusCached_shouldReturnCachedStatus
{
    MSIDOnboardingStatus *original = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                     phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                                ttlSeconds:900
                                                 startedAt:[NSDate date]];

    BOOL writeResult = [self.cache setWithStatus:original];
    XCTAssertTrue(writeResult);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];

    XCTAssertNotNil(retrieved);
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqualObjects(retrieved.ownerBundleId, @"com.microsoft.azureauthenticator");
}

- (void)testGetOnboardingStatus_whenStatusExpired_shouldReturnDefaultStatus
{
    // Create a status that started 2000 seconds ago with a 900-second TTL
    NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-2000];
    MSIDOnboardingStatus *expired = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                    phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                               ttlSeconds:900
                                                startedAt:pastDate];

    [self.cache setWithStatus:expired];

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];

    XCTAssertNotNil(retrieved);
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseNone);
}

- (void)testGetOnboardingStatus_whenStatusNotExpired_shouldReturnCachedStatus
{
    NSDate *recentDate = [NSDate dateWithTimeIntervalSinceNow:-100];
    MSIDOnboardingStatus *valid = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                  phase:MSIDOnboardingPhaseFailed
                                             ttlSeconds:900
                                              startedAt:recentDate];

    [self.cache setWithStatus:valid];

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];

    XCTAssertNotNil(retrieved);
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseFailed);
}

#pragma mark - setWithStatus

- (void)testSetWithStatus_whenNilStatus_shouldReturnNO
{
    MSIDOnboardingStatus *nilStatus = nil;
    BOOL result = [self.cache setWithStatus:nilStatus];

    XCTAssertFalse(result);
}

- (void)testSetWithStatus_whenNothingCached_shouldSucceed
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:status];

    XCTAssertTrue(result);
}

- (void)testSetWithStatus_whenSameOriginatingBundleId_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                            originating:@"com.microsoft.teams"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:second];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseMdmEnrollmentInProgress);
}

- (void)testSetWithStatus_whenDifferentOriginatingBundleId_shouldReturnNO
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                            originating:@"com.microsoft.teams"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.outlook"
                                                   phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:second];

    XCTAssertFalse(result);
}

- (void)testSetWithStatus_whenDifferentOriginatingBundleIdButOwnerOverride_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.another.app"
                                            originating:@"com.microsoft.teams"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    // Owner override: new status owned by current app bundle ID (test host)
    // Even with different originatingBundleId, the override should succeed
    NSString *currentBundleId = [[NSBundle mainBundle] bundleIdentifier];
    MSIDOnboardingStatus *overrideStatus = [self statusWithOwner:currentBundleId
                                                     originating:@"com.microsoft.outlook"
                                                           phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                                      ttlSeconds:900
                                                       startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:overrideStatus];

    XCTAssertTrue(result);
}

- (void)testSetWithStatus_whenOriginatingBundleIdMatchIsCaseInsensitive_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                            originating:@"com.Microsoft.Teams"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseFailed
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:second];

    XCTAssertTrue(result);
}

#pragma mark - clear

- (void)testClear_whenNilBundleId_shouldReturnNO
{
    NSString *nilBundleId = nil;
    BOOL result = [self.cache clear:nilBundleId];

    XCTAssertFalse(result);
}

- (void)testClear_whenEmptyBundleId_shouldReturnNO
{
    BOOL result = [self.cache clear:@""];

    XCTAssertFalse(result);
}

- (void)testClear_whenNothingCached_shouldReturnYES
{
    BOOL result = [self.cache clear:@"com.microsoft.azureauthenticator"];

    XCTAssertTrue(result);
}

- (void)testClear_whenMatchingBundleId_shouldRemoveAndReturnYES
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    BOOL result = [self.cache clear:@"com.microsoft.azureauthenticator"];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseNone);
}

- (void)testClear_whenNonMatchingBundleId_shouldReturnNO
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    BOOL result = [self.cache clear:@"com.microsoft.other.app"];

    XCTAssertFalse(result);

    // Verify status is still there
    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
}

- (void)testClear_whenBundleIdMatchIsCaseInsensitive_shouldRemoveAndReturnYES
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    BOOL result = [self.cache clear:@"com.Microsoft.AzureAuthenticator"];

    XCTAssertTrue(result);
}

- (void)testClear_whenOriginatingBundleIdMatches_shouldRemoveAndReturnYES
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    // Clear using the originating bundle ID instead of owner bundle ID
    BOOL result = [self.cache clear:@"com.microsoft.teams"];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseNone);
}

- (void)testClear_whenOriginatingBundleIdMatchIsCaseInsensitive_shouldRemoveAndReturnYES
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    // Clear using the originating bundle ID with different case
    BOOL result = [self.cache clear:@"com.Microsoft.Teams"];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseNone);
}

- (void)testClear_whenNeitherOwnerNorOriginatingBundleIdMatches_shouldReturnNO
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    [self.cache setWithStatus:status];

    // Clear using a bundle ID that matches neither owner nor originating
    BOOL result = [self.cache clear:@"com.microsoft.outlook"];

    XCTAssertFalse(result);

    // Verify status is still there
    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
}

#pragma mark - isOwnerOverride

- (void)testIsOwnerOverride_whenOwnerMatchesCurrentBundleId_shouldReturnYES
{
    // The current bundle ID in tests is the test host's bundle ID
    NSString *currentBundleId = [[NSBundle mainBundle] bundleIdentifier];
    MSIDOnboardingStatus *status = [self statusWithOwner:currentBundleId
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache isOwnerOverride:status];

    XCTAssertTrue(result);
}

- (void)testIsOwnerOverride_whenOwnerDoesNotMatchCurrentBundleId_shouldReturnNO
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.other.app"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache isOwnerOverride:status];

    XCTAssertFalse(result);
}

#pragma mark - setWithStatus then getOnboardingStatus roundtrip

- (void)testSetAndGet_shouldPreserveAllFields
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSDate *startDate = [NSDate date];
    
    NSDictionary *json = @{
        @"version": @1,
        @"phase": @"failed",
        @"context": @"inAppWebview",
        @"ownerBundleId": @"com.microsoft.azureauthenticator",
        @"originatingBundleId": @"com.microsoft.outlook",
        @"originatingDisplayName": @"Outlook",
        @"correlationId": @"12345678-1234-1234-1234-123456789abc",
        @"startedAt": [formatter stringFromDate:startDate],
        @"ttlSeconds": @1800,
        @"reason": @{@"code": @"network", @"message": @"Network error"}
    };
    
    NSError *error = nil;
    MSIDOnboardingStatus *original = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(original);
    XCTAssertNil(error);

    BOOL writeResult = [self.cache setWithStatus:original];
    XCTAssertTrue(writeResult);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];

    XCTAssertNotNil(retrieved);
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseFailed);
    XCTAssertEqual(retrieved.onboardingContext, MSIDOnboardingContextInAppWebview);
    XCTAssertEqualObjects(retrieved.ownerBundleId, @"com.microsoft.azureauthenticator");
    XCTAssertEqualObjects(retrieved.originatingBundleId, @"com.microsoft.outlook");
    XCTAssertEqualObjects(retrieved.originatingDisplayName, @"Outlook");
    XCTAssertEqual(retrieved.ttlSeconds, 1800);
    XCTAssertNotNil(retrieved.reason);
    XCTAssertEqual(retrieved.reason.code, MSIDOnboardingReasonCodeNetwork);
    XCTAssertEqualObjects(retrieved.reason.message, @"Network error");
}

@end
