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
#import "MSIDOAuth2Constants.h"

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
        @"session_correlation_id" : correlationId,
        @"onboarding_mode" : mode
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
    NSString *seed = [self seedJsonWithVersion:@"1.0.0" correlationId:@"abc-123" mode:@"brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"clientA" target:@"resource1"];
    builder.sessionCachePersistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];
    return builder;
}

#pragma mark - Init

- (void)testInit_whenValidSeedJson_shouldParseSeedFields
{
    NSString *seed = [self seedJsonWithVersion:@"1.0.0" correlationId:@"abc-123" mode:@"non-brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);
}

- (void)testInit_whenEmptyJson_shouldUseEmptyDefaults
{
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:@"" clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);

    // With no blocking errors, finalizeBlob still returns a blob with empty seed fields
    NSString *result = [builder finalizeBlob];
    XCTAssertTrue(result.length > 0);

    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    XCTAssertEqualObjects(parsed[@"schema_version"], @"");
    XCTAssertEqualObjects(parsed[@"session_correlation_id"], @"");
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"");
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
}

- (void)testInit_whenInvalidJson_shouldUseEmptyDefaults
{
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:@"not json" clientId:@"client1" target:@"user.read"];

    XCTAssertNotNil(builder);

    [builder addBlockingError:@"65001"];
    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"schema_version"], @"");
    XCTAssertEqualObjects(parsed[@"session_correlation_id"], @"");
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"");
}

- (void)testInit_whenSeedContainsUxFlowUsed_shouldCarryThroughToBlob
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"ux_flow_used" : @[@"FlowFromSeedA", @"FlowFromSeedB"]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];
    [builder addUxFlowUsed:@"FlowAddedAtRuntime"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *flows = parsed[@"ux_flow_used"];
    XCTAssertEqual(flows.count, 3);
    XCTAssertEqualObjects(flows[0], @"FlowFromSeedA");
    XCTAssertEqualObjects(flows[1], @"FlowFromSeedB");
    XCTAssertEqualObjects(flows[2], @"FlowAddedAtRuntime");
}

- (void)testInit_whenSeedUxFlowUsedIsNotArray_shouldIgnoreIt
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"ux_flow_used" : @"not-an-array"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"ux_flow_used"]);
}

- (void)testInit_whenSeedUxFlowUsedHasNonStringEntries_shouldIncludeOnlyStrings
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"ux_flow_used" : @[@"ValidFlow", @42, [NSNull null], @"AnotherValidFlow"]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *flows = parsed[@"ux_flow_used"];
    XCTAssertEqual(flows.count, 2);
    XCTAssertEqualObjects(flows[0], @"ValidFlow");
    XCTAssertEqualObjects(flows[1], @"AnotherValidFlow");
}

- (void)testInit_whenSeedContainsStepsList_shouldCarryThroughToBlob
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"steps_list" : @[
            @{@"step_id" : @"AuthenticationStarted", @"ts" : @"2025-10-29T15:03:17.270Z"},
            @{@"step_id" : @"CredentialEntryCompleted", @"ts" : @"2025-10-29T15:03:17.520Z"}
        ]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];
    NSDate *runtimeTs = [self dateFromISO8601String:@"2025-10-29T15:03:17.770Z"];
    [builder addStep:@"BrokerInstallPrompted" timestamp:runtimeTs];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *steps = parsed[@"steps_list"];
    XCTAssertEqual(steps.count, 3);
    XCTAssertEqualObjects(steps[0][@"step_id"], @"AuthenticationStarted");
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.270Z");
    XCTAssertEqualObjects(steps[1][@"step_id"], @"CredentialEntryCompleted");
    XCTAssertEqualObjects(steps[1][@"ts"], @"2025-10-29T15:03:17.520Z");
    XCTAssertEqualObjects(steps[2][@"step_id"], @"BrokerInstallPrompted");
    XCTAssertEqualObjects(steps[2][@"ts"], @"2025-10-29T15:03:17.770Z");
    XCTAssertEqualObjects(parsed[@"last_completed_step"], @"BrokerInstallPrompted");
}

- (void)testInit_whenSeedStepsListIsNotArray_shouldIgnoreIt
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"steps_list" : @"not-an-array"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNotNil(parsed[@"steps_list"]);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
    XCTAssertNil(parsed[@"last_completed_step"]);
}

