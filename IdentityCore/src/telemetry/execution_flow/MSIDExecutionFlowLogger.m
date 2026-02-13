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
#import "MSIDBackgroundThreadUtil.h"

#define MAX_EXECUTION_FLOW_ELIMINATION_POOL_SIZE 200

@interface MSIDExecutionFlowLogger ()

@property (nonatomic) BOOL enabled;
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
        _enabled = YES;
        _executionFlowMap = [MSIDCache new];
        _executionFlowLoggerQueue = dispatch_queue_create("com.microsoft.executionFlowLoggerQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)registerExecutionFlowWithCorrelationId:(NSUUID *)correlationId
{
    if (!self.enabled) { return; }

    if (!correlationId || [NSString msidIsStringNilOrBlank:correlationId.UUIDString])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"CorrelationId cannot be nil", nil);
        return;
    }
    
    dispatch_async(self.executionFlowLoggerQueue, ^{
        if (!self.enabled) { return; }

        if (self.executionFlowMap.count >= MAX_EXECUTION_FLOW_ELIMINATION_POOL_SIZE)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"The number of execution flows is reaching the maximum, cannot add new flows. Please check if ended flows are flushed correctly", nil);
            return;
        }
        
        if ([self.executionFlowMap objectForKey:correlationId])
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"The execution flow for this correlationId %@ has been registered, and cannot be re-registered. This is a developer error, please check", correlationId, nil);
            return;
        }
        
        MSIDExecutionFlow *executionFlow = [MSIDExecutionFlow new];
        [self.executionFlowMap setObject:executionFlow forKey:correlationId];
    });
}

- (void)insertTag:(NSString *)tag
        extraInfo:(NSDictionary *)info
withCorrelationId:(NSUUID *)correlationId
{
    if (!self.enabled) { return; }

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
    if (pthread_threadid_np(NULL, &tid) != 0)
    {
        tid = (uint64_t)[NSThread currentThread].hash; // Fallback
    }
    
    NSDate *triggeringTime = [NSDate date];
    dispatch_async(self.executionFlowLoggerQueue, ^{
        if (!self.enabled) { return; }

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

// Asynchronously retrieves and flushes the execution flow for the specified correlation identifier.
- (void)retrieveExecutionFlowWithCorrelationId:(NSUUID *)correlationId
                                     queryKeys:(nullable NSSet<NSString *> *)queryKeys
                                   shouldFlush:(BOOL)shouldFlush
                                    completion:(void (^)(NSString * _Nullable executionFlow))completion
{
    if (!self.enabled)
    {
        if (completion) { completion(nil); }
        return;
    }

    if (!correlationId || [NSString msidIsStringNilOrBlank:correlationId.UUIDString])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"CorrelationId cannot be nil", nil);
        if (completion) { completion(nil); }
        return;
    }

    dispatch_async(self.executionFlowLoggerQueue, ^{
        if (!self.enabled)
        {
            [MSIDBackgroundThreadUtil executeAsyncOnOtherBackgroundThread:^{
                if (completion)
                {
                    completion(nil);
                }
            }];
            return;
        }

        MSIDExecutionFlow *flow = [self.executionFlowMap objectForKey:correlationId];
        if (shouldFlush)
        {
            [self.executionFlowMap removeObjectForKey:correlationId];
        }
        
        NSString *result = [flow exportExecutionFlowToJSONsWithKeys:queryKeys];
        // Dispatch completion on a background queue so the logger queue can continue.
        [MSIDBackgroundThreadUtil executeAsyncOnOtherBackgroundThread:^{
            if (completion)
            {
                completion(result);
            }
        }];
    });
}

- (void)flush
{
    if (!self.enabled) { return; }

    dispatch_async(self.executionFlowLoggerQueue, ^{
        [self.executionFlowMap removeAllObjects];
    });
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    if (!enabled)
    {
        dispatch_async(self.executionFlowLoggerQueue, ^{
            [self.executionFlowMap removeAllObjects];
        });
    }
}

@end
