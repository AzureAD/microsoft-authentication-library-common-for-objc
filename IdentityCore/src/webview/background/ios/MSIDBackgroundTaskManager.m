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

@interface MSIDBackgroundTaskManager()

@property (nonatomic) MSIDCache *taskCache;

@end

@interface MSIDBackgroundTaskData : NSObject

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
@property (nonnull, nonatomic) id callerReference;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (id)initWithTaskId:(UIBackgroundTaskIdentifier)backgroundTaskId caller:(id)caller;

@end

@implementation MSIDBackgroundTaskData

-(id)initWithTaskId:(UIBackgroundTaskIdentifier)backgroundTaskId caller:(id)caller
{
    self = [super init];
    if (self)
    {
        _backgroundTaskId = backgroundTaskId;
        __typeof__(caller) __weak weakCallerReference = caller;
        _callerReference = weakCallerReference;
    }
    return self;
}
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
 https://forums.developer.apple.com/message/253232#253232
 */

- (void)startOperationWithType:(MSIDBackgroundTaskType)type caller:(nonnull id)caller
{
    MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
    
    if (backgroundTaskData.backgroundTaskId != UIBackgroundTaskInvalid)
    {
        // Background task already started
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Start background app task with type %ld", (long)type);
    
    UIBackgroundTaskIdentifier backgroundTaskId = [[MSIDAppExtensionUtil sharedApplication] beginBackgroundTaskWithName:@"Interactive login"
                                                                  expirationHandler:^{
                                                                      MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Background task expired for type %ld", (long)type);
                                                                      [self stopAllOperationsForType:type];
                                                                  }];
    
    [self setBackgroundTask:[[MSIDBackgroundTaskData alloc] initWithTaskId:backgroundTaskId caller:caller] forType:type];
}

- (void)stopAllOperationsForType:(MSIDBackgroundTaskType)type
{
    MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
    
    if (backgroundTaskData.backgroundTaskId == UIBackgroundTaskInvalid)
    {
        // Background task not started
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Stop background task with type %ld", (long)type);
    [[MSIDAppExtensionUtil sharedApplication] endBackgroundTask:backgroundTaskData.backgroundTaskId];
    [self setBackgroundTask:[[MSIDBackgroundTaskData alloc] initWithTaskId:UIBackgroundTaskInvalid caller:backgroundTaskData.callerReference] forType:type];
}

- (void)stopOperationWithType:(MSIDBackgroundTaskType)type caller:(nonnull id)caller
{
    MSIDBackgroundTaskData *backgroundTaskData = [self backgroundTaskWithType:type];
    
    if ((backgroundTaskData.backgroundTaskId == UIBackgroundTaskInvalid) || (![caller isEqual:backgroundTaskData.callerReference]))
    {
        // Background task not started or background task can be stopped only if it started it
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Stop background task with type %ld", (long)type);
    [[MSIDAppExtensionUtil sharedApplication] endBackgroundTask:backgroundTaskData.backgroundTaskId];
    [self setBackgroundTask:[[MSIDBackgroundTaskData alloc] initWithTaskId:UIBackgroundTaskInvalid caller:backgroundTaskData.callerReference] forType:type];
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
