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

@implementation MSIDGCDStarvationDetector {
    NSThread *_monitorThread;
    BOOL _shouldStop;
    NSTimeInterval _interval;
    NSTimeInterval _timeout;
    void (^_callback)(void);
}

#pragma mark - Public API

// We need to start the monitoring in a customized thread to avoid the current thread been blocked
- (void)startMonitoringWithInterval:(NSTimeInterval)interval
                            timeout:(NSTimeInterval)timeout
                          onStarved:(void (^)(void))callback
{
    if (self.running) return;

    _interval = interval;
    _timeout = timeout;
    _callback = [callback copy];
    _shouldStop = NO;

    _monitorThread = [[NSThread alloc] initWithTarget:self
                                             selector:@selector(monitorLoop)
                                               object:nil];
    _monitorThread.name = [NSString stringWithFormat:@"%@-%@", @"com.microsoft.msid.gcdStarvationMonitor.thread", [NSUUID UUID].UUIDString];
    [_monitorThread start];
    _running = YES;
}

- (void)stopMonitoring {
    @synchronized(self) {
        _shouldStop = YES;
    }
    
    // Wait for monitor thread to finish
    if (_monitorThread && !_monitorThread.isFinished) {
        [_monitorThread cancel];
        // Give it time to clean up
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_monitorThread = nil;
            self->_callback = nil;
        });
    }}

- (void)monitorLoop {
    @autoreleasepool {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCD starvation monitor started on thread: %@", [NSThread currentThread]);
        
        while (YES) {
            @synchronized(self) {
                if (_shouldStop || [NSThread currentThread].isCancelled) {
                    break;
                }
            }
            
            BOOL starved = [self isThreadStarvedWithTimeout:_timeout];
            if (starved && _callback) {
                _callback();
            }
            
            [NSThread sleepForTimeInterval:_interval];
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"GCD starvation monitor stopped");
        
        @synchronized(self) {
            _running = NO;
        }
    }
}

- (BOOL)isThreadStarvedWithTimeout:(NSTimeInterval)timeout {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    // The "ping" — will only execute if GCD has an available worker
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
