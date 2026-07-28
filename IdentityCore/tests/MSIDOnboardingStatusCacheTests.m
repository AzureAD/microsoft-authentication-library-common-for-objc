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
#import "MSIDCacheKey.h"
#import "MSIDJsonObject.h"

@interface MSIDOnboardingStatusCache ()

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;
@property (nonatomic) MSIDCacheItemJsonSerializer *serializer;

- (MSIDCacheKey *)cacheKey;
- (BOOL)isOwnerOverride:(MSIDOnboardingStatus *)status;

@end

@interface MSIDOnboardingStatusCacheTests : XCTestCase

@property (nonatomic) MSIDOnboardingStatusCache *cache;
@property (nonatomic) MSIDTestCacheDataSource *testDataSource;
@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> originalDataSource;

@end

@implementation MSIDOnboardingStatusCacheTests

- (void)setUp
{
    [super setUp];
    self.cache = MSIDOnboardingStatusCache.sharedInstance;
    self.originalDataSource = MSIDOnboardingStatusCache.sharedInstance.dataSource;
    self.testDataSource = [MSIDTestCacheDataSource new];
    self.cache.dataSource = self.testDataSource;
}

- (void)tearDown
{
    // Reset to clean state
    [self.testDataSource reset];
    MSIDOnboardingStatusCache.sharedInstance.dataSource = self.originalDataSource;
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
    XCTAssertNotNil(status, @"Failed to create status: %@", error);
    return status;
}

- (NSString *)isoStringFromDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return [formatter stringFromDate:date];
}

- (NSMutableDictionary *)statusJSONWithPhase:(MSIDOnboardingPhase)phase
                               correlationId:(NSString *)correlationId
                                    startedAt:(NSDate *)startedAt
{
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"version"] = @1;
    json[@"phase"] = [MSIDOnboardingStatus stringFromPhase:phase];
    json[@"context"] = [MSIDOnboardingStatus stringFromContext:MSIDOnboardingContextBroker];
    json[@"originatingDisplayName"] = @"Teams";
    json[@"correlationId"] = correlationId;
    json[@"ttlSeconds"] = @900;
    json[@"reason"] = @{@"code": @"none", @"message": @""};

    if (startedAt)
    {
        json[@"startedAt"] = [self isoStringFromDate:startedAt];
    }

    return json;
}

- (BOOL)writeStatusJSONDirectly:(NSDictionary *)json
{
    NSError *error = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(jsonObject, @"Failed to create JSON object: %@", error);

    BOOL result = [self.testDataSource saveJsonObject:jsonObject
                                           serializer:self.cache.serializer
                                                  key:[self.cache cacheKey]
                                              context:nil
                                                error:&error];
    XCTAssertTrue(result, @"Failed to write status JSON directly: %@", error);
    return result;
}

- (NSArray<MSIDJsonObject *> *)readStatusJSONDirectly
{
    NSError *error = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [self.testDataSource jsonObjectsWithKey:[self.cache cacheKey]
                                                                          serializer:self.cache.serializer
                                                                             context:nil
                                                                               error:&error];
    XCTAssertNotNil(jsonObjects, @"Failed to read status JSON directly: %@", error);
    return jsonObjects;
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

- (void)test_setWithStatus_whenCurrentStatusHasNilOriginatingBundleId_rejectsOverwriteFromDifferentApp
{
    NSString *originalCorrelationId = @"11111111-1111-1111-1111-111111111111";
    NSMutableDictionary *json = [self statusJSONWithPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                            correlationId:originalCorrelationId
                                                startedAt:[NSDate date]];
    XCTAssertTrue([self writeStatusJSONDirectly:json]);

    MSIDOnboardingStatus *newStatus = [self statusWithOwner:@"com.different.owner"
                                                originating:@"com.different.app"
                                                      phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                                 ttlSeconds:900
                                                  startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:newStatus];

    XCTAssertFalse(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqualObjects(retrieved.correlationId, [[NSUUID alloc] initWithUUIDString:originalCorrelationId]);
}

- (void)test_clear_whenCurrentStatusHasNilBundleIds_returnsNo
{
    NSMutableDictionary *json = [self statusJSONWithPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                            correlationId:@"22222222-2222-2222-2222-222222222222"
                                                startedAt:[NSDate date]];
    XCTAssertTrue([self writeStatusJSONDirectly:json]);

    BOOL result = [self.cache clear:@"com.any.bundle"];

    XCTAssertFalse(result);
    XCTAssertEqual([self readStatusJSONDirectly].count, 1);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
}

- (void)test_getOnboardingStatus_whenStartedAtMissing_treatsAsExpiredAndPurges
{
    NSMutableDictionary *json = [self statusJSONWithPhase:MSIDOnboardingPhaseFailed
                                            correlationId:@"33333333-3333-3333-3333-333333333333"
                                                startedAt:nil];
    json[@"ownerBundleId"] = @"com.microsoft.azureauthenticator";
    json[@"originatingBundleId"] = @"com.microsoft.teams";
    XCTAssertTrue([self writeStatusJSONDirectly:json]);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];

    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseNone);
    XCTAssertEqual([self readStatusJSONDirectly].count, 0);

    MSIDOnboardingStatus *secondRetrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(secondRetrieved.phase, MSIDOnboardingPhaseNone);
}

