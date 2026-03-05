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
@class MSIDExecutionFlowBlob;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDExecutionFlow : NSObject

/**
 Inserts a diagnostic tag into the execution flow log.
 
 @param tag
 A non‐null string that identifies the event or milestone being recorded.
 @param triggeringTime
 The timestamp at which the tag event occurred.
 @param tid
 The numeric identifier of the thread on which the event was triggered.
 @param info
 An optional dictionary of additional context or metadata for the event; may be nil.
 */
- (void)insertTag:(NSString *)tag
   triggeringTime:(NSDate *)triggeringTime
         threadId:(NSNumber *)tid
        extraInfo:(nullable NSDictionary *)info;

/**
 Exports the recorded execution flow entries as JSON strings, optionally filtered by a set of keys.
 
 @param queryKeys
 An optional NSSet of NSString keys used to select which portions of the execution flow
 to include in the output. Pass `nil` to export all recorded entries.
 @return
 A JSON-formatted NSString containing the filtered execution flow data, or `nil` if
 there is no data to export.
 */
- (nullable NSString *)exportExecutionFlowToJSONsWithKeys:(nullable NSSet<NSString *> *)queryKeys;

@end

NS_ASSUME_NONNULL_END
