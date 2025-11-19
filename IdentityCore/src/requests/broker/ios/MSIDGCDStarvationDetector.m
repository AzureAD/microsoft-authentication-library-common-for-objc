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

#import "MSIDGCDStarvationDetector.h"
#import "MSIDLogger+Internal.h"


static NSTimeInterval threadingTimeout = 0.01; //10 ms
static NSTimeInterval threadingPingInterval = 0.1; //100 ms

@interface MSIDGCDStarvationDetector()

@property (nonatomic) BOOL running;
@property (nonatomic) BOOL shouldStop;
@property (nonatomic) NSThread *monitorThread;
@property (nonatomic) NSTimeInterval gcdStarvedDuration;
@property (nonatomic) NSInteger totalPingCount;
@property (nonatomic) NSInteger starvedPingCount;

@end

@implementation MSIDGCDStarvationDetector

#pragma mark - Public API

// We need to start the monitoring in a customized thread to avoid the current thread which invokes this detector being blocked
- (void)startMonitoring
{
    @synchronized(self) {
        if (self.running) return;

        self.shouldStop = NO;
        _monitorThread = [[NSThread alloc] initWithTarget:self
                                                 selector:@selector(monitorLoop)
                                                   object:nil];
        _monitorThread.name = [NSString stringWithFormat:@"%@-%@", @"com.microsoft.msid.MSIDGCDStarvationDetector.thread", [NSUUID UUID].UUIDString];
        [_monitorThread start];
        self.running = YES;
    }
}

- (NSTimeInterval)stopMonitoring {
    NSThread *threadToWait = nil;
    @synchronized (self) {
        self.shouldStop = YES;
        threadToWait = self.monitorThread;
        if (threadToWait) {
            [threadToWait cancel];
        }
    }
    // Wait for the thread to finish before cleanup, outside the lock
    if (threadToWait) {
        while (!threadToWait.isFinished) {
            [NSThread sleepForTimeInterval:0.01];
        }
    }
    @synchronized (self) {
        self.monitorThread = nil;
        self.running = NO;
        return self.gcdStarvedDuration;
    }
}

- (void)monitorLoop {
    @autoreleasepool {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCD starvation monitor started on thread: %@", [NSThread currentThread]);
        
        while (YES) {
            if (self.shouldStop || [NSThread currentThread].isCancelled) {
                break;
            }
            @synchronized (self) {
                BOOL starved = [self isThreadStarvedWithTimeout:threadingTimeout];
                self.totalPingCount += 1;
           
                
                if (starved) {
                    self.gcdStarvedDuration += (threadingTimeout + threadingPingInterval);
                    self.starvedPingCount += 1;
                    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"GCD thread pool starvation detected, cumulative duration: %.2fms", self.gcdStarvedDuration * 1000);
                }
            }
            
            [NSThread sleepForTimeInterval:threadingPingInterval];
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCD starvation monitor stopped on thread: %@", [NSThread currentThread]);
    }
}

- (BOOL)isThreadStarvedWithTimeout:(NSTimeInterval)timeout {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    // The "ping" — will only execute if GCD has an available worker in qos
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        // No need for starved variable - semaphore result is sufficient
        dispatch_semaphore_signal(sema);
    });

    long result = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
    
    // result == 0 means semaphore was signaled (GCD thread available)
    // result != 0 means timeout occurred (GCD thread starvation)
    return (result != 0);
}


@end