- (void)test_setWithStatus_concurrent_serializesAndDoesNotCorrupt
{
    NSMutableDictionary *jsonA = [self statusJSONWithPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             correlationId:@"44444444-4444-4444-4444-444444444444"
                                                 startedAt:[NSDate date]];
    jsonA[@"ownerBundleId"] = @"com.microsoft.azureauthenticator";
    jsonA[@"originatingBundleId"] = @"com.microsoft.teams";

    NSMutableDictionary *jsonB = [self statusJSONWithPhase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                             correlationId:@"55555555-5555-5555-5555-555555555555"
                                                 startedAt:[NSDate date]];
    jsonB[@"ownerBundleId"] = @"com.microsoft.azureauthenticator";
    jsonB[@"originatingBundleId"] = @"com.microsoft.teams";

    NSError *error = nil;
    MSIDOnboardingStatus *statusA = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:jsonA error:&error];
    XCTAssertNotNil(statusA, @"Failed to create status A: %@", error);

    error = nil;
    MSIDOnboardingStatus *statusB = [[MSIDOnboardingStatus alloc] initWithJSONDictionary:jsonB error:&error];
    XCTAssertNotNil(statusB, @"Failed to create status B: %@", error);

    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_group_t group = dispatch_group_create();
    __block BOOL resultA = NO;
    __block BOOL resultB = NO;

    dispatch_group_async(group, concurrentQueue, ^{
        resultA = [self.cache setWithStatus:statusA];
    });
    dispatch_group_async(group, concurrentQueue, ^{
        resultB = [self.cache setWithStatus:statusB];
    });

    long waitResult = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(waitResult, 0);
    XCTAssertTrue(resultA);
    XCTAssertTrue(resultB);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertTrue([retrieved.correlationId isEqual:statusA.correlationId] || [retrieved.correlationId isEqual:statusB.correlationId]);
}

#pragma mark - isInProgressPhase

- (void)testIsInProgressPhase_whenBrokerInteractiveInProgress_shouldReturnYES
{
    XCTAssertTrue([self.cache isInProgressPhase:MSIDOnboardingPhaseBrokerInteractiveInProgress]);
}

- (void)testIsInProgressPhase_whenMdmEnrollmentInProgress_shouldReturnYES
{
    XCTAssertTrue([self.cache isInProgressPhase:MSIDOnboardingPhaseMdmEnrollmentInProgress]);
}

- (void)testIsInProgressPhase_whenNone_shouldReturnNO
{
    XCTAssertFalse([self.cache isInProgressPhase:MSIDOnboardingPhaseNone]);
}

- (void)testIsInProgressPhase_whenFailed_shouldReturnNO
{
    XCTAssertFalse([self.cache isInProgressPhase:MSIDOnboardingPhaseFailed]);
}

#pragma mark - setWithStatus terminal phase overwrite

- (void)testSetWithStatus_whenCurrentPhaseFailedFromDifferentApp_shouldOverwrite
{
    // App A leaves a terminal (failed) status behind.
    MSIDOnboardingStatus *failed = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                             originating:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseFailed
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];
    XCTAssertTrue([self.cache setWithStatus:failed]);

    // A different app (B) must be allowed to overwrite a terminal status.
    MSIDOnboardingStatus *fromOtherApp = [self statusWithOwner:@"com.microsoft.outlook"
                                                   originating:@"com.microsoft.outlook"
                                                         phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                                    ttlSeconds:900
                                                     startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:fromOtherApp];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseBrokerInteractiveInProgress);
    XCTAssertEqualObjects(retrieved.originatingBundleId, @"com.microsoft.outlook");
}

- (void)testSetWithStatus_whenCurrentPhaseMdmEnrollmentInProgressFromDifferentApp_shouldReturnNO
{
    // App A has an in-progress (MDM enrollment) status.
    MSIDOnboardingStatus *inProgress = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                 originating:@"com.microsoft.teams"
                                                       phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                                  ttlSeconds:900
                                                   startedAt:[NSDate date]];
    XCTAssertTrue([self.cache setWithStatus:inProgress]);

    // A different app (B) must NOT be allowed to overwrite an in-progress status.
    MSIDOnboardingStatus *fromOtherApp = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   originating:@"com.microsoft.outlook"
                                                         phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                                    ttlSeconds:900
                                                     startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:fromOtherApp];

    XCTAssertFalse(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseMdmEnrollmentInProgress);
    XCTAssertEqualObjects(retrieved.originatingBundleId, @"com.microsoft.teams");
}

@end
