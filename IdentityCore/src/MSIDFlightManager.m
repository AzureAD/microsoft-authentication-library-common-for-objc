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


#import "MSIDFlightManager.h"

@interface MSIDFlightManager()

@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end


@implementation MSIDFlightManager

+ (instancetype)sharedInstance
{
    static MSIDFlightManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self.class alloc] initInternal];
    });
    
    return sharedInstance;
}

- (instancetype)initInternal
{
    self = [super init];
    if (self)
    {
        _synchronizationQueue = [self initializeDispatchQueue];
    }
    return self;
}

- (dispatch_queue_t)initializeDispatchQueue
{
    NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidflightmanager-%@", [NSUUID UUID].UUIDString];
    return dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
}

- (void)setFlightProvider:(id<MSIDFlightManagerInterface>)flightProvider
{
    dispatch_barrier_async(self.synchronizationQueue, ^{
        self->_flightProvider = flightProvider;
    });
}

#pragma mark - MSIDFlightManagerInterface

- (BOOL)boolForKey:(nonnull NSString *)flightKey 
{
    __block BOOL result = NO;
    if (self.flightProvider)
    {
        dispatch_sync(self.synchronizationQueue, ^{
            result = [self.flightProvider boolForKey:flightKey];
        });
    }
    
    return result;
}

- (nullable NSString *)stringForKey:(nonnull NSString *)flightKey
{
    __block NSString* result = nil;
    if (self.flightProvider)
    {
        dispatch_sync(self.synchronizationQueue, ^{
            result = [self.flightProvider stringForKey:flightKey];
        });
    }
    
    return result;
}


@end
