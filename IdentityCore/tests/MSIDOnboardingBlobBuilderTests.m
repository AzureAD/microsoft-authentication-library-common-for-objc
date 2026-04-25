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
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDSessionCachePersistence.h"

static NSString * const kTestSuiteName = @"test.MSIDOnboardingBlobBuilderTests";
static NSString * const kCacheKey = @"com.microsoft.oneauth.session_correlation_cache";

@interface MSIDSessionCachePersistence ()

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;

@end

@interface MSIDOnboardingBlobBuilder ()

@property (nonatomic) MSIDSessionCachePersistence *sessionCachePersistence;

@end

@interface MSIDOnboardingBlobBuilderTests : XCTestCase

@property (nonatomic) NSUserDefaults *testDefaults;

@end

@implementation MSIDOnboardingBlobBuilderTests

- (void)setUp
{
    [super setUp];
    self.testDefaults = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [self.testDefaults removeObjectForKey:kCacheKey];
}

- (void)tearDown
{
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kTestSuiteName];
    [super tearDown];
}

#pragma mark - Helpers

- (NSString *)seedJsonWithVersion:(NSString *)version
                    correlationId:(NSString *)correlationId
                             mode:(NSString *)mode
{
    NSDictionary *seed = @{
        @"schema_version" : version,
        @"sessionCorrelationId" : correlationId,
        @"onboardingMode" : mode
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)parsedJsonFromBlob:(NSString *)blob
{
    NSData *data = [blob dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (NSDate *)dateFromISO8601String:(NSString *)isoString
{
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    return [formatter dateFromString:isoString];
}

- (MSIDOnboardingBlobBuilder *)builderWithTestDefaults
{
    NSString *seed = [self seedJsonWithVersion:@"1.0" correlationId:@"abc-123" mode:@"brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"clientA" target:@"resource1"];
    builder.sessionCachePersistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];
    return builder;
}

#pragma mark - Init

- (void)testInit_whenValidSeedJson_shouldParseSeedFields
{
    NSString *seed = [self seedJsonWithVersion:@"1.0" correlationId:@"abc-123" mode:@"non_brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);
}

- (void)testInit_whenEmptyJson_shouldUseEmptyDefaults
{
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:@"" clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);

    NSString *result = [builder finalizeBlob];
    XCTAssertEqualObjects(result, @"");
}

- (void)testInit_whenInvalidJson_shouldUseEmptyDefaults
{
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:@"not json" clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);

    [builder addBlockingError:@"65001"];
    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"schema_version"], @"");
    XCTAssertEqualObjects(parsed[@"sessionCorrelationId"], @"");
    XCTAssertEqualObjects(parsed[@"onboardingMode"], @"");
}

#pragma mark - addStep

- (void)testAddStep_whenCalled_shouldRecordStepEntry
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    NSDate *timestamp = [self dateFromISO8601String:@"2025-10-29T15:03:17.270Z"];
    [builder addStep:@"AuthenticationStarted" timestamp:timestamp];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    NSArray *steps = parsed[@"stepsList"];

    XCTAssertEqual(steps.count, 1);
    XCTAssertEqualObjects(steps[0][@"stepId"], @"AuthenticationStarted");
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.270Z");
}

