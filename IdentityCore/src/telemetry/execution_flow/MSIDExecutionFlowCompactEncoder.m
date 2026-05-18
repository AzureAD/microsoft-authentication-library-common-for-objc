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

#import "MSIDExecutionFlowCompactEncoder.h"
#import "MSIDExecutionFlow.h"
#import "MSIDExecutionFlowConstants.h"
#import "NSString+MSIDExtensions.h"

NSString *const MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION = @"1.0.0";

NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED = @"succeeded";
NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_FAILED    = @"failed";
NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_CANCELLED = @"cancelled";

NSString *const MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG = @"\u2026trunc";

// Envelope keys
static NSString *const kCompactKeyVersion        = @"v";
static NSString *const kCompactKeyCorrelationId  = @"cid";
static NSString *const kCompactKeyBrokerName     = @"n";
static NSString *const kCompactKeyBrokerVersion  = @"av";
static NSString *const kCompactKeyAuthOutcome    = @"ao";
static NSString *const kCompactKeyErrorCode      = @"ec";
static NSString *const kCompactKeyPerf           = @"perf";
static NSString *const kCompactKeyStartTime      = @"st";
static NSString *const kCompactKeyDuration       = @"dur";
static NSString *const kCompactKeyEventFlow      = @"ef";

// Optional event-blob keys we request from the flow when assembling `ef`.
// Mandatory keys (`t`, `ts`, `tid`) are always emitted by the blob regardless.
static NSString *const kEventOptionalKeyDiagnostic = @"d";
static NSString *const kEventOptionalKeyErrorCode  = @"e";
static NSString *const kEventOptionalKeyRef        = @"ref";

@implementation MSIDExecutionFlowCompactEncoder

+ (nullable NSString *)encodeExecutionFlow:(nullable MSIDExecutionFlow *)flow
                              correlationId:(nullable NSString *)correlationId
                                 brokerName:(nullable NSString *)brokerName
                              brokerVersion:(nullable NSString *)brokerVersion
                                authOutcome:(NSString *)authOutcome
                                  errorCode:(nullable NSString *)errorCode
                                startTimeMs:(uint64_t)startTimeMs
                                 durationMs:(uint64_t)durationMs
                                   maxBytes:(NSUInteger)maxBytes
{
    if (!flow)
    {
        return nil;
    }

    NSParameterAssert(authOutcome.length > 0);
    if (authOutcome.length == 0)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"authOutcome is required; refusing to encode execution flow envelope", nil);
        return nil;
    }

    NSSet<NSString *> *queryKeys = [NSSet setWithArray:@[kEventOptionalKeyDiagnostic,
                                                         kEventOptionalKeyErrorCode,
                                                         kEventOptionalKeyRef]];
    NSArray<NSDictionary<NSString *, id> *> *events = [flow executionFlowDictionariesWithKeys:queryKeys];
    NSMutableArray<NSDictionary<NSString *, id> *> *workingEvents = [events mutableCopy];

    NSString *encoded = [self encodeWithCorrelationId:correlationId
                                           brokerName:brokerName
                                        brokerVersion:brokerVersion
                                          authOutcome:authOutcome
                                            errorCode:errorCode
                                          startTimeMs:startTimeMs
                                           durationMs:durationMs
                                               events:workingEvents
                                            truncated:NO];

    if (!encoded)
    {
        return nil;
    }

    if (maxBytes == 0)
    {
        return encoded;
    }

    NSUInteger byteLength = [encoded lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (byteLength <= maxBytes)
    {
        return encoded;
    }

    // Truncate: drop oldest events FIFO until the envelope (with sentinel) fits.
    while (workingEvents.count > 0)
    {
        [workingEvents removeObjectAtIndex:0];

        NSString *candidate = [self encodeWithCorrelationId:correlationId
                                                 brokerName:brokerName
                                              brokerVersion:brokerVersion
                                                authOutcome:authOutcome
                                                  errorCode:errorCode
                                                startTimeMs:startTimeMs
                                                 durationMs:durationMs
                                                     events:workingEvents
                                                  truncated:YES];

        if (!candidate)
        {
            return nil;
        }

        NSUInteger candidateLength = [candidate lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (candidateLength <= maxBytes)
        {
            return candidate;
        }
    }

    // Even with no events left, emit the envelope with just the sentinel so consumers
    // can detect that truncation occurred.
    return [self encodeWithCorrelationId:correlationId
                              brokerName:brokerName
                           brokerVersion:brokerVersion
                             authOutcome:authOutcome
                               errorCode:errorCode
                             startTimeMs:startTimeMs
                              durationMs:durationMs
                                  events:@[]
                               truncated:YES];
}

#pragma mark - Private

+ (NSString *)encodeWithCorrelationId:(NSString *)correlationId
                           brokerName:(NSString *)brokerName
                        brokerVersion:(NSString *)brokerVersion
                          authOutcome:(NSString *)authOutcome
                            errorCode:(NSString *)errorCode
                          startTimeMs:(uint64_t)startTimeMs
                           durationMs:(uint64_t)durationMs
                               events:(NSArray<NSDictionary<NSString *, id> *> *)events
                            truncated:(BOOL)truncated
{
    NSMutableArray<NSDictionary<NSString *, id> *> *eventsCopy = [events mutableCopy] ?: [NSMutableArray new];
    if (truncated)
    {
        [eventsCopy addObject:@{ MSID_EXECUTION_FLOW_TAG: MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG }];
    }

    NSMutableDictionary<NSString *, id> *perf = [NSMutableDictionary new];
    perf[kCompactKeyVersion]   = MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION;
    perf[kCompactKeyStartTime] = @(startTimeMs);
    perf[kCompactKeyDuration]  = @(durationMs);
    perf[kCompactKeyEventFlow] = eventsCopy;

    NSMutableDictionary<NSString *, id> *envelope = [NSMutableDictionary new];
    envelope[kCompactKeyVersion]      = MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION;
    envelope[kCompactKeyAuthOutcome]  = authOutcome ?: @"";
    envelope[kCompactKeyPerf]         = perf;

    if (correlationId.length > 0)
    {
        envelope[kCompactKeyCorrelationId] = correlationId;
    }
    if (brokerName.length > 0)
    {
        envelope[kCompactKeyBrokerName] = brokerName;
    }
    if (brokerVersion.length > 0)
    {
        envelope[kCompactKeyBrokerVersion] = brokerVersion;
    }
    if (errorCode.length > 0)
    {
        envelope[kCompactKeyErrorCode] = errorCode;
    }

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:envelope
                                                   options:kNilOptions
                                                     error:&jsonError];
    if (!data)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil,
                              @"Failed to encode execution flow envelope: %@",
                              MSID_PII_LOG_MASKABLE(jsonError.localizedDescription));
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
