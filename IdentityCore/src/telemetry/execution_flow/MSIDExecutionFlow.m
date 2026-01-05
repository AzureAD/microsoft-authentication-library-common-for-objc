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
        _executionFlowWritingQueue = dispatch_queue_create("com.microsoft.executionFlowWritingQueue", DISPATCH_QUEUE_CONCURRENT);
        _startTime = [NSDate date];
    }
    
    return self;
}

- (void)insertExecutionBlob:(MSIDExecutionFlowBlob *)blob
{
    dispatch_barrier_async(self.executionFlowWritingQueue, ^{
        [self.executionFlow addObject:blob];
    });
}

- (NSArray *)executionFlowWithKeys:(NSArray *)blobKeys
{
    __weak typeof(self) weakSelf = self;
    __block NSMutableArray *executionFlow = [NSMutableArray new];
    dispatch_sync(self.executionFlowWritingQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        for (MSIDExecutionFlowBlob *blob in strongSelf.executionFlow) {
            [executionFlow addObject:[blob executionBlobWithKeys:blobKeys]];
        }
    });
    
    return executionFlow;
}

@end
