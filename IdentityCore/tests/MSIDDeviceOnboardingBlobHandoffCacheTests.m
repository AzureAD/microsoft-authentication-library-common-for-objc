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
#import "MSIDDeviceOnboardingBlobHandoffCache.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDJsonObject.h"

static NSString *const kFieldVersion = @"version";
static NSString *const kFieldSessionCorrelationId = @"session_correlation_id";
static NSString *const kFieldOnboardingBlob = @"onboardingBlob";
static NSString *const kFieldWrittenAt = @"written_at";

@interface MSIDDeviceOnboardingBlobHandoffCache ()

@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> dataSource;
@property (nonatomic) MSIDCacheItemJsonSerializer *serializer;

- (MSIDCacheKey *)cacheKey;

@end

@interface MSIDDeviceOnboardingBlobHandoffCacheTests : XCTestCase

@property (nonatomic) MSIDDeviceOnboardingBlobHandoffCache *cache;
@property (nonatomic) MSIDTestCacheDataSource *testDataSource;
@property (nonatomic) id<MSIDExtendedTokenCacheDataSource> originalDataSource;

@end

@implementation MSIDDeviceOnboardingBlobHandoffCacheTests

- (void)setUp
{
    [super setUp];
    self.cache = MSIDDeviceOnboardingBlobHandoffCache.sharedInstance;
    self.originalDataSource = self.cache.dataSource;
    self.testDataSource = [MSIDTestCacheDataSource new];
    self.cache.dataSource = self.testDataSource;
}

- (void)tearDown
{
    [self.testDataSource reset];
    self.cache.dataSource = self.originalDataSource;
    [super tearDown];
}

#pragma mark - Helpers

// Builds a realistic broker onboarding blob JSON string carrying an embedded session correlation id.
- (NSString *)blobJsonWithSessionId:(NSString *)sessionId payload:(NSString *)payload
{
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    if (sessionId)
    {
        json[kFieldSessionCorrelationId] = sessionId;
    }
    json[@"steps"] = payload ?: @"";

    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// Writes an envelope straight into the data source so tests can control written_at (TTL cases).
- (BOOL)writeEnvelopeDirectlyWithSessionId:(NSString *)sessionId
                                      blob:(NSString *)blob
                                 writtenAt:(NSTimeInterval)writtenAt
{
    NSDictionary *envelope = @{
        kFieldVersion: @1,
        kFieldSessionCorrelationId: sessionId,
        kFieldOnboardingBlob: blob,
        kFieldWrittenAt: @(writtenAt),
    };

    NSError *error = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:envelope error:&error];
    XCTAssertNotNil(jsonObject, @"Failed to build json object: %@", error);

    BOOL result = [self.testDataSource saveJsonObject:jsonObject
                                           serializer:self.cache.serializer
                                                  key:[self.cache cacheKey]
                                              context:nil
                                                error:&error];
    XCTAssertTrue(result, @"Failed to write envelope directly: %@", error);
    return result;
}

- (NSDictionary *)readEnvelopeDirectly
{
    NSError *error = nil;
    NSArray<MSIDJsonObject *> *jsonObjects = [self.testDataSource jsonObjectsWithKey:[self.cache cacheKey]
                                                                          serializer:self.cache.serializer
                                                                             context:nil
                                                                               error:&error];
    XCTAssertNil(error, @"Unexpected read error: %@", error);
    if (jsonObjects.count == 0)
    {
        return nil;
    }
    return [jsonObjects.firstObject jsonDictionary];
}

#pragma mark - Write then read

- (void)testWriteThenRead_whenSessionMatches_shouldReturnBlob
{
    NSString *sessionId = @"11111111-1111-1111-1111-111111111111";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"broker-built-steps"];

    BOOL wrote = [self.cache writeBlobJson:blob forSessionCorrelationId:sessionId];
    XCTAssertTrue(wrote);

    NSString *recovered = [self.cache readBlobJsonForSessionCorrelationId:sessionId];
    XCTAssertEqualObjects(recovered, blob);
}

- (void)testWrite_shouldPersistExpectedEnvelopeFields
{
    NSString *sessionId = @"22222222-2222-2222-2222-222222222222";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"steps"];

    NSTimeInterval before = [[NSDate date] timeIntervalSince1970];
    XCTAssertTrue([self.cache writeBlobJson:blob forSessionCorrelationId:sessionId]);
    NSTimeInterval after = [[NSDate date] timeIntervalSince1970];

    NSDictionary *envelope = [self readEnvelopeDirectly];
    XCTAssertNotNil(envelope);
    XCTAssertEqualObjects(envelope[kFieldVersion], @(MSIDDeviceOnboardingBlobHandoffCache.envelopeVersion));
    XCTAssertEqualObjects(envelope[kFieldSessionCorrelationId], sessionId);
    XCTAssertEqualObjects(envelope[kFieldOnboardingBlob], blob);

    double writtenAt = [envelope[kFieldWrittenAt] doubleValue];
    XCTAssertGreaterThanOrEqual(writtenAt, before);
    XCTAssertLessThanOrEqual(writtenAt, after);
}

- (void)testWrite_shouldOverwritePreviousEntry
{
    NSString *sessionId = @"33333333-3333-3333-3333-333333333333";
    XCTAssertTrue([self.cache writeBlobJson:[self blobJsonWithSessionId:sessionId payload:@"first"]
                    forSessionCorrelationId:sessionId]);

    NSString *second = [self blobJsonWithSessionId:sessionId payload:@"second"];
    XCTAssertTrue([self.cache writeBlobJson:second forSessionCorrelationId:sessionId]);

    XCTAssertEqualObjects([self.cache readBlobJsonForSessionCorrelationId:sessionId], second);
}

#pragma mark - Write guards

