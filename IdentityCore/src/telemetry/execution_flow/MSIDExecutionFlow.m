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

#import "MSIDExecutionFlow.h"
#import "MSIDExecutionFlowBlob.h"
#import "MSIDJsonSerializer.h"
#import "NSDate+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDExecutionFlowConstants.h"

#define MAX_EXECUTION_FLOW_SIZE 50

@interface MSIDExecutionFlow ()

@property (nonatomic) NSMutableArray *executionFlow;
@property (nonatomic) dispatch_queue_t executionFlowWritingQueue;
@property (nonatomic) NSDate *startTime;

@end

@implementation MSIDExecutionFlow

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _executionFlow = [NSMutableArray new];
        _executionFlowWritingQueue = dispatch_queue_create("com.microsoft.executionFlowWritingQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)insertTag:(NSString *)tag
   triggeringTime:(NSDate *)triggeringTime
         threadId:(NSNumber *)tid
        extraInfo:(NSDictionary *)info
{
    if ([NSString msidIsStringNilOrBlank:tag])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, MSID_EXECUTION_FLOW_TAG_NIL_MESSAGE, nil);
        return;
    }
    
    if (!tid)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, MSID_EXECUTION_FLOW_TID_NIL_MESSAGE, nil);
        return;
    }
    
    if (!triggeringTime)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, MSID_EXECUTION_FLOW_TRIGGERING_TIME_NIL_MESSAGE, nil);
        return;
    }
    
    dispatch_async(self.executionFlowWritingQueue, ^{
        NSTimeInterval interval = 0;
        if (!self.startTime)
        {
            self.startTime = triggeringTime;
        }
        else
        {
            interval = [triggeringTime timeIntervalSinceDate:self.startTime];
        }
        
        int64_t ts = (int64_t)(interval * 1000.0);

        MSIDExecutionFlowBlob *blob = [[MSIDExecutionFlowBlob alloc] initWithTag:tag timeStep:@(ts) threadId:tid];
        if (!blob)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, MSID_EXECUTION_FLOW_FAILED_TO_CREATE_BLOB_MESSAGE, nil);
            return;
        }
        
        if (info && info.allKeys.count > 0)
        {
            for (id key in info)
            {
                [blob setObject:info[key] forKey:key];
            }
        }
        // This is unlikely but just in case to keep the execution flow not tracking too many
        if (self.executionFlow.count >= MAX_EXECUTION_FLOW_SIZE)
        {
            [self.executionFlow removeObjectAtIndex:0];
        }
        
        [self.executionFlow addObject:blob];
    });
}

- (NSString *)exportExecutionFlowToJSONsWithKeys:(NSSet<NSString *> *)queryKeys
{
    
    __block NSMutableString *jsonArray = [NSMutableString stringWithString:MSID_EXECUTION_FLOW_JSON_OPEN_BRACKET];
    
    dispatch_sync(self.executionFlowWritingQueue, ^{
        for (NSUInteger i = 0; i < self.executionFlow.count; i++)
        {
            MSIDExecutionFlowBlob *blob = self.executionFlow[i];
            NSString *blobJSON = [blob blobToStringWithKeys:queryKeys];
            
            if (blobJSON)
            {
                [jsonArray appendString:blobJSON];
                
                // Add comma separator if not the last element
                if (i < self.executionFlow.count - 1)
                {
                    [jsonArray appendString:MSID_EXECUTION_FLOW_JSON_COMMA];
                }
            }
        }
    });
    
    [jsonArray appendString:MSID_EXECUTION_FLOW_JSON_CLOSE_BRACKET];
    
    // Return nil if array is empty
    if ([jsonArray isEqualToString:MSID_EXECUTION_FLOW_JSON_EMPTY_ARRAY])
    {
        return nil;
    }
    
    return jsonArray;
}

@end