- (void)testInit_whenSeedStepsListHasMalformedEntries_shouldIncludeOnlyValid
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"steps_list" : @[
            @{@"step_id" : @"ValidStepA", @"ts" : @"2025-10-29T15:03:17.270Z"},
            @{@"step_id" : @"MissingTs"},
            @{@"ts" : @"2025-10-29T15:03:17.300Z"},
            @{@"step_id" : @"NonStringTs", @"ts" : @42},
            @"not-a-dict",
            @{@"step_id" : @"ValidStepB", @"ts" : @"2025-10-29T15:03:17.520Z"}
        ]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *steps = parsed[@"steps_list"];
    XCTAssertEqual(steps.count, 2);
    XCTAssertEqualObjects(steps[0][@"step_id"], @"ValidStepA");
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.270Z");
    XCTAssertEqualObjects(steps[1][@"step_id"], @"ValidStepB");
    XCTAssertEqualObjects(steps[1][@"ts"], @"2025-10-29T15:03:17.520Z");
    XCTAssertEqualObjects(parsed[@"last_completed_step"], @"ValidStepB");
}

- (void)testInit_whenSeedContainsBlockingErrors_shouldCarryThroughToBlob
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"blocking_errors" : @[@"SEED_ERROR_A", @"SEED_ERROR_B"]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];
    builder.sessionCachePersistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];
    [builder addBlockingError:@"RUNTIME_ERROR"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *errors = parsed[@"blocking_errors"];
    XCTAssertEqual(errors.count, 3);
    XCTAssertEqualObjects(errors[0], @"SEED_ERROR_A");
    XCTAssertEqualObjects(errors[1], @"SEED_ERROR_B");
    XCTAssertEqualObjects(errors[2], @"RUNTIME_ERROR");
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"RUNTIME_ERROR");
}

- (void)testInit_whenSeedBlockingErrorsIsNotArray_shouldIgnoreIt
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"blocking_errors" : @{@"unexpected" : @"object"}
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNotNil(parsed[@"blocking_errors"]);
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertNil(parsed[@"last_blocking_error"]);
}

- (void)testInit_whenSeedBlockingErrorsHasNonStringEntries_shouldIncludeOnlyStrings
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"blocking_errors" : @[@"VALID_ERROR_A", @42, [NSNull null], @"VALID_ERROR_B"]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *errors = parsed[@"blocking_errors"];
    XCTAssertEqual(errors.count, 2);
    XCTAssertEqualObjects(errors[0], @"VALID_ERROR_A");
    XCTAssertEqualObjects(errors[1], @"VALID_ERROR_B");
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"VALID_ERROR_B");
}

- (void)testInit_whenSeedContainsLastLoadedDomain_shouldCarryThroughToBlob
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"last_loaded_domain" : @"login.microsoftonline.com"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"last_loaded_domain"], @"login.microsoftonline.com");
}

- (void)testInit_whenSeedLastLoadedDomainIsNotString_shouldIgnoreIt
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"last_loaded_domain" : @42
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"last_loaded_domain"]);
}

- (void)testInit_whenSeedLastLoadedDomainEmpty_shouldIgnoreIt
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"last_loaded_domain" : @""
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"last_loaded_domain"]);
}

- (void)testInit_whenSeedHasLastLoadedDomain_runtimeSetLastLoadedDomainOverrides
{
    NSDictionary *seed = @{
        @"schema_version" : @"1.0.0",
        @"session_correlation_id" : @"abc-123",
        @"onboarding_mode" : @"brokered",
        @"last_loaded_domain" : @"seed.microsoftonline.com"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:seed options:0 error:nil];
    NSString *seedJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seedJson clientId:@"client1" target:@"user.read"];
    [builder setLastLoadedDomain:@"runtime.microsoftonline.com"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"last_loaded_domain"], @"runtime.microsoftonline.com");
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
    NSArray *steps = parsed[@"steps_list"];

    XCTAssertEqual(steps.count, 1);
    XCTAssertEqualObjects(steps[0][@"step_id"], @"AuthenticationStarted");
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
    NSArray *steps = parsed[@"steps_list"];

    XCTAssertEqual(steps.count, 4);
    XCTAssertEqualObjects(steps[0][@"step_id"], @"BrokerInstallPromptedForMDM");
    XCTAssertEqualObjects(steps[0][@"ts"], @"2025-10-29T15:03:17.270Z");
    XCTAssertEqualObjects(steps[1][@"step_id"], @"DeviceRegistrationStarted");
    XCTAssertEqualObjects(steps[1][@"ts"], @"2025-10-29T15:03:17.520Z");
    XCTAssertEqualObjects(steps[2][@"step_id"], @"DeviceRegistrationCompleted");
    XCTAssertEqualObjects(steps[2][@"ts"], @"2025-10-29T15:03:17.770Z");
    XCTAssertEqualObjects(steps[3][@"step_id"], @"MDMEnrollmentStarted");
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
    NSArray *steps = parsed[@"steps_list"];

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

    NSArray *errors = parsed[@"blocking_errors"];
    XCTAssertEqual(errors.count, 1);
    XCTAssertEqualObjects(errors[0], @"BROKER_INSTALLATION_TRIGGERED");
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"BROKER_INSTALLATION_TRIGGERED");
}

