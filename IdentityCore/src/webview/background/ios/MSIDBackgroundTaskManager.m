//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDBackgroundTaskManager.h"
#import "MSIDAppExtensionUtil.h"
#import "MSIDCache.h"
#import "MSIDBackgroundTaskData.h"

@interface MSIDBackgroundTaskManager()

@property (nonatomic) MSIDCache *taskCache;

@end

@implementation MSIDBackgroundTaskManager

#pragma mark - Init

- (id)initInternal
{
    self = [super init];
    if (self)
    {
        _taskCache = [MSIDCache new];
    }
    return self;
}

+ (MSIDBackgroundTaskManager *)sharedInstance
{
    static dispatch_once_t once;
    static MSIDBackgroundTaskManager *singleton = nil;
    
    dispatch_once(&once, ^{
        singleton = [[MSIDBackgroundTaskManager alloc] initInternal];
    });
    
    return singleton;
}

#pragma mark - Implementation

/*
 Background task execution:
 https://developer.apple.com/forums/thread/85066
 */

- (void)startOperationWithType:(MSIDBackgroundTaskType)type
{
    [self startOperationWithType:type expirationHandler:nil];
}

- (nullable NSUUID *)startOperationWithType:(MSIDBackgroundTaskType)type
                          expirationHandler:(nullable dispatch_block_t)expirationHandler
{
    NSUUID *token = expirationHandler ? [NSUUID UUID] : nil;
    @synchronized (self.taskCache)
    {
        MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
        if (backgroundTaskData)
        {
            // A background task was already started for this type, updating count
            backgroundTaskData.callerReferenceCount++;
            if (token && expirationHandler)
            {
                backgroundTaskData.expirationHandlers[token] = [expirationHandler copy];
            }
            return token;
        }
        UIBackgroundTaskIdentifier backgroundTaskId = [[MSIDAppExtensionUtil sharedApplication] beginBackgroundTaskWithName:@"Interactive login"
                                                                                                          expirationHandler:^{
                                                                        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Background task expired for type %ld.", (long)type);
                                                                    // If a task took too long & OS has decided to kill it, end bg task for that type regardless of other requsts relying on bg protection.
                                                                        [self expireOperationWithType:type];
                                                                    }];
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Start background app task with type %ld & taskId : %lu", (long)type, (unsigned long)backgroundTaskId);
        MSIDBackgroundTaskData *newTaskData = [[MSIDBackgroundTaskData alloc] initWithTaskId:backgroundTaskId];
        if (token && expirationHandler)
        {
            newTaskData.expirationHandlers[token] = [expirationHandler copy];
        }
        [self setBackgroundTask:newTaskData forType:type];
    }
    return token;
}

- (void)stopOperationWithType:(MSIDBackgroundTaskType)type
{
    [self stopOperationWithType:type token:nil];
}

- (void)stopOperationWithType:(MSIDBackgroundTaskType)type
                        token:(nullable NSUUID *)token
{
    @synchronized (self.taskCache)
    {
        MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
        if (!backgroundTaskData)
        {
            return;
        }
        if (token)
        {
            if (!backgroundTaskData.expirationHandlers[token])
            {
                return;
            }
            [backgroundTaskData.expirationHandlers removeObjectForKey:token];
        }
        backgroundTaskData.callerReferenceCount--;
        if (backgroundTaskData.callerReferenceCount > 0)
        {
            // No background task found in task cache for specified type or there are still other tasks relying on background protection.
            return;
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Stop background task with type %ld & taskId : %lu", (long)type, backgroundTaskData.backgroundTaskId);
        [[MSIDAppExtensionUtil sharedApplication] endBackgroundTask:backgroundTaskData.backgroundTaskId];
        [self.taskCache removeObjectForKey:@(type)];
    }
}

- (void)expireOperationWithType:(MSIDBackgroundTaskType)type
{
    NSArray<dispatch_block_t> *handlersToInvoke = nil;
    @synchronized (self.taskCache)
    {
        MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
        if (!backgroundTaskData)
        {
            return;
        }
        handlersToInvoke = [backgroundTaskData.expirationHandlers allValues];
        [backgroundTaskData.expirationHandlers removeAllObjects];
        backgroundTaskData.callerReferenceCount = 1;
        [self stopOperationWithType:type token:nil];
    }

    for (dispatch_block_t handler in handlersToInvoke)
    {
        handler();
    }
}

#pragma mark - Task dictionary

- (MSIDBackgroundTaskData *)backgroundTaskWithType:(MSIDBackgroundTaskType)type
{
    return [self.taskCache objectForKey:@(type)];
}

- (void)setBackgroundTask:(MSIDBackgroundTaskData *)backgroundTaskData forType:(MSIDBackgroundTaskType)type
{
    [self.taskCache setObject:backgroundTaskData forKey:@(type)];
}

@end
