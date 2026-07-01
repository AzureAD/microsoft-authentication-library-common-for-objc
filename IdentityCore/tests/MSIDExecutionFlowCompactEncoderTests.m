//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
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
#import "MSIDExecutionFlow.h"
#import "MSIDExecutionFlowCompactEncoder.h"
#import "MSIDExecutionFlowConstants.h"

@interface MSIDExecutionFlowCompactEncoderTests : XCTestCase
@end

@implementation MSIDExecutionFlowCompactEncoderTests

#pragma mark - Helpers

- (NSDictionary *)encodeAndParse:(MSIDExecutionFlow *)flow
                   correlationId:(NSString *)cid
                      brokerName:(NSString *)brokerName
                   brokerVersion:(NSString *)brokerVersion
                     authOutcome:(NSString *)outcome
                       errorCode:(NSString *)errorCode
                     startTimeMs:(uint64_t)st
                      durationMs:(uint64_t)dur
                        maxBytes:(NSUInteger)maxBytes
{
    NSString *json = [MSIDExecutionFlowCompactEncoder encodeExecutionFlow:flow
                                                            correlationId:cid
                                                               brokerName:brokerName
                                                            brokerVersion:brokerVersion
                                                              authOutcome:outcome
                                                                errorCode:errorCode
                                                              startTimeMs:st
                                                               durationMs:dur
                                                                 maxBytes:maxBytes];
    if (!json) return nil;

    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    XCTAssertNil(err, @"JSON should parse cleanly");
    XCTAssertTrue([parsed isKindOfClass:NSDictionary.class]);
    return parsed;
}

- (MSIDExecutionFlow *)flowWithBlobs:(NSUInteger)count
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSDate *base = [NSDate dateWithTimeIntervalSince1970:1700000000];
    for (NSUInteger i = 0; i < count; i++)
    {
        NSString *tag = [NSString stringWithFormat:@"tag%lu", (unsigned long)i];
        NSDate *t = [base dateByAddingTimeInterval:(NSTimeInterval)i];
        [flow insertTag:tag triggeringTime:t threadId:@(42) extraInfo:nil];
    }
    return flow;
}

#pragma mark - Nil / empty input

- (void)testEncode_whenFlowIsNil_shouldReturnNil
{
    NSString *result = [MSIDExecutionFlowCompactEncoder encodeExecutionFlow:nil
                                                              correlationId:@"cid-1"
                                                                 brokerName:@"broker"
                                                              brokerVersion:@"1.0"
                                                                authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                                                  errorCode:nil
                                                                startTimeMs:0
                                                                 durationMs:0
                                                                   maxBytes:0];
    XCTAssertNil(result);
}

- (void)testEncode_whenFlowIsEmpty_shouldEmitEnvelopeWithEmptyEventArray
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:@"cid-1"
                                       brokerName:@"broker"
                                    brokerVersion:@"1.2.3"
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:1000
                                       durationMs:250
                                         maxBytes:0];

    XCTAssertEqualObjects(envelope[@"v"], @"1.0.0");
    XCTAssertEqualObjects(envelope[@"cid"], @"cid-1");
    XCTAssertEqualObjects(envelope[@"n"], @"broker");
    XCTAssertEqualObjects(envelope[@"av"], @"1.2.3");
    XCTAssertEqualObjects(envelope[@"ao"], @"succeeded");
    XCTAssertNil(envelope[@"ec"], @"ec must be omitted on success when nil");

    NSDictionary *perf = envelope[@"perf"];
    XCTAssertEqualObjects(perf[@"v"], @"1.0.0");
    XCTAssertEqualObjects(perf[@"st"], @(1000));
    XCTAssertEqualObjects(perf[@"dur"], @(250));
    XCTAssertEqualObjects(perf[@"ef"], @[]);
}

#pragma mark - Round-trip

