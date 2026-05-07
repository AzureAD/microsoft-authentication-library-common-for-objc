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
{
    NSMutableDictionary<NSString *, MSIDDIContainerEntry *> *_entryByKey;
    NSMutableDictionary<NSString *, id> *_overrideByKey;
    NSMutableDictionary<NSString *, id> *_singletonCache;
    NSLock *_lock;
}

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
        _overrideByKey = [NSMutableDictionary new];
        _singletonCache = [NSMutableDictionary new];
        _lock = [NSLock new];
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

    [_lock lock];
    _entryByKey[key] = entry;
    [_singletonCache removeObjectForKey:key];
    [_lock unlock];
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

- (id)resolveKey:(NSString *)key
     description:(NSString *)description
 defaultProvider:(id _Nullable (^)(void))defaultProvider
{
    [_lock lock];

    id override = _overrideByKey[key];
    if (override)
    {
        [_lock unlock];
        return override;
    }

    id cached = _singletonCache[key];
    if (cached)
    {
        [_lock unlock];
        return cached;
    }

    MSIDDIContainerEntry *entry = _entryByKey[key];
    if (!entry)
    {
        [_lock unlock];

        if (defaultProvider)
        {
            // No registration and no override: the caller has supplied its
            // own default. Invoke it outside the lock — defaults often
            // re-enter via the caller's existing +sharedInstance and must
            // not deadlock the container. Result is intentionally not
            // cached here; the caller owns its own singleton storage.
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

        NSAssert(NO, @"MSIDDIContainer: no factory or override registered for '%@'", description);
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"MSIDDIContainer: no factory or override registered for '%@'", description]
                                     userInfo:nil];
    }

    if (entry.lifetime == MSIDDIContainerLifetimeSingleton)
    {
        // Invoke the factory while holding the lock so concurrent resolves
        // observe the cached singleton instead of racing parallel factory
        // invocations. Factories registered with this lifetime are expected
        // to be cheap, side-effect free, and free of re-entrant calls back
        // into the container for the same key (which would deadlock).
        id instance = entry.factory();
        if (!instance)
        {
            [_lock unlock];
            NSAssert(NO, @"MSIDDIContainer: factory returned nil for '%@'", description);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"MSIDDIContainer: factory returned nil for '%@'", description]
                                         userInfo:nil];
        }

        _singletonCache[key] = instance;
        [_lock unlock];
        return instance;
    }

    id _Nonnull (^factory)(void) = entry.factory;
    [_lock unlock];

    id instance = factory();
    if (!instance)
    {
        NSAssert(NO, @"MSIDDIContainer: factory returned nil for '%@'", description);
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"MSIDDIContainer: factory returned nil for '%@'", description]
                                     userInfo:nil];
    }
    return instance;
}

#pragma mark - Test overrides

- (void)setOverrideForClass:(Class)cls instance:(id)instance
{
    NSParameterAssert(cls);
    NSParameterAssert(instance);

    [_lock lock];
    _overrideByKey[[self keyForClass:cls]] = instance;
    [_lock unlock];
}

- (void)setOverrideForProtocol:(Protocol *)proto instance:(id)instance
{
    NSParameterAssert(proto);
    NSParameterAssert(instance);

    [_lock lock];
    _overrideByKey[[self keyForProtocol:proto]] = instance;
    [_lock unlock];
}

- (void)removeOverrideForClass:(Class)cls
{
    NSParameterAssert(cls);

    [_lock lock];
    [_overrideByKey removeObjectForKey:[self keyForClass:cls]];
    [_lock unlock];
}

- (void)removeOverrideForProtocol:(Protocol *)proto
{
    NSParameterAssert(proto);

    [_lock lock];
    [_overrideByKey removeObjectForKey:[self keyForProtocol:proto]];
    [_lock unlock];
}

- (void)resetAllOverrides
{
    [_lock lock];
    [_overrideByKey removeAllObjects];
    [_lock unlock];
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