- (void)testAddBlockingError_whenMultipleErrors_shouldTrackLastError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"BROKER_INSTALLATION_TRIGGERED"];
    [builder addBlockingError:@"MDM_FLOW"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *errors = parsed[@"blocking_errors"];
    XCTAssertEqual(errors.count, 2);
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"MDM_FLOW");
}

#pragma mark - setLastLoadedDomain

- (void)testSetLastLoadedDomain_whenSet_shouldAppearInBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder setLastLoadedDomain:@"login.microsoftonline.com"];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertEqualObjects(parsed[@"last_loaded_domain"], @"login.microsoftonline.com");
}

- (void)testSetLastLoadedDomain_whenNotSet_shouldBeAbsentFromBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"last_loaded_domain"]);
}

#pragma mark - addUxFlowUsed

- (void)testAddUxFlowUsed_whenCalled_shouldAppearInBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addUxFlowUsed:@"MobileOnboardingPhase1"];
    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    NSArray *flows = parsed[@"ux_flow_used"];
    XCTAssertEqual(flows.count, 1);
    XCTAssertEqualObjects(flows[0], @"MobileOnboardingPhase1");
}

- (void)testAddUxFlowUsed_whenNotCalled_shouldBeAbsentFromBlob
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"ux_flow_used"]);
}

#pragma mark - finalizeBlob

- (void)testFinalizeBlob_whenNoBlockingErrors_shouldReturnBlobWithEmptyErrors
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addStep:@"AuthenticationStarted" timestamp:[NSDate date]];

    NSString *result = [builder finalizeBlob];
    XCTAssertTrue(result.length > 0);

    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    XCTAssertNotNil(parsed);
    XCTAssertEqualObjects(parsed[@"schema_version"], @"1.0.0");
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertEqual([parsed[@"steps_list"] count], 1);
    XCTAssertEqualObjects(parsed[@"last_completed_step"], @"AuthenticationStarted");
}

- (void)testFinalizeBlob_whenBlockingErrorsPresent_shouldReturnPopulatedJson
{
    NSString *seed = [self seedJsonWithVersion:@"1.0.0" correlationId:@"abc-123" mode:@"non-brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed clientId:@"c" target:@"t"];
    builder.sessionCachePersistence = [[MSIDSessionCachePersistence alloc] initWithUserDefaults:self.testDefaults];

    NSDate *ts1 = [self dateFromISO8601String:@"2025-10-29T15:03:17.270Z"];
    NSDate *ts2 = [self dateFromISO8601String:@"2025-10-29T15:03:17.520Z"];
    [builder addStep:@"AuthenticationStarted" timestamp:ts1];
    [builder addStep:@"BrokerInstallPrompted" timestamp:ts2];
    [builder addBlockingError:@"BROKER_INSTALLATION_TRIGGERED"];
    [builder setLastLoadedDomain:@"login.microsoftonline.com"];
    [builder addUxFlowUsed:@"MobileOnboardingPhase1"];

    NSString *result = [builder finalizeBlob];
    XCTAssertTrue(result.length > 0);

    NSDictionary *parsed = [self parsedJsonFromBlob:result];
    XCTAssertNotNil(parsed);

    // Seed fields
    XCTAssertEqualObjects(parsed[@"schema_version"], @"1.0.0");
    XCTAssertEqualObjects(parsed[@"session_correlation_id"], @"abc-123");
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"non-brokered");

    // Steps
    NSArray *steps = parsed[@"steps_list"];
    XCTAssertEqual(steps.count, 2);

    // Blocking errors
    NSArray *errors = parsed[@"blocking_errors"];
    XCTAssertEqual(errors.count, 1);
    XCTAssertEqualObjects(errors[0], @"BROKER_INSTALLATION_TRIGGERED");
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"BROKER_INSTALLATION_TRIGGERED");

    // Domain
    XCTAssertEqualObjects(parsed[@"last_loaded_domain"], @"login.microsoftonline.com");

    // Last completed step
    XCTAssertEqualObjects(parsed[@"last_completed_step"], @"BrokerInstallPrompted");

    // UX flow used
    NSArray *flows = parsed[@"ux_flow_used"];
    XCTAssertEqual(flows.count, 1);
    XCTAssertEqualObjects(flows[0], @"MobileOnboardingPhase1");
}

- (void)testFinalizeBlob_whenNoSteps_shouldOmitLastCompletedStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder addBlockingError:@"65001"];

    NSString *result = [builder finalizeBlob];
    NSDictionary *parsed = [self parsedJsonFromBlob:result];

    XCTAssertNil(parsed[@"last_completed_step"]);
    XCTAssertNotNil(parsed[@"steps_list"]);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
}

#pragma mark - ensureBrokeredOnboardingMode