- (void)testWrite_whenBlobIsBlank_shouldReturnNoAndWriteNothing
{
    NSString *sessionId = @"44444444-4444-4444-4444-444444444444";

    XCTAssertFalse([self.cache writeBlobJson:@"" forSessionCorrelationId:sessionId]);
    XCTAssertFalse([self.cache writeBlobJson:@"   " forSessionCorrelationId:sessionId]);
    XCTAssertNil([self readEnvelopeDirectly]);
}

- (void)testWrite_whenSessionIdIsBlank_shouldReturnNoAndWriteNothing
{
    NSString *blob = [self blobJsonWithSessionId:@"whatever" payload:@"steps"];

    XCTAssertFalse([self.cache writeBlobJson:blob forSessionCorrelationId:@""]);
    XCTAssertFalse([self.cache writeBlobJson:blob forSessionCorrelationId:@"   "]);
    XCTAssertNil([self readEnvelopeDirectly]);
}

#pragma mark - Read

- (void)testRead_whenNothingCached_shouldReturnNil
{
    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:@"any-session"]);
}

- (void)testRead_whenSessionIdIsBlank_shouldReturnNil
{
    NSString *sessionId = @"55555555-5555-5555-5555-555555555555";
    [self.cache writeBlobJson:[self blobJsonWithSessionId:sessionId payload:@"steps"] forSessionCorrelationId:sessionId];

    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:@""]);
    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:@"   "]);
}

- (void)testRead_whenSessionIdMismatches_shouldReturnNil
{
    NSString *sessionA = @"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    NSString *sessionB = @"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
    [self.cache writeBlobJson:[self blobJsonWithSessionId:sessionA payload:@"steps"] forSessionCorrelationId:sessionA];

    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:sessionB]);
}

- (void)testRead_whenWithinTtl_shouldReturnBlob
{
    NSString *sessionId = @"66666666-6666-6666-6666-666666666666";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"steps"];
    NSTimeInterval writtenAt = [[NSDate date] timeIntervalSince1970] - 10.0;
    [self writeEnvelopeDirectlyWithSessionId:sessionId blob:blob writtenAt:writtenAt];

    XCTAssertEqualObjects([self.cache readBlobJsonForSessionCorrelationId:sessionId], blob);
}

- (void)testRead_whenEntryExpired_shouldReturnNilAndRemoveEntry
{
    NSString *sessionId = @"77777777-7777-7777-7777-777777777777";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"steps"];
    NSTimeInterval expired = [[NSDate date] timeIntervalSince1970] - (MSIDDeviceOnboardingBlobHandoffCache.defaultTtlSeconds + 60.0);
    [self writeEnvelopeDirectlyWithSessionId:sessionId blob:blob writtenAt:expired];

    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:sessionId]);
    // Expired entry should be purged as a side effect of the read.
    XCTAssertNil([self readEnvelopeDirectly]);
}

- (void)testRead_whenWrittenAtInFuture_shouldReturnNilAndRemoveEntry
{
    NSString *sessionId = @"88888888-8888-8888-8888-888888888888";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"steps"];
    NSTimeInterval future = [[NSDate date] timeIntervalSince1970] + 120.0;
    [self writeEnvelopeDirectlyWithSessionId:sessionId blob:blob writtenAt:future];

    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:sessionId]);
    XCTAssertNil([self readEnvelopeDirectly]);
}

#pragma mark - Clear

- (void)testClear_whenSessionMatches_shouldRemoveEntry
{
    NSString *sessionId = @"99999999-9999-9999-9999-999999999999";
    [self.cache writeBlobJson:[self blobJsonWithSessionId:sessionId payload:@"steps"] forSessionCorrelationId:sessionId];

    [self.cache clearBlobForSessionCorrelationId:sessionId];

    XCTAssertNil([self.cache readBlobJsonForSessionCorrelationId:sessionId]);
    XCTAssertNil([self readEnvelopeDirectly]);
}

- (void)testClear_whenSessionMismatches_shouldNotRemoveEntry
{
    NSString *sessionA = @"cccccccc-cccc-cccc-cccc-cccccccccccc";
    NSString *sessionB = @"dddddddd-dddd-dddd-dddd-dddddddddddd";
    NSString *blob = [self blobJsonWithSessionId:sessionA payload:@"steps"];
    [self.cache writeBlobJson:blob forSessionCorrelationId:sessionA];

    [self.cache clearBlobForSessionCorrelationId:sessionB];

    XCTAssertEqualObjects([self.cache readBlobJsonForSessionCorrelationId:sessionA], blob);
}

#pragma mark - sessionCorrelationIdFromBlobJson

- (void)testSessionCorrelationIdFromBlobJson_whenPresent_shouldReturnId
{
    NSString *sessionId = @"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee";
    NSString *blob = [self blobJsonWithSessionId:sessionId payload:@"steps"];

    XCTAssertEqualObjects([MSIDDeviceOnboardingBlobHandoffCache sessionCorrelationIdFromBlobJson:blob], sessionId);
}

- (void)testSessionCorrelationIdFromBlobJson_whenMissingOrInvalid_shouldReturnNil
{
    XCTAssertNil([MSIDDeviceOnboardingBlobHandoffCache sessionCorrelationIdFromBlobJson:nil]);
    XCTAssertNil([MSIDDeviceOnboardingBlobHandoffCache sessionCorrelationIdFromBlobJson:@""]);
    XCTAssertNil([MSIDDeviceOnboardingBlobHandoffCache sessionCorrelationIdFromBlobJson:@"not-json"]);
    XCTAssertNil([MSIDDeviceOnboardingBlobHandoffCache sessionCorrelationIdFromBlobJson:[self blobJsonWithSessionId:nil payload:@"steps"]]);
}

@end
