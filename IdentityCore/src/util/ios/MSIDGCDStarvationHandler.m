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


#import "MSIDGCDStarvationHandler.h"

@interface MSIDGCDStarvationHandler ()
@property (nonatomic) NSThread *fallbackThread;
@property (nonatomic) dispatch_queue_t starvationTestQueue;
@end

@implementation MSIDGCDStarvationHandler

+ (instancetype)sharedHandler {
    static MSIDGCDStarvationHandler *handler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[MSIDGCDStarvationHandler alloc] init];
    });
    return handler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _starvationTestQueue = dispatch_queue_create("com.microsoft.msid.starvation.pintest.queue", DISPATCH_QUEUE_SERIAL);
        [self setupFallbackThread];
    }
    
    return self;
}

- (void)setupFallbackThread {
    _fallbackThread = [[NSThread alloc] initWithTarget:self
                                               selector:@selector(runFallbackThread)
                                                 object:nil];
    _fallbackThread.name = @"com.microsoft.msid.gcdFallback.thread";
    [_fallbackThread start];
}

- (void)runFallbackThread {
    @autoreleasepool {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        
        // Keep thread alive
        [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow]
                                         target:self
                                       selector:@selector(keepThreadAlive)
                                       userInfo:nil
                                        repeats:NO];
        
        while (!_fallbackThread.isCancelled) {
            @autoreleasepool {
                [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            }
        }
    }
}

- (void)keepThreadAlive {
    // Empty method to keep run loop alive
}

- (BOOL)isGCDThreadPoolStarvedWithTimeout:(NSTimeInterval)timeout {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // Dispatch a simple task to test GCD responsiveness
    dispatch_async(_starvationTestQueue, ^{
        dispatch_semaphore_signal(semaphore);
    });
    
    // Wait with timeout
    dispatch_time_t timeoutTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC));
    long result = dispatch_semaphore_wait(semaphore, timeoutTime);
    
    return result != 0; // Non-zero means timeout occurred
}

- (void)executeBlock:(dispatch_block_t)block fallbackToCustomThread:(BOOL)fallbackToCustomThread {
    if (!fallbackToCustomThread) {
        // Always use GCD
        dispatch_async(_starvationTestQueue, block);
        return;
    }
    
    // Test for thread starvation
    if ([self isGCDThreadPoolStarvedWithTimeout:0.01]) { // 10ms timeout
        // GCD is starved, use custom thread
        [self performSelector:@selector(executeBlockOnFallbackThread:)
                     onThread:_fallbackThread
                   withObject:block
                waitUntilDone:NO];
    } else {
        // GCD is available
        dispatch_async(_starvationTestQueue, block);
    }
}

- (void)executeBlockOnFallbackThread:(dispatch_block_t)block {
    block();
}

@end