- (void)testEnsureBrokeredOnboardingMode_whenSeedModeNonBrokered_shouldSetToBrokered
{
    NSString *seed = [self seedJsonWithVersion:@"1.0.0" correlationId:@"abc-123" mode:@"non-brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed
                                                                                    clientId:@"client"
                                                                                      target:@"target"];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"non-brokered");

    [builder ensureBrokeredOnboardingMode];

    parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"brokered");
}

- (void)testEnsureBrokeredOnboardingMode_whenSeedModeEmpty_shouldSetToBrokered
{
    // Seed without an `onboarding_mode` field — builder initializes the property to @"".
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:@"{\"schema_version\":\"1.0.0\"}"
                                                                                    clientId:@"client"
                                                                                      target:@"target"];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"");

    [builder ensureBrokeredOnboardingMode];

    parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"brokered");
}

- (void)testEnsureBrokeredOnboardingMode_whenAlreadyBrokered_shouldBeNoOp
{
    NSString *seed = [self seedJsonWithVersion:@"1.0.0" correlationId:@"abc-123" mode:@"brokered"];
    MSIDOnboardingBlobBuilder *builder = [[MSIDOnboardingBlobBuilder alloc] initWithSeedJson:seed
                                                                                    clientId:@"client"
                                                                                      target:@"target"];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"brokered");

    [builder ensureBrokeredOnboardingMode];

    parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"onboarding_mode"], @"brokered");
}

#pragma mark - processResponseHeaders:responseURL:

- (NSUInteger)countOfStep:(NSString *)stepId inBlob:(NSDictionary *)parsed
{
    NSUInteger count = 0;
    for (NSDictionary *step in parsed[@"steps_list"])
    {
        if ([step[@"step_id"] isEqualToString:stepId])
        {
            count++;
        }
    }
    return count;
}

- (void)testProcessResponseHeaders_whenResponseURLHasHost_shouldSetLastLoadedDomain
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{} responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/authorize"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"last_loaded_domain"], @"login.microsoftonline.com");
}

- (void)testProcessResponseHeaders_whenNoClitelemHeader_shouldNotRecordBlockingError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{} responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
    XCTAssertFalse(builder.strongAuthSetupStarted);
    XCTAssertFalse(builder.mdmEnrollmentStarted);
}

- (void)testProcessResponseHeaders_whenClitelemErrorCodeIsZero_shouldNotRecordBlockingError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,0,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
}

- (void)testProcessResponseHeaders_whenClitelemMalformed_shouldNotRecordBlockingError
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
}

- (void)testProcessResponseHeaders_whenNonBlockingErrorCode_shouldNotRecordBlockingErrorOrStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50126,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([parsed[@"blocking_errors"] count], 0);
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
}

- (void)testProcessResponseHeaders_whenStrongAuthSetupErrorCode_shouldRecordStepAndSetFlag
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50079,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    XCTAssertTrue(builder.strongAuthSetupStarted);

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"50079");
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepStrongAuthSetupStarted inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenStrongAuthSetupErrorCodeSeenTwice_shouldRecordStepOnce
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    NSDictionary *headers = @{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50079,0,,"};
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com"];
    [builder processResponseHeaders:headers responseURL:url];
    [builder processResponseHeaders:headers responseURL:url];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepStrongAuthSetupStarted inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenMdmEnrollmentRequiredErrorCode_shouldRecordStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,53000,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepMdmEnrollmentRequired inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenDeviceRegistrationErrorCode_shouldRecordStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50129,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepDeviceRegistrationRequired inBlob:parsed], 1);
    XCTAssertFalse(builder.strongAuthSetupStarted);
    XCTAssertFalse(builder.mdmEnrollmentStarted);
}

- (void)testProcessResponseHeaders_whenDeviceNotCompliantErrorCode_shouldRecordStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,530001,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepDeviceNotCompliant inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenBrokerInstallForMamErrorCode_shouldRecordStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50127,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepBrokerInstallPromptedForMAM inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenBrokerInstallErrorCode_shouldRecordStep
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,501271,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqual([self countOfStep:MSIDOnboardingBlobStepBrokerInstallPrompted inBlob:parsed], 1);
}

- (void)testProcessResponseHeaders_whenBlockingErrorNotMappedToStep_shouldRecordBlockingErrorOnly
{
    MSIDOnboardingBlobBuilder *builder = [self builderWithTestDefaults];

    [builder processResponseHeaders:@{MSID_OAUTH2_CLIENT_TELEMETRY: @"2,50076,0,,"}
                        responseURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];

    NSDictionary *parsed = [self parsedJsonFromBlob:[builder finalizeBlob]];
    XCTAssertEqualObjects(parsed[@"last_blocking_error"], @"50076");
    XCTAssertEqual([parsed[@"steps_list"] count], 0);
    XCTAssertFalse(builder.strongAuthSetupStarted);
    XCTAssertFalse(builder.mdmEnrollmentStarted);
}

@end