- (void)testEncode_withSingleBlob_shouldRoundTripMandatoryFields
{
    MSIDExecutionFlow *flow = [self flowWithBlobs:1];

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:@"abc"
                                       brokerName:@"broker"
                                    brokerVersion:@"2.0"
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:5
                                       durationMs:10
                                         maxBytes:0];

    NSArray *ef = envelope[@"perf"][@"ef"];
    XCTAssertEqual(ef.count, 1);
    NSDictionary *event = ef.firstObject;
    XCTAssertEqualObjects(event[@"t"], @"tag0");
    XCTAssertNotNil(event[@"ts"]);
    XCTAssertEqualObjects(event[@"tid"], @(42));
    XCTAssertNil(event[@"d"]);
    XCTAssertNil(event[@"e"]);
    XCTAssertNil(event[@"ref"]);
}

- (void)testEncode_withAllOptionalFieldsPopulated_shouldEmitAllOptionalKeys
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"opttag"
     triggeringTime:[NSDate dateWithTimeIntervalSince1970:1700000000]
           threadId:@(7)
          extraInfo:@{ @"d": @(404), @"e": @(1003), @"ref": @"SubclassA" }];

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_FAILED
                                        errorCode:@"AADSTS50012"
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];

    XCTAssertNil(envelope[@"cid"]);
    XCTAssertNil(envelope[@"n"]);
    XCTAssertNil(envelope[@"av"]);
    XCTAssertEqualObjects(envelope[@"ao"], @"failed");
    XCTAssertEqualObjects(envelope[@"ec"], @"AADSTS50012");

    NSArray *ef = envelope[@"perf"][@"ef"];
    XCTAssertEqual(ef.count, 1);
    NSDictionary *event = ef.firstObject;
    XCTAssertEqualObjects(event[@"t"], @"opttag");
    XCTAssertEqualObjects(event[@"d"], @(404));
    XCTAssertEqualObjects(event[@"e"], @(1003));
    XCTAssertEqualObjects(event[@"ref"], @"SubclassA");
}

#pragma mark - Auth outcome enum coverage

