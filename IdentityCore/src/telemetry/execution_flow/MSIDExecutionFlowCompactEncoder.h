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

#import <Foundation/Foundation.h>

@class MSIDExecutionFlow;

NS_ASSUME_NONNULL_BEGIN

/// Schema version for the compact-key envelope (root `v` and `perf.v`).
extern NSString *const MSID_EXECUTION_FLOW_COMPACT_SCHEMA_VERSION;

/// Auth outcome values for `ao` (matches Android `AuthOutcome` enum SerializedNames).
extern NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED;
extern NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_FAILED;
extern NSString *const MSID_EXECUTION_FLOW_AUTH_OUTCOME_CANCELLED;

/// Sentinel event blob tag emitted when one or more event blobs are dropped to fit `maxBytes`.
extern NSString *const MSID_EXECUTION_FLOW_TRUNCATION_SENTINEL_TAG;

/**
 Encodes an `MSIDExecutionFlow` as a compact-key JSON envelope intended for the broker → OneAuth wire.

 The envelope shape (per spec FR-E2):

 ```
 {
   "v":   "1.0.0",                  // schema version
   "cid": "<correlation id>",       // optional
   "n":   "<broker name>",          // optional
   "av":  "<broker version>",       // optional
   "ao":  "succeeded|failed|cancelled",
   "ec":  "<error code>",           // optional, typically only on failure
   "perf": {
     "v":   "1.0.0",
     "st":  <start time, ms>,
     "dur": <duration, ms>,
     "ef":  [
       { "t": "...", "ts": <ms>, "tid": <int>, "d": <int>, "e": <int>, "ref": "..." },
       ...
     ]
   }
 }
 ```

 Compact event-blob keys (`t`, `ts`, `tid`, `d`, `e`, `ref`) match Android `EventTag`
 `@SerializedName` byte-for-byte (spec §11). Optional fields are omitted from the JSON
 object when not present.

 Pure function: no logger / no state / thread-safe.
 */
@interface MSIDExecutionFlowCompactEncoder : NSObject

/**
 Encode the supplied flow into a compact-key JSON envelope.

 @param flow            The flow to encode. If `nil`, returns `nil`. If the flow contains no
                        events, the encoder still emits the surrounding envelope with `"ef":[]`.
 @param correlationId   Optional correlation id to emit at the envelope root (`cid`).
 @param brokerName      Optional broker name (`n`).
 @param brokerVersion   Optional broker version (`av`).
 @param authOutcome     Required auth outcome string (`ao`); use one of
                        `MSID_EXECUTION_FLOW_AUTH_OUTCOME_SUCCEEDED` /
                        `..._FAILED` / `..._CANCELLED`.
 @param errorCode       Optional error code to emit at the envelope root (`ec`); typically
                        `nil` on success.
 @param startTimeMs     Wall-clock start time of the auth flow in milliseconds (`perf.st`).
 @param durationMs      Total auth-flow duration in milliseconds (`perf.dur`).
 @param maxBytes        Maximum encoded UTF-8 length. When `> 0`, oldest event blobs are
                        dropped (FIFO) until the encoded envelope fits, and a single
                        sentinel event `{ "t": "…trunc" }` is appended. When `0`, no
                        truncation is applied.
 @return                The encoded JSON string, or `nil` for `nil` input.
 */
+ (nullable NSString *)encodeExecutionFlow:(nullable MSIDExecutionFlow *)flow
                              correlationId:(nullable NSString *)correlationId
                                 brokerName:(nullable NSString *)brokerName
                              brokerVersion:(nullable NSString *)brokerVersion
                                authOutcome:(NSString *)authOutcome
                                  errorCode:(nullable NSString *)errorCode
                                startTimeMs:(uint64_t)startTimeMs
                                 durationMs:(uint64_t)durationMs
                                   maxBytes:(NSUInteger)maxBytes;

@end

NS_ASSUME_NONNULL_END
