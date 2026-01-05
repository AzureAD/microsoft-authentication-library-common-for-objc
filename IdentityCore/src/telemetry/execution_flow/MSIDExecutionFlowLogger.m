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


#import "MSIDExecutionFlowLogger.h"
#import "MSIDCache.h"
#import "MSIDExecutionFlow.h"

@interface MSIDExecutionFlowLogger ()

@property (nonatomic) MSIDCache *executionFlowMap;

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
    }
    
    return self;
}

-(void)insertTag:(NSString *)tag
       extraInfo:(NSDictionary *)info
withCorrelationId:(NSString *)correlationId
{
    MSIDExecutionFlow *executionFlow = [self.executionFlowMap objectForKey:correlationId];
    if(!executionFlow)
    {
        executionFlow = [MSIDExecutionFlow new];
        [self.executionFlowMap setObject:executionFlow forKey:correlationId];
    }
    
    [executionFlow insertTag:tag extraInfo:info];
}

- (MSIDExecutionFlow *)retriveExecutionFlowWithCorrelationId:(NSString *)correlationId
{
    return [self.executionFlowMap objectForKey:correlationId];
}

@end
