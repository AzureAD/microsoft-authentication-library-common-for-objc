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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Lifetime semantics for services registered with @c MSIDDIContainer.
 *
 * - @c MSIDDIContainerLifetimeSingleton: factory is invoked at most once;
 *   subsequent resolutions return the cached instance.
 * - @c MSIDDIContainerLifetimeTransient: factory is invoked on every resolve
 *   call and a fresh instance is returned each time.
 */
typedef NS_ENUM(NSInteger, MSIDDIContainerLifetime)
{
    MSIDDIContainerLifetimeSingleton,
    MSIDDIContainerLifetimeTransient
};

/**
 * A lightweight, thread-safe dependency-injection container.
 *
 * @c MSIDDIContainer lets producers register a factory keyed by a class or
 * protocol, and lets consumers resolve a concrete instance for that key
 * without taking a direct dependency on the producer. Tests can install
 * per-key overrides to inject mocks without swizzling.
 *
 * Resolution order for a given key is: override (if any) > cached singleton
 * (if applicable) > registered factory.
 *
 * Resolving a key that has neither an override nor a registered factory is a
 * programmer error and triggers an assertion.
 */
@interface MSIDDIContainer : NSObject

/**
 * The process-wide shared container. Most callers should use this; create a
 * fresh instance only in unit tests that need full isolation.
 */
@property (class, nonatomic, readonly) MSIDDIContainer *sharedInstance;

#pragma mark - Registration

/**
 * Register a factory that produces instances satisfying the given class key.
 *
 * @param cls       The class used as the lookup key.
 * @param lifetime  Singleton or transient instance management.
 * @param factory   Block invoked to produce a new instance. Must not return
 *                  @c nil.
 *
 * If a factory was previously registered for the same key it is replaced.
 * Registration does not clear an existing override; callers that need a
 * clean slate should call @c resetAllOverrides separately.
 */
- (void)registerClass:(Class)cls
             lifetime:(MSIDDIContainerLifetime)lifetime
              factory:(id _Nonnull (^)(void))factory;

/**
 * Register a factory that produces instances satisfying the given protocol key.
 *
 * @param proto     The protocol used as the lookup key.
 * @param lifetime  Singleton or transient instance management.
 * @param factory   Block invoked to produce a new instance. Must not return
 *                  @c nil.
 */
- (void)registerProtocol:(Protocol *)proto
                lifetime:(MSIDDIContainerLifetime)lifetime
                 factory:(id _Nonnull (^)(void))factory;

#pragma mark - Resolution

/**
 * Resolve an instance for the given class key.
 *
 * @param cls  The class previously registered (or overridden).
 *
 * @return The resolved instance. Never @c nil. Triggers an assertion if no
 *         factory or override exists for @c cls.
 */
- (id)resolveClass:(Class)cls;

/**
 * Resolve an instance for the given protocol key.
 *
 * @param proto  The protocol previously registered (or overridden).
 *
 * @return The resolved instance. Never @c nil. Triggers an assertion if no
 *         factory or override exists for @c proto.
 */
- (id)resolveProtocol:(Protocol *)proto;

#pragma mark - Test overrides

/**
 * Install a per-key override that takes precedence over any registered
 * factory and any cached singleton for the given class.
 *
 * @param cls       The class key to override.
 * @param instance  The instance to return on subsequent resolves.
 *
 * Intended for unit tests. Production code should use the registration APIs.
 */
- (void)setOverrideForClass:(Class)cls instance:(id)instance;

/**
 * Install a per-key override that takes precedence over any registered
 * factory for the given protocol.
 *
 * @param proto     The protocol key to override.
 * @param instance  The instance to return on subsequent resolves.
 */
- (void)setOverrideForProtocol:(Protocol *)proto instance:(id)instance;

/**
 * Remove a previously-installed override for the given class key.
 *
 * If no override is installed, this is a no-op. Cached singletons are
 * preserved.
 */
- (void)removeOverrideForClass:(Class)cls;

/**
 * Remove a previously-installed override for the given protocol key.
 */
- (void)removeOverrideForProtocol:(Protocol *)proto;

/**
 * Clear every override on the container. Cached singletons and registered
 * factories are preserved.
 *
 * Tests should call this from @c -tearDown to leave the container in a
 * predictable state for subsequent tests.
 */
- (void)resetAllOverrides;

@end

NS_ASSUME_NONNULL_END
