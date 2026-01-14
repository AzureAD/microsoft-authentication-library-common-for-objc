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

- (nullable instancetype)initWithTag:(NSString *)tag
                            timeStep:(NSNumber *)ts
                            threadId:(NSNumber *)tid;

// Developer can set any extra key/value pair(s) apart from tag, ts and tid.
- (void)setObject:(id)obj forKey:(NSString *)key;

// Converts the blob to a JSON string representation, if query keys are not provided, return all fields
- (NSString *)blobToStringWithKeys:(nullable NSSet<NSString *>*)queryKeys;

@end

NS_ASSUME_NONNULL_END
