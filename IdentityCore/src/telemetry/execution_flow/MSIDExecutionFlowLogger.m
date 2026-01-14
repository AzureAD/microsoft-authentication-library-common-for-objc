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

#include <pthread.h>
#import "MSIDExecutionFlowLogger.h"
#import "MSIDCache.h"
#import "MSIDExecutionFlow.h"
#import "NSString+MSIDExtensions.h"

#define MAX_EXECUTION_FLOW_ELIMINATION_POOL_SIZE 200

@interface MSIDExecutionFlowLogger ()

@property (nonatomic) MSIDCache *executionFlowMap;
@property (nonatomic) dispatch_queue_t executionFlowLoggerQueue;

@end

@implementation MSIDExecutionFlowLogger

+ (MSIDExecutionFlowLogger *)sharedInstance
{
    static dispatch_once_t once;
    static MSIDExecutionFlowLogger *singleton = nil;
    
    dispatch_once(&once, ^{
        singleton = [[MSIDExecutionFlowLogger alloc] init];
    });
    
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _executionFlowMap = [MSIDCache new];
        _executionFlowLoggerQueue = dispatch_queue_create("com.microsoft.executionFlowLoggerQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (void)registerExecutionFlowWithCorrelationId:(NSUUID *)correlationId
{
    if (!correlationId || [NSString msidIsStringNilOrBlank:correlationId.UUIDString])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"CorrelationId cannot be nil", nil);
        return;
    }
    
    dispatch_barrier_sync(self.executionFlowLoggerQueue, ^{
        NSSet<NSUUID *> *allFlowKeys = [NSSet setWithArray:self.executionFlowMap.toDictionary.allKeys];
        if (allFlowKeys.count >= MAX_EXECUTION_FLOW_ELIMINATION_POOL_SIZE)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"The number of execution flows are reaching maximum, cannot add new flows. Please check if ended flows are flushed correctly", nil);
            return;
        }
        
        if ([allFlowKeys containsObject:correlationId])
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"The execution flow for this correlationId %@ has been registered, and cannot be re-registered. This is a developer error, please check", correlationId, nil);
            return;
        }
        
        MSIDExecutionFlow *executionFlow = [MSIDExecutionFlow new];;
        [self.executionFlowMap setObject:executionFlow forKey:correlationId];
    });
}

- (void)insertTag:(NSString *)tag
       extraInfo:(NSDictionary *)info
withCorrelationId:(NSUUID *)correlationId
{
    if ([NSString msidIsStringNilOrBlank:tag])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Tag cannot be nil, fail to insert tag", nil);
        return;
    }
    
    if (!correlationId || [NSString msidIsStringNilOrBlank:correlationId.UUIDString])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"CorrelationId cannot be nil, fail to insert tag: %@", tag, nil);
        return;
    }
    
    __uint64_t tid = 0;
    if (pthread_threadid_np(NULL, &tid) != 0) {
        tid = (uint64_t)[NSThread currentThread].hash; // Fallback
    }
    
    NSDate *triggeringTime = [NSDate date];
    dispatch_barrier_async(self.executionFlowLoggerQueue, ^{        
        if (![self.executionFlowMap.toDictionary.allKeys containsObject:correlationId])
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"The execution flow for adding this tag %@ with correlationId: %@ has been flushed or not registered yet, this is a developer error, please check", tag, correlationId, nil);
            return;
        }
        
        MSIDExecutionFlow *executionFlow = [self.executionFlowMap objectForKey:correlationId];
        if(!executionFlow)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"The execution flow for this correlationId %@ is not registered and tag %@ cannot be added", correlationId, tag, nil);
            return;
        }
        
        [executionFlow insertTag:tag triggeringTime:triggeringTime threadId:@(tid) extraInfo:info];
    });
}

- (NSString *)retrieveAndFlushExecutionFlowWithCorrelationId:(NSUUID *)correlationId
                                                   querykeys:(NSSet<NSString *> *)queryKeys
{
    if (!correlationId || [NSString msidIsStringNilOrBlank:correlationId.UUIDString])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"CorrelationId cannot be nil", nil);
        return nil;
    }
    
    __block MSIDExecutionFlow *flow = nil;
    dispatch_sync(self.executionFlowLoggerQueue, ^{
        flow = [self.executionFlowMap objectForKey:correlationId];
    });
    
    dispatch_barrier_async(self.executionFlowLoggerQueue, ^{
        [self.executionFlowMap removeObjectForKey:correlationId];
    });
    
    return [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
}

- (void)flush
{
    dispatch_barrier_async(self.executionFlowLoggerQueue, ^{
        [self.executionFlowMap removeAllObjects];
    });
}

@end
