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

#import "MSIDDIContainer.h"

@interface MSIDDIContainerEntry : NSObject

@property (nonatomic, assign) MSIDDIContainerLifetime lifetime;
@property (nonatomic, copy) id _Nonnull (^factory)(void);

@end

@implementation MSIDDIContainerEntry
@end

@interface MSIDDIContainer ()

@property (nonatomic) NSMutableDictionary<NSString *, MSIDDIContainerEntry *> *entryByKey;
@property (nonatomic) NSMutableDictionary<NSString *, id> *singletonCache;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDDIContainer

#pragma mark - Class methods

+ (MSIDDIContainer *)sharedInstance
{
    static MSIDDIContainer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [MSIDDIContainer new];
    });
    return sharedInstance;
}

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _entryByKey = [NSMutableDictionary new];
        _singletonCache = [NSMutableDictionary new];
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msiddicontainer-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }

    return self;
}

#pragma mark - Registration

- (void)registerClass:(Class)cls
             lifetime:(MSIDDIContainerLifetime)lifetime
              factory:(id _Nonnull (^)(void))factory
{
    NSParameterAssert(cls);
    NSParameterAssert(factory);

    [self registerKey:[self keyForClass:cls] lifetime:lifetime factory:factory];
}

- (void)registerProtocol:(Protocol *)proto
                lifetime:(MSIDDIContainerLifetime)lifetime
                 factory:(id _Nonnull (^)(void))factory
{
    NSParameterAssert(proto);
    NSParameterAssert(factory);

    [self registerKey:[self keyForProtocol:proto] lifetime:lifetime factory:factory];
}

- (void)registerKey:(NSString *)key
           lifetime:(MSIDDIContainerLifetime)lifetime
            factory:(id _Nonnull (^)(void))factory
{
    MSIDDIContainerEntry *entry = [MSIDDIContainerEntry new];
    entry.lifetime = lifetime;
    entry.factory = factory;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        self.entryByKey[key] = entry;
        [self.singletonCache removeObjectForKey:key];
    });
}

#pragma mark - Resolution

- (id)resolveClass:(Class)cls
{
    NSParameterAssert(cls);
    return [self resolveKey:[self keyForClass:cls]
                description:NSStringFromClass(cls)
            defaultProvider:nil];
}

- (id)resolveProtocol:(Protocol *)proto
{
    NSParameterAssert(proto);
    return [self resolveKey:[self keyForProtocol:proto]
                description:NSStringFromProtocol(proto)
            defaultProvider:nil];
}

- (id)resolveClass:(Class)cls
         orDefault:(id _Nonnull (^)(void))defaultProvider
{
    NSParameterAssert(cls);
    NSParameterAssert(defaultProvider);
    return [self resolveKey:[self keyForClass:cls]
                description:NSStringFromClass(cls)
            defaultProvider:defaultProvider];
}

- (id)resolveProtocol:(Protocol *)proto
            orDefault:(id _Nonnull (^)(void))defaultProvider
{
    NSParameterAssert(proto);
    NSParameterAssert(defaultProvider);
    return [self resolveKey:[self keyForProtocol:proto]
                description:NSStringFromProtocol(proto)
            defaultProvider:defaultProvider];
}

#pragma mark - Class-method seams

- (Class)resolveImplClassForProtocol:(Protocol *)proto
                           orDefault:(Class _Nonnull (^)(void))defaultProvider
{
    NSParameterAssert(proto);
    NSParameterAssert(defaultProvider);

    id resolved = [self resolveKey:[self keyForProtocol:proto]
                       description:NSStringFromProtocol(proto)
                   defaultProvider:^id _Nonnull {
                       Class defaultClass = defaultProvider();
                       // Cast Class -> id; +resolveKey: validates non-nil.
                       return (id)defaultClass;
                   }];
    return (Class)resolved;
}

- (Class)resolveImplClassForClass:(Class)cls
                        orDefault:(Class _Nonnull (^)(void))defaultProvider
{
    NSParameterAssert(cls);
    NSParameterAssert(defaultProvider);

    id resolved = [self resolveKey:[self keyForClass:cls]
                       description:NSStringFromClass(cls)
                   defaultProvider:^id _Nonnull {
                       Class defaultClass = defaultProvider();
                       return (id)defaultClass;
                   }];
    return (Class)resolved;
}

- (id)resolveKey:(NSString *)key
     description:(NSString *)description
 defaultProvider:(id _Nullable (^)(void))defaultProvider
{
    __block id cached = nil;
    __block MSIDDIContainerEntry *entry = nil;

    // Concurrent read: many resolves can run in parallel; only writes
    // (registration / singleton install / reset) take the barrier.
    dispatch_sync(self.synchronizationQueue, ^{
        cached = self.singletonCache[key];
        if (cached) return;
        entry = self.entryByKey[key];
    });

    if (cached) return cached;

    if (!entry)
    {
        if (defaultProvider)
        {
            // No registration: the caller has supplied its own default.
            // Invoke it outside the queue — defaults often re-enter via
            // the caller's existing +sharedInstance and must not deadlock
            // the container. Result is intentionally not cached here; the
            // caller owns its own singleton storage.
            id defaultInstance = defaultProvider();
            if (!defaultInstance)
            {
                NSAssert(NO, @"MSIDDIContainer: default provider returned nil for '%@'", description);
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"MSIDDIContainer: default provider returned nil for '%@'", description]
                                             userInfo:nil];
            }
            return defaultInstance;
        }

        NSAssert(NO, @"MSIDDIContainer: no factory registered for '%@'", description);
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"MSIDDIContainer: no factory registered for '%@'", description]
                                     userInfo:nil];
    }

    if (entry.lifetime == MSIDDIContainerLifetimeSingleton)
    {
        // Double-checked install under a barrier so concurrent resolves
        // observe the cached singleton instead of racing parallel factory
        // invocations. Factories registered with this lifetime are expected
        // to be cheap, side-effect free, and free of re-entrant calls back
        // into the container for the same key (which would deadlock).
        __block id resolvedInstance = nil;
        dispatch_barrier_sync(self.synchronizationQueue, ^{
            id existing = self.singletonCache[key];
            if (existing)
            {
                resolvedInstance = existing;
                return;
            }
            id newInstance = entry.factory();
            if (!newInstance)
            {
                // Leave resolvedInstance nil; caller throws below.
                return;
            }
            self.singletonCache[key] = newInstance;
            resolvedInstance = newInstance;
        });

        if (!resolvedInstance)
        {
            NSAssert(NO, @"MSIDDIContainer: factory returned nil for '%@'", description);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"MSIDDIContainer: factory returned nil for '%@'", description]
                                         userInfo:nil];
        }
        return resolvedInstance;
    }

    // Transient: invoke the factory outside the queue. Each resolve
    // produces a fresh instance and never touches the singleton cache.
    id instance = entry.factory();
    if (!instance)
    {
        NSAssert(NO, @"MSIDDIContainer: factory returned nil for '%@'", description);
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"MSIDDIContainer: factory returned nil for '%@'", description]
                                     userInfo:nil];
    }
    return instance;
}

#pragma mark - Reset

- (void)reset
{
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        [self.entryByKey removeAllObjects];
        [self.singletonCache removeAllObjects];
    });
}

#pragma mark - Private

- (NSString *)keyForClass:(Class)cls
{
    return [@"C:" stringByAppendingString:NSStringFromClass(cls)];
}

- (NSString *)keyForProtocol:(Protocol *)proto
{
    return [@"P:" stringByAppendingString:NSStringFromProtocol(proto)];
}

@end
