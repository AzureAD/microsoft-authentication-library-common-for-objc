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

- (BOOL)isBrokerOverride:(MSIDOnboardingStatus *)status;

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
    return [[MSIDOnboardingStatus alloc] initWithVersion:1
                                                   phase:phase
                                       onboardingContext:MSIDOnboardingContextBroker
                                           ownerBundleId:ownerBundleId
                                     originatingBundleId:@"com.microsoft.teams"
                                 originatingDisplayName:@"Teams"
                                           correlationId:[[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"]
                                               startedAt:startedAt ?: [NSDate date]
                                              ttlSeconds:ttl
                                                  reason:[[MSIDOnboardingReason alloc] initWithCode:MSIDOnboardingReasonCodeNone message:@""]];
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

- (void)testSetWithStatus_whenSameOwner_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                   phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:second];

    XCTAssertTrue(result);

    MSIDOnboardingStatus *retrieved = [self.cache getOnboardingStatus];
    XCTAssertEqual(retrieved.phase, MSIDOnboardingPhaseMdmEnrollmentInProgress);
}

- (void)testSetWithStatus_whenDifferentOwner_shouldReturnNO
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.azureauthenticator"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.another.app"
                                                   phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:second];

    XCTAssertFalse(result);
}

- (void)testSetWithStatus_whenDifferentOwnerButBrokerOverride_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.microsoft.another.app"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    // Broker override: new status owned by broker app bundle ID
    MSIDOnboardingStatus *brokerStatus = [self statusWithOwner:MSID_BROKER_APP_BUNDLE_ID
                                                         phase:MSIDOnboardingPhaseMdmEnrollmentInProgress
                                                    ttlSeconds:900
                                                     startedAt:[NSDate date]];

    BOOL result = [self.cache setWithStatus:brokerStatus];

    XCTAssertTrue(result);
}

- (void)testSetWithStatus_whenOwnerMatchIsCaseInsensitive_shouldSucceed
{
    MSIDOnboardingStatus *first = [self statusWithOwner:@"com.Microsoft.AzureAuthenticator"
                                                  phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                             ttlSeconds:900
                                              startedAt:[NSDate date]];
    [self.cache setWithStatus:first];

    MSIDOnboardingStatus *second = [self statusWithOwner:@"com.microsoft.azureauthenticator"
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

#pragma mark - isBrokerOverride

- (void)testIsBrokerOverride_whenOwnerIsBrokerBundleId_shouldReturnYES
{
    MSIDOnboardingStatus *status = [self statusWithOwner:MSID_BROKER_APP_BUNDLE_ID
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache isBrokerOverride:status];

    XCTAssertTrue(result);
}

- (void)testIsBrokerOverride_whenOwnerIsNotBrokerBundleId_shouldReturnNO
{
    MSIDOnboardingStatus *status = [self statusWithOwner:@"com.microsoft.teams"
                                                   phase:MSIDOnboardingPhaseBrokerInteractiveInProgress
                                              ttlSeconds:900
                                               startedAt:[NSDate date]];

    BOOL result = [self.cache isBrokerOverride:status];

    XCTAssertFalse(result);
}

#pragma mark - setWithStatus then getOnboardingStatus roundtrip

- (void)testSetAndGet_shouldPreserveAllFields
{
    NSUUID *correlationId = [[NSUUID alloc] initWithUUIDString:@"12345678-1234-1234-1234-123456789abc"];
    MSIDOnboardingReason *reason = [[MSIDOnboardingReason alloc] initWithCode:MSIDOnboardingReasonCodeNetwork message:@"Network error"];
    NSDate *startDate = [NSDate date];

    MSIDOnboardingStatus *original = [[MSIDOnboardingStatus alloc] initWithVersion:1
                                                                             phase:MSIDOnboardingPhaseFailed
                                                                 onboardingContext:MSIDOnboardingContextInAppWebview
                                                                     ownerBundleId:@"com.microsoft.azureauthenticator"
                                                               originatingBundleId:@"com.microsoft.outlook"
                                                           originatingDisplayName:@"Outlook"
                                                                     correlationId:correlationId
                                                                         startedAt:startDate
                                                                        ttlSeconds:1800
                                                                            reason:reason];

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