- (void)testAddStep_whenMultipleSteps_shouldRecordAll
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    NSDate *ts1 = [self dateFromISO8601String:@"2025-10-29T15:03:17.270Z"];
    NSDate *ts2 = [self dateFromISO8601String:@"2025-10-29T15:03:17.520Z"];
    NSDate *ts3 = [self dateFromISO8601String:@"2025-10-29T15:03:17.770Z"];
    NSDate *ts4 = [self dateFromISO8601String:@"2025-10-29T15:03:18.190Z"];
    [builder addStep:@"BrokerInstallPromptedForMDM" timestamp:ts1];
    [builder addStep:@"DeviceRegistrationStarted" timestamp:ts2];
    [builder addStep:@"DeviceRegistrationCompleted" timestamp:ts3];
    [builder addStep:@"MDMEnrollmentStarted" timestamp:ts4];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    NSArray *steps = parsed[@"stepsList"];

    XCTAssertEqual(steps.count, 4);
    XCTAssertEqualObjects(steps[0][@"stepId"], @"BrokerInstallPromptedForMDM");
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.270Z");
    XCTAssertEqualObjects(steps[1][@"stepId"], @"DeviceRegistrationStarted");
    XCTAssertEqualObjects(steps[1][@"ts"], @"2025-10-29T15:03:17.520Z");
    XCTAssertEqualObjects(steps[2][@"stepId"], @"DeviceRegistrationCompleted");
    XCTAssertEqualObjects(steps[2][@"ts"], @"2025-10-29T15:03:17.770Z");
    XCTAssertEqualObjects(steps[3][@"stepId"], @"MDMEnrollmentStarted");
    XCTAssertEqualObjects(steps[3][@"ts"], @"2025-10-29T15:03:18.190Z");
}

- (void)testAddStep_whenSubMillisecondDifference_shouldPreserveMillisecondPrecision
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    NSDate *ts1 = [self dateFromISO8601String:@"2025-10-29T15:03:17.123Z"];
    NSDate *ts2 = [self dateFromISO8601String:@"2025-10-29T15:03:17.456Z"];
    NSDate *ts3 = [self dateFromISO8601String:@"2025-10-29T15:03:17.789Z"];
    [builder addStep:@"AuthenticationStarted" timestamp:ts1];
    [builder addStep:@"CredentialEntryCompleted" timestamp:ts2];
    [builder addStep:@"BrokerInstallPrompted" timestamp:ts3];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    NSArray *steps = parsed[@"stepsList"];

    XCTAssertEqual(steps.count, 3);
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.123Z");
    XCTAssertEqualObjects(steps[1][@"ts"], @"2025-10-29T15:03:17.456Z");
    XCTAssertEqualObjects(steps[2][@"ts"], @"2025-10-29T15:03:17.789Z");
}

#pragma mark - addBlockingError

- (void)testAddBlockingError_whenCalled_shouldRecordError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"BROKER_INSTALLATION_TRIGGERED"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *errors = parsed[@"blockingErrors"];
    XCTAssertEqual(errors.count, 1);
    XCTAssertEqualObjects(errors[0], @"BROKER_INSTALLATION_TRIGGERED");
    XCTAssertEqualObjects(parsed[@"lastBlockingError"], @"BROKER_INSTALLATION_TRIGGERED");
}

- (void)testAddBlockingError_whenMultipleErrors_shouldTrackLastError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"BROKER_INSTALLATION_TRIGGERED"];
    [builder addBlockingError:@"MDM_FLOW"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *errors = parsed[@"blockingErrors"];
    XCTAssertEqual(errors.count, 2);
    XCTAssertEqualObjects(parsed[@"lastBlockingError"], @"MDM_FLOW");
}

- (void)testAddBlockingError_whenCalled_shouldPersistSessionCorrelation
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *persisted = [self.testDefaults stringForKey:kCacheKey];
    XCTAssertNotNil(persisted);

    NSDictionary *cache = [self parsedJsonFromBlob:persisted];
    NSDictionary *entry = cache[@"clientA|resource1"];
    XCTAssertNotNil(entry);
    XCTAssertEqualObjects(entry[@"id"], @"abc-123");
    XCTAssertNotNil(entry[@"ts"]);
}

#pragma mark - setLastLoadedDomain

- (void)testSetLastLoadedDomain_whenSet_shouldAppearInBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder setLastLoadedDomain:@"login.microsoftonline.com"];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"lastLoadedDomain"], @"login.microsoftonline.com");
}

- (void)testSetLastLoadedDomain_whenNotSet_shouldBeAbsentFromBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"lastLoadedDomain"]);
}

#pragma mark - setRemediationNeeded

