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

+ (instancetype)sharedInstanceByQueryKey:(NSString *)queryKey
                                 keyType:(MSIDFlightManagerQueryKeyType)keyType
{
    if ([NSString msidIsStringNilOrBlank:queryKey])
    {
        // Use shared flight manager if queryKey is nil or empty
        return [MSIDFlightManager sharedInstance];
    }
    
    static NSMutableDictionary<NSString *, MSIDFlightManager *> *instancesByQueryKey = nil;
    static dispatch_once_t onceToken;
    static dispatch_queue_t synchronizationQueue;
    
    dispatch_once(&onceToken, ^{
        instancesByQueryKey = [NSMutableDictionary new];
        synchronizationQueue = dispatch_queue_create("com.microsoft.msidflightmanager.querykey", DISPATCH_QUEUE_CONCURRENT);
    });
    
    __block MSIDFlightManager *instance = nil;
    
    // First, try to read the instance concurrently
    dispatch_sync(synchronizationQueue, ^{
        instance = instancesByQueryKey[queryKey];
    });
    
    if (!instance)
    {
        // If not found, create and insert with a barrier write
        dispatch_barrier_sync(synchronizationQueue, ^{
            instance = instancesByQueryKey[queryKey];
            if (!instance)
            {
                instance = [[self.class alloc] initInternal];
                
                id<MSIDFlightManagerInterface> flightProvider = [[MSIDFlightManager sharedInstance].queryKeyFlightProvider
                                                                 flightProviderForQueryKey:queryKey
                                                                 keyType:keyType];
                if (flightProvider)
                {
                    instance.flightProvider = flightProvider;
                }
                
                instancesByQueryKey[queryKey] = instance;
            }
        });
    }
    
    return instance;
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
    // Use a synchronous barrier so the assignment (and the release of any previously
    // installed provider) completes before the setter returns. An async barrier let the
    // previous provider be released on the queue after the setter returned, racing with
    // concurrent readers and allowing a stale/nil provider to be observed.
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        self->_flightProvider = flightProvider;
    });
}

#pragma mark - MSIDFlightManagerInterface

- (BOOL)boolForKey:(nonnull NSString *)flightKey 
{
    __block BOOL result = NO;
    // Read and use the provider entirely on the synchronization queue while holding a
    // strong local reference, so a concurrent setFlightProvider: cannot deallocate it
    // between the nil-check and the message send (use-after-free -> SIGSEGV).
    dispatch_sync(self.synchronizationQueue, ^{
        id<MSIDFlightManagerInterface> provider = self->_flightProvider;
        if (provider)
        {
            result = [provider boolForKey:flightKey];
        }
    });
    
    return result;
}

- (nullable NSString *)stringForKey:(nonnull NSString *)flightKey
{
    __block NSString *result = nil;
    // Read and use the provider entirely on the synchronization queue while holding a
    // strong local reference, so a concurrent setFlightProvider: cannot deallocate it
    // between the nil-check and the message send (use-after-free -> SIGSEGV).
    dispatch_sync(self.synchronizationQueue, ^{
        id<MSIDFlightManagerInterface> provider = self->_flightProvider;
        if (provider)
        {
            result = [provider stringForKey:flightKey];
        }
    });
    
    return result;
}


@end
