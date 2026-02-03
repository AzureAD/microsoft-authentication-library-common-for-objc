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


#import <Foundation/Foundation.h>

/*
 "t": "abcde",  // Tag name: 5 alphanumeric characters  (0-9, a-z) or a tag that is meaningful, no duplication in the code base
 "ts": 12,       // Timestep: milliseconds since the time the execution flow was created
 "tid": 1,      // Thread ID
 "d": 0,        // Optional: diagnostic code (iteration count, http code)
 "e": 1003,      // Optional: error code
 "ref": "class name" // Optional: when logging in parent class, this can be used to tell which subclass is invoking the flow
 */

NS_ASSUME_NONNULL_BEGIN

@interface MSIDExecutionFlowBlob : NSObject

/**
 Initializes an `MSIDExecutionFlowBlob` with the given tag, timestep, and thread identifier.
 
 @param tag   A string tag name (5 alphanumeric characters or a meaningful, unique identifier).
 @param ts    The timestep, in milliseconds, since this execution flow was created.
 @param tid   The thread identifier on which this flow is recorded.
 @return       A newly initialized `MSIDExecutionFlowBlob` instance, or `nil` if initialization fails.
 */
- (nullable instancetype)initWithTag:(NSString *)tag
                            timeStep:(NSNumber *)ts
                            threadId:(NSNumber *)tid;

/**
 Stores the given object for the specified key in the execution flow blob.
 
 Use this method to attach additional diagnostic information—such as error codes, iteration counts, or subclass references—to the execution flow. Stored values will be included when serializing the blob via `blobToStringWithKeys:`.
 
 @param obj The object to store. Can be any value (e.g., NSNumber, NSString) to include in the blob.
 @param key The key under which to store the object. Must be a non-empty string.
 */
- (void)setObject:(id)obj forKey:(NSString *)key;

/**
 Serializes the current execution flow blob into a string, optionally filtering by a set of keys.
 
 This method produces a loggable representation (e.g., JSON) of the core execution flow properties—tag, timestamp, and thread ID—along with any additional diagnostic entries added via `-setObject:forKey:`. If `queryKeys` is non-`nil`, only entries whose keys are contained in the set (plus the mandatory fields) will be included; if `queryKeys` is `nil` or empty, all stored entries are serialized.
 
 @param queryKeys An optional set of keys to filter which blob entries to include. Pass `nil` to serialize all entries.
 @return A string representation of the execution flow blob suitable for logging or telemetry, or an empty string if serialization fails.
 */
- (NSString *)blobToStringWithKeys:(nullable NSSet<NSString *>*)queryKeys;
@end

NS_ASSUME_NONNULL_END
