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
 * - @c MSIDDIContainerLifetimeSingleton: factory is invoked exactly once for
 *   the lifetime of the registration; subsequent resolutions return the
 *   cached instance. The container serializes the first invocation across
 *   concurrent callers.
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
 * without taking a direct dependency on the producer. Tests inject mocks by
 * calling the same registration APIs (typically from a base test class's
 * @c -setUp), and call @c reset from @c -tearDown to leave the container
 * clean for the next test.
 *
 * Resolution order for a given key is: cached singleton (if applicable) >
 * registered factory.
 *
 * Resolving a key that has no registered factory is a programmer error and
 * triggers an assertion (or, for the @c orDefault overloads, falls through
 * to the supplied default).
 */
@interface MSIDDIContainer : NSObject

/**
 * The process-wide shared container. Most callers should use this; create a
 * fresh instance only in unit tests that need full isolation.
 */
@property (class, nonatomic, readonly) MSIDDIContainer *sharedInstance;

#pragma mark - Parameterized construction

/**
 * Registered factories take no arguments, so call-site parameters (URLs,
 * tenant IDs, request contexts, ...) need one of three patterns. Pick the
 * one that matches where the parameter actually comes from.
 *
 * @b 1. @b Captured-config @b factory — parameters known at registration time.
 * The factory closes over them, callers resolve with no arguments.
 *
 * @code
 * NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
 * [container registerClass:[MSIDAADAuthority class]
 *                 lifetime:MSIDDIContainerLifetimeSingleton
 *                  factory:^id {
 *                      return [[MSIDAADAuthority alloc] initWithURL:url
 *                                                           context:nil
 *                                                             error:nil];
 *                  }];
 * @endcode
 *
 * @b 2. @b Class-method @b seam — caller still owns @c alloc/init, container
 * just picks the class. Use @c resolveImplClassForClass: /
 * @c resolveImplClassForProtocol: when only the @e type needs to be
 * swappable (e.g., production @c MSIDAADAuthority vs. a test double):
 *
 * @code
 * Class cls = [container resolveImplClassForClass:[MSIDAADAuthority class]
 *                                       orDefault:^Class { return [MSIDAADAuthority class]; }];
 * MSIDAADAuthority *authority = [[cls alloc] initWithURL:url context:ctx error:&err];
 * @endcode
 *
 * @b 3. @b Factory-as-dependency — parameters only known at the call site.
 * Register a typedef'd block as the dependency; resolve the block, then
 * invoke it with the per-call arguments:
 *
 * @code
 * typedef MSIDAADAuthority * _Nullable (^MSIDAADAuthorityFactory)(NSURL *url,
 *                                                                id<MSIDRequestContext> _Nullable ctx,
 *                                                                NSError **error);
 *
 * [container registerProtocol:@protocol(MSIDAADAuthorityFactoryProviding)
 *                    lifetime:MSIDDIContainerLifetimeSingleton
 *                     factory:^id {
 *                         return (MSIDAADAuthorityFactory)^(NSURL *u, id ctx, NSError **e) {
 *                             return [[MSIDAADAuthority alloc] initWithURL:u context:ctx error:e];
 *                         };
 *                     }];
 *
 * MSIDAADAuthorityFactory make =
 *     [container resolveProtocol:@protocol(MSIDAADAuthorityFactoryProviding)];
 * MSIDAADAuthority *authority = make(url, ctx, &err);
 * @endcode
 */

#pragma mark - Registration

/**
 * Register a factory that produces instances satisfying the given class key.
 *
 * @param cls       The class used as the lookup key.
 * @param lifetime  Singleton or transient instance management.
 * @param factory   Block invoked to produce a new instance. Must not return
 *                  @c nil.
 *
 * If a factory was previously registered for the same key it is replaced
 * and the cached singleton (if any) is cleared.
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
 * @param cls  The class previously registered.
 *
 * @return The resolved instance. Never @c nil. Triggers an assertion if no
 *         factory exists for @c cls.
 */
- (id)resolveClass:(Class)cls;

/**
 * Resolve an instance for the given protocol key.
 *
 * @param proto  The protocol previously registered.
 *
 * @return The resolved instance. Never @c nil. Triggers an assertion if no
 *         factory exists for @c proto.
 */
