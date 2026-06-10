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
// LIABILITY, WHETHER IN AN ACTION, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

#import <Foundation/Foundation.h>

@class MSIDExecutionFlowBlob;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDExecutionFlowUtils : NSObject

/// Returns the singleton execution‑flow utility instance.
+ (instancetype)sharedInstance;

/**
 Convert a blob dictionary into a JSON string, always including required fields (t, ts, tid) in that order and optionally filtering by a set of additional keys.

 @param queryKeys The set of field names to include in the JSON output in addition to the required fields. If nil or empty, all available fields are output.
 @return A JSON-formatted string representing the blob.
 */
- (NSString *)convertDictionary:(NSDictionary *)dictionary
           toJsonStringWithKeys:(NSSet<NSString *> *)queryKeys;

@end

NS_ASSUME_NONNULL_END