- (void)testEncode_whenAuthOutcomeCancelled_shouldEmitCancelled
{
    NSDictionary *envelope = [self encodeAndParse:[[MSIDExecutionFlow alloc] init]
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_CANCELLED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    XCTAssertEqualObjects(envelope[@"ao"], @"cancelled");
    XCTAssertNil(envelope[@"ec"]);
}

- (void)testEncode_whenAuthOutcomeFailedButNoErrorCode_shouldOmitErrorCode
{
    NSDictionary *envelope = [self encodeAndParse:[[MSIDExecutionFlow alloc] init]
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_FAILED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    XCTAssertEqualObjects(envelope[@"ao"], @"failed");
    XCTAssertNil(envelope[@"ec"], @"ec must be omitted when nil even on failure path");
}

#pragma mark - Schema version

- (void)testEncode_shouldEmitSchemaVersionAtRootAndPerf
{
    NSDictionary *envelope = [self encodeAndParse:[self flowWithBlobs:1]
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    XCTAssertEqualObjects(envelope[@"v"], MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION);
    XCTAssertEqualObjects(envelope[@"perf"][@"v"], MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION);
}

#pragma mark - Truncation

- (void)testEncode_whenBelowMaxBytes_shouldNotTruncate
{
    MSIDExecutionFlow *flow = [self flowWithBlobs:5];

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:100000];
    NSArray *ef = envelope[@"perf"][@"ef"];
    XCTAssertEqual(ef.count, 5);
    NSDictionary *last = ef.lastObject;
    XCTAssertNotEqualObjects(last[@"t"], MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG);
}

- (void)testEncode_whenMaxBytesZero_shouldNotTruncate
{
    MSIDExecutionFlow *flow = [self flowWithBlobs:20];

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    NSArray *ef = envelope[@"perf"][@"ef"];
    XCTAssertEqual(ef.count, 20);
}

- (void)testEncode_whenAboveMaxBytes_shouldDropOldestAndAppendSentinel
{
    MSIDExecutionFlow *flow = [self flowWithBlobs:10];

    // First, get the natural size and pick a max that forces a few drops.
    NSString *full = [MSIDExecutionFlowCompactEncoder encodeExecutionFlow:flow
                                                            correlationId:nil
                                                               brokerName:nil
                                                            brokerVersion:nil
                                                              authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                                                errorCode:nil
                                                              startTimeMs:0
                                                               durationMs:0
                                                                 maxBytes:0];
    NSUInteger fullBytes = [full lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    XCTAssertGreaterThan(fullBytes, 100u);

    // Choose maxBytes well below the full size to force truncation.
    NSUInteger budget = fullBytes - 80;

    NSDictionary *envelope = [self encodeAndParse:flow
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:budget];

    NSArray *ef = envelope[@"perf"][@"ef"];
    XCTAssertGreaterThan(ef.count, 0u);
    XCTAssertLessThan(ef.count, 11u, @"Should have dropped at least one event plus added sentinel");

    // Last entry must be the sentinel.
    NSDictionary *last = ef.lastObject;
    XCTAssertEqualObjects(last[@"t"], MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG);

    // FIFO drop: first surviving non-sentinel must NOT be tag0.
    NSDictionary *first = ef.firstObject;
    XCTAssertNotEqualObjects(first[@"t"], @"tag0", @"Oldest event should be dropped first");

    // Final encoded length must be <= maxBytes.
    NSString *encodedString = [MSIDExecutionFlowCompactEncoder encodeExecutionFlow:flow
                                                                     correlationId:nil
                                                                        brokerName:nil
                                                                     brokerVersion:nil
                                                                       authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                                                         errorCode:nil
                                                                       startTimeMs:0
                                                                        durationMs:0
                                                                          maxBytes:budget];
    NSUInteger encodedBytes = [encodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    XCTAssertLessThanOrEqual(encodedBytes, budget);
}

- (void)testEncode_whenMaxBytesTooSmallForAnyEvent_shouldStillEmitSentinel
{
    MSIDExecutionFlow *flow = [self flowWithBlobs:5];

    // Pick a maxBytes that's smaller than even the bare envelope plus sentinel.
    // The encoder should still return *something* with the sentinel so the consumer
    // can detect truncation occurred.
    NSString *result = [MSIDExecutionFlowCompactEncoder encodeExecutionFlow:flow
                                                              correlationId:nil
                                                                 brokerName:nil
                                                              brokerVersion:nil
                                                                authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                                                  errorCode:nil
                                                                startTimeMs:0
                                                                 durationMs:0
                                                                   maxBytes:1];
    XCTAssertNotNil(result);
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    NSArray *ef = parsed[@"perf"][@"ef"];
    XCTAssertEqual(ef.count, 1u);
    XCTAssertEqualObjects(ef.firstObject[@"t"], MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG);
}

#pragma mark - Optional envelope fields omitted

- (void)testEncode_whenOptionalFieldsNil_shouldOmitThem
{
    NSDictionary *envelope = [self encodeAndParse:[[MSIDExecutionFlow alloc] init]
                                    correlationId:nil
                                       brokerName:nil
                                    brokerVersion:nil
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:nil
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    XCTAssertNil(envelope[@"cid"]);
    XCTAssertNil(envelope[@"n"]);
    XCTAssertNil(envelope[@"av"]);
    XCTAssertNil(envelope[@"ec"]);
}

- (void)testEncode_whenOptionalFieldsEmptyStrings_shouldOmitThem
{
    NSDictionary *envelope = [self encodeAndParse:[[MSIDExecutionFlow alloc] init]
                                    correlationId:@""
                                       brokerName:@""
                                    brokerVersion:@""
                                      authOutcome:MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED
                                        errorCode:@""
                                      startTimeMs:0
                                       durationMs:0
                                         maxBytes:0];
    XCTAssertNil(envelope[@"cid"]);
    XCTAssertNil(envelope[@"n"]);
    XCTAssertNil(envelope[@"av"]);
    XCTAssertNil(envelope[@"ec"]);
}

#pragma mark - Helper API direct coverage

- (void)testBlobToDictionaryWithKeys_nilQueryKeys_returnsCopyDistinctFromInternalStorage
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"helpertag"
     triggeringTime:[NSDate dateWithTimeIntervalSince1970:1700000000]
           threadId:@(99)
          extraInfo:@{ @"d": @(1), @"e": @(2), @"ref": @"R" }];

    NSArray<NSDictionary<NSString *, id> *> *firstCall  = [flow executionFlowDictionariesWithKeys:nil];
    NSArray<NSDictionary<NSString *, id> *> *secondCall = [flow executionFlowDictionariesWithKeys:nil];
    XCTAssertEqual(firstCall.count, 1u);
    XCTAssertEqual(secondCall.count, 1u);

    // Returned dict must be a defensive copy: callers should not be able to mutate it.
    NSDictionary *dict = firstCall.firstObject;
    XCTAssertFalse([dict isKindOfClass:[NSMutableDictionary class]],
                   @"nil-queryKeys path must return an immutable copy, not internal mutable storage");

    // Round-trip: every mandatory + optional key is present.
    XCTAssertEqualObjects(dict[@"t"], @"helpertag");
    XCTAssertNotNil(dict[@"ts"]);
    XCTAssertEqualObjects(dict[@"tid"], @(99));
    XCTAssertEqualObjects(dict[@"d"], @(1));
    XCTAssertEqualObjects(dict[@"e"], @(2));
    XCTAssertEqualObjects(dict[@"ref"], @"R");

    // A second retrieval should observe the same underlying values (no leakage from
    // either retrieval into the next).
    XCTAssertEqualObjects(secondCall.firstObject[@"d"], @(1));
}

- (void)testBlobToDictionaryWithKeys_emptyQueryKeys_returnsAllFields
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"emptyq"
     triggeringTime:[NSDate dateWithTimeIntervalSince1970:1700000000]
           threadId:@(1)
          extraInfo:@{ @"d": @(7) }];

    NSArray<NSDictionary<NSString *, id> *> *blobs = [flow executionFlowDictionariesWithKeys:[NSSet set]];
    XCTAssertEqual(blobs.count, 1u);
    XCTAssertEqualObjects(blobs.firstObject[@"d"], @(7),
                          @"Empty queryKeys set should behave like nil and include all keys");
}

- (void)testBlobToDictionaryWithKeys_filtersToRequestedKeysPlusReserved
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    [flow insertTag:@"filtertag"
     triggeringTime:[NSDate dateWithTimeIntervalSince1970:1700000000]
           threadId:@(1)
          extraInfo:@{ @"d": @(1), @"e": @(2), @"ref": @"R" }];

    NSArray<NSDictionary<NSString *, id> *> *blobs = [flow executionFlowDictionariesWithKeys:[NSSet setWithObject:@"d"]];
    XCTAssertEqual(blobs.count, 1u);
    NSDictionary *dict = blobs.firstObject;
    XCTAssertEqualObjects(dict[@"t"], @"filtertag", @"Mandatory key always present");
    XCTAssertNotNil(dict[@"ts"], @"Mandatory key always present");
    XCTAssertEqualObjects(dict[@"tid"], @(1), @"Mandatory key always present");
    XCTAssertEqualObjects(dict[@"d"], @(1));
    XCTAssertNil(dict[@"e"], @"Filtered out");
    XCTAssertNil(dict[@"ref"], @"Filtered out");
}

- (void)testExecutionFlowDictionariesWithKeys_emptyFlow_returnsEmptyArray
{
    MSIDExecutionFlow *flow = [[MSIDExecutionFlow alloc] init];
    NSArray *result = [flow executionFlowDictionariesWithKeys:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 0u);
}

@end