- (void)testSetRemediationNeeded_whenTrue_shouldAppearInBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder setRemediationNeeded:YES];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"remediationNeeded"], @(YES));
}

- (void)testSetRemediationNeeded_whenFalse_shouldBeAbsentFromBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder setRemediationNeeded:NO];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"remediationNeeded"]);
}

#pragma mark - addUxFlowUsed

- (void)testAddUxFlowUsed_whenCalled_shouldAppearInBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addUxFlowUsed:@"MobileOnboardingPhase1"];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *flows = parsed[@"uxFlowUsed"];
    XCTAssertEqual(flows.count, 1);
    XCTAssertEqualObjects(flows[0], @"MobileOnboardingPhase1");
}

- (void)testAddUxFlowUsed_whenNotCalled_shouldBeAbsentFromBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"uxFlowUsed"]);
}

#pragma mark - finalizeBlob

- (void)testFinalizeBlob_whenNoBlockingErrors_shouldReturnEmptyString
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addStep:@"AuthenticationStarted" timestamp:[NSDate date]];

    NSString *result = [builder finalizeBlob];
    XCTAssertEqualObjects(result, @"");
}

- (void)testFinalizeBlob_whenBlockingErrorsPresent_shouldReturnPopulatedJson
{
    NSString *seed = [self seedJsonWithVersion:@"1.0" correlationId:@"abc-123" mode:@"non_brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"c" target:@"t"];
    builder.sessionCachePersistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];

    NSDate *ts1 = [self dateFromISO8601String:@"2025-10-29T15:03:17.270Z"];
    NSDate *ts2 = [self dateFromISO8601String:@"2025-10-29T15:03:17.520Z"];
    [builder addStep:@"AuthenticationStarted" timestamp:ts1];
    [builder addStep:@"BrokerInstallPrompted" timestamp:ts2];
    [builder addBlockingError:@"BROKER_INSTALLATION_TRIGGERED"];
    [builder setLastLoadedDomain:@"login.microsoftonline.com"];
    [builder setRemediationNeeded:YES];
    [builder addUxFlowUsed:@"MobileOnboardingPhase1"];

    NSString *result = [builder finalizeBlob];
    XCTAssertTrue(result.length > 0);

    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    XCTAssertNotNil(parsed);

    // Seed fields
    XCTAssertEqualObjects(parsed[@"schema_version"], @"1.0");
    XCTAssertEqualObjects(parsed[@"sessionCorrelationId"], @"abc-123");
    XCTAssertEqualObjects(parsed[@"onboardingMode"], @"non_brokered");

    // Steps
    NSArray *steps = parsed[@"stepsList"];
    XCTAssertEqual(steps.count, 2);

    // Blocking errors
    NSArray *errors = parsed[@"blockingErrors"];
    XCTAssertEqual(errors.count, 1);
    XCTAssertEqualObjects(errors[0], @"BROKER_INSTALLATION_TRIGGERED");
    XCTAssertEqualObjects(parsed[@"lastBlockingError"], @"BROKER_INSTALLATION_TRIGGERED");

    // Domain
    XCTAssertEqualObjects(parsed[@"lastLoadedDomain"], @"login.microsoftonline.com");

    // Last completed step
    XCTAssertEqualObjects(parsed[@"lastCompletedStep"], @"BrokerInstallPrompted");

    // Remediation needed
    XCTAssertEqualObjects(parsed[@"remediationNeeded"], @(YES));

    // UX flow used
    NSArray *flows = parsed[@"uxFlowUsed"];
    XCTAssertEqual(flows.count, 1);
    XCTAssertEqualObjects(flows[0], @"MobileOnboardingPhase1");
}

- (void)testFinalizeBlob_whenNoSteps_shouldOmitLastCompletedStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"lastCompletedStep"]);
    XCTAssertNotNil(parsed[@"stepsList"]);
    XCTAssertEqual([parsed[@"stepsList"] count], 0);
}

@end
