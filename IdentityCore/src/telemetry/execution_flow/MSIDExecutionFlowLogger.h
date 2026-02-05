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

@class MSIDExecutionFlow;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDExecutionFlowLogger : NSObject

/*!
 Returns the shared singleton instance of MSIDExecutionFlowLogger.

 @return A singleton MSIDExecutionFlowLogger for registering and tracking execution flows.
 */
+ (MSIDExecutionFlowLogger *)sharedInstance;

/*!
 Begins tracking a new execution flow under the specified correlation identifier.

 @param correlationId The unique identifier for the execution flow to register.
 */
- (void)registerExecutionFlowWithCorrelationId:(NSUUID *)correlationId;

/*!
 Inserts a tag into the execution flow identified by the given correlation identifier, optionally attaching extra information.

 @param tag The tag string to insert into the execution flow.
 @param info An optional dictionary containing additional context or metadata to associate with the tag.
 @param correlationId The unique identifier of the execution flow into which the tag should be inserted.
 */
- (void)insertTag:(NSString *)tag
        extraInfo:(nullable NSDictionary *)info
withCorrelationId:(NSUUID *)correlationId;

/*!
 Retrieves and flushes the execution flow for the specified correlation identifier asynchronously.

 @param correlationId The unique identifier of the execution flow to retrieve and flush.
 @param queryKeys  An optional set of keys to filter which tags or entries are included. Pass nil to include all entries.
 @param completion A block invoked with the string representation of the execution flow matching the query keys, or nil if no flow exists for the given identifier.
 */
- (void)retrieveAndFlushExecutionFlowWithCorrelationId:(NSUUID *)correlationId
                                            queryKeys:(nullable NSSet<NSString *> *)queryKeys
                                           completion:(void (^)(NSString * _Nullable executionFlow))completion;

@end

NS_ASSUME_NONNULL_END
