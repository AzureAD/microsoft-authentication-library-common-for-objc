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

static NSTimeInterval starvationCheckTimeout = 0.01; //10 ms - timeout for detecting if GCD thread pool is starved
static NSTimeInterval starvationCheckInterval = 1; //1000 ms - interval between starvation checks
static NSTimeInterval maxMonitoringDuration = 15.0; //15 seconds - maximum monitoring duration to prevent indefinite running

@interface MSIDGCDStarvationDetector()

@property (nonatomic) BOOL running;
@property (nonatomic) BOOL shouldStop;
@property (nonatomic) NSThread *monitorThread;
@property (nonatomic) NSTimeInterval gcdStarvedDuration;
@property (nonatomic) NSInteger totalPingCount;
@property (nonatomic) NSInteger starvedPingCount;
@property (nonatomic) NSDate *monitoringStartTime;

@end

@implementation MSIDGCDStarvationDetector

#pragma mark - Public API

// We need to start the monitoring in a customized thread to avoid the current thread which invokes this detector being blocked
- (void)startMonitoring
{
    @synchronized(self) {
        if (self.running) return;

        self.shouldStop = NO;
        self.monitoringStartTime = [NSDate date];
        self.monitorThread = [[NSThread alloc] initWithTarget:self
                                                 selector:@selector(monitorLoop)
                                                   object:nil];
        self.monitorThread.name = [NSString stringWithFormat:@"%@-%@", @"com.microsoft.msid.MSIDGCDStarvationDetector.thread", [NSUUID UUID].UUIDString];
        [self.monitorThread start];
        self.running = YES;
    }
}

- (NSTimeInterval)stopMonitoring {
    @synchronized (self) {
        self.shouldStop = YES;
        if (self.monitorThread) {
            [self.monitorThread cancel];
        }
        self.monitorThread = nil;
        self.running = NO;
        return self.gcdStarvedDuration;
    }
}

- (void)monitorLoop {
    @autoreleasepool {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCDStarvationDetector -- started on thread: %@", [NSThread currentThread]);
        
        while (YES) {
            @synchronized (self)
            {
                if (self.shouldStop || [NSThread currentThread].isCancelled) {
                    break;
                }
                
                NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.monitoringStartTime];
                if (elapsed >= maxMonitoringDuration) {
                    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"GCDStarvationDetector -- reached maximum duration (%.2fs), stopping", elapsed);
                    [self stopMonitoring];
                    break;
                }
                
                BOOL starved = [self isThreadStarvedWithTimeout:starvationCheckTimeout];
                self.totalPingCount += 1;
                if (starved) {
                    self.gcdStarvedDuration += (starvationCheckTimeout + (self.starvedPingCount == 0 ? 0 : starvationCheckInterval));
                    self.starvedPingCount += 1;
                    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"GCDStarvationDetector -- starvation detected, cumulative duration: %.2fms", self.gcdStarvedDuration * 1000);
                }
                
            }
            [NSThread sleepForTimeInterval:starvationCheckInterval];
        }
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCDStarvationDetector -- stopped on thread: %@", [NSThread currentThread]);
    }
}

- (BOOL)isThreadStarvedWithTimeout:(NSTimeInterval)timeout {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    // The "ping" — will only execute if GCD has an available worker in qos
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        // Signal the semaphore when a GCD worker thread becomes available
        dispatch_semaphore_signal(sema);
    });

    long result = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
    
    // result == 0 means semaphore was signaled (GCD thread available)
    // result != 0 means timeout occurred (GCD thread starvation)
    return (result != 0);
}


@end