- (id)resolveProtocol:(Protocol *)proto;

/**
 * Resolve an instance for the given class key, falling back to a default
 * provider when nothing is registered.
 *
 * Resolution order: cached singleton > registered factory > @c defaultProvider.
 *
 * Use this overload to make a class's existing @c +sharedInstance funnel
 * through the container without requiring an explicit registration step.
 * Tests inject mocks by calling @c registerClass:lifetime:factory: with a
 * factory that returns the mock; production callers fall through to
 * @c defaultProvider, which typically returns the class's pre-existing
 * default instance.
 *
 * The result of @c defaultProvider is intentionally @b not cached by the
 * container — the caller is expected to own its own singleton storage (e.g.,
 * a @c dispatch_once inside @c +sharedInstance). This keeps lifetime
 * semantics predictable and avoids the container silently upgrading a
 * non-singleton default into a cached one.
 *
 * @param cls              The class key to resolve.
 * @param defaultProvider  Block invoked only when no factory is
 *                         registered. Must not return @c nil.
 *
 * @return The resolved instance. Never @c nil.
 */
- (id)resolveClass:(Class)cls
         orDefault:(id _Nonnull (^)(void))defaultProvider;

/**
 * Resolve an instance for the given protocol key, falling back to a default
 * provider when nothing is registered.
 *
 * @see resolveClass:orDefault:
 */
- (id)resolveProtocol:(Protocol *)proto
            orDefault:(id _Nonnull (^)(void))defaultProvider;

#pragma mark - Class-method seams

/**
 * Resolve a @c Class implementation registered against the given protocol,
 * falling back to a default class when nothing is overridden or registered.
 *
 * Use this overload when the seam being virtualized is a @b class method
 * (e.g., a utility @c +classMethod that tests previously stubbed via
 * @c MSIDTestSwizzle). Declare the seam as a protocol that uses the @c +
 * marker for class methods, have the production class conform to that
 * protocol, and resolve the implementing class through this method:
 *
 * @code
 * @protocol MSIDWPJKeysProviding <NSObject>
 * + (nullable MSIDWPJKeyPairWithCert *)getWPJKeysWithTenantId:(NSString *)t
 *                                                     context:(id)c;
 * @end
 *
 * Class<MSIDWPJKeysProviding> impl =
 *     [[MSIDDIContainer sharedInstance]
 *         resolveImplClassForProtocol:@protocol(MSIDWPJKeysProviding)
 *                           orDefault:^Class { return self; }];
 * return [impl getWPJKeysWithTenantId:tenantId context:context];
 * @endcode
 *
 * Tests register a fake class that conforms to the same protocol via
 * @c registerProtocol:lifetime:factory: with a factory that returns
 * @c (id)[FakeClass class]. Because the resolved value is statically typed
 * as @c Class<Protocol>, the compiler verifies the fake class implements
 * every class method declared by the protocol.
 *
 * @param proto             The protocol key to resolve.
 * @param defaultProvider   Block invoked only when no factory is registered.
 *                          Must not return @c Nil.
 *
 * @return The resolved class. Never @c Nil.
 */
- (Class)resolveImplClassForProtocol:(Protocol *)proto
                           orDefault:(Class _Nonnull (^)(void))defaultProvider;

/**
 * Resolve a @c Class implementation registered against the given class key,
 * falling back to a default class when nothing is overridden or registered.
 *
 * Class-keyed sibling of @c resolveImplClassForProtocol:orDefault:. Useful
 * when the seam is a class method on a concrete utility class and you do
 * not want to introduce a separate protocol — the registered class need only
 * supply matching @c + selectors at runtime.
 *
 * @see resolveImplClassForProtocol:orDefault:
 */
- (Class)resolveImplClassForClass:(Class)cls
                        orDefault:(Class _Nonnull (^)(void))defaultProvider;

#pragma mark - Reset

/**
 * Clear every registration and cached singleton on the container.
 *
 * Tests should call this from @c -tearDown (typically from a shared base
 * test class) to leave the container in a predictable state for subsequent
 * tests.
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END
