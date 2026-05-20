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

#import <XCTest/XCTest.h>
#import "MSIDDIContainer.h"

#pragma mark - Test fixtures

@protocol MSIDDIContainerTestProtocol <NSObject>
- (NSString *)greeting;
@end

@interface MSIDDIContainerTestService : NSObject <MSIDDIContainerTestProtocol>
@property (nonatomic, readonly) NSString *identifier;
@end

@implementation MSIDDIContainerTestService

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _identifier = [[NSUUID UUID] UUIDString];
    }

    return self;
}

- (NSString *)greeting
{
    return @"hello";
}

@end

@interface MSIDDIContainerTestMockService : NSObject <MSIDDIContainerTestProtocol>
@end

@implementation MSIDDIContainerTestMockService

- (NSString *)greeting
{
    return @"mocked";
}

@end

#pragma mark - Class-method protocol fixtures

@protocol MSIDDIContainerTestClassMethodProtocol <NSObject>
+ (NSString *)greeting;
@end

@interface MSIDDIContainerTestClassMethodService : NSObject <MSIDDIContainerTestClassMethodProtocol>
@end

@implementation MSIDDIContainerTestClassMethodService

+ (NSString *)greeting
{
    return @"hello-class";
}

@end

@interface MSIDDIContainerTestClassMethodMockService : NSObject <MSIDDIContainerTestClassMethodProtocol>
@end

@implementation MSIDDIContainerTestClassMethodMockService

+ (NSString *)greeting
{
    return @"mocked-class";
}

@end

// Intentionally does NOT conform to MSIDDIContainerTestClassMethodProtocol —
// used to exercise the conformance-validation path in
// resolveImplClassForProtocol:orDefault: / resolveImplClassForClass:orDefault:.
@interface MSIDDIContainerTestNonConformingService : NSObject
@end

@implementation MSIDDIContainerTestNonConformingService
@end

#pragma mark - Tests

@interface MSIDDIContainerTests : XCTestCase
@property (nonatomic) MSIDDIContainer *container;
@end

@implementation MSIDDIContainerTests

- (void)setUp
{
    [super setUp];
    self.container = [MSIDDIContainer new];
}

- (void)testRegisterClass_whenSingletonLifetime_shouldReturnSameInstance
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];

    id first = [self.container resolveClass:[MSIDDIContainerTestService class]];
    id second = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertNotNil(first);
    XCTAssertTrue(first == second);
}

- (void)testRegisterClass_whenTransientLifetime_shouldReturnFreshInstance
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeTransient
                          factory:^id { return [MSIDDIContainerTestService new]; }];

    MSIDDIContainerTestService *first = [self.container resolveClass:[MSIDDIContainerTestService class]];
    MSIDDIContainerTestService *second = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertFalse(first == second);
    XCTAssertNotEqualObjects(first.identifier, second.identifier);
}

- (void)testRegisterProtocol_whenResolved_shouldReturnConcreteInstance
{
    [self.container registerProtocol:@protocol(MSIDDIContainerTestProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return [MSIDDIContainerTestService new]; }];

    id<MSIDDIContainerTestProtocol> resolved = [self.container resolveProtocol:@protocol(MSIDDIContainerTestProtocol)];

    XCTAssertNotNil(resolved);
    XCTAssertEqualObjects([resolved greeting], @"hello");
}

- (void)testRegisterClass_whenReregistered_shouldReplaceFactoryAndClearCache
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];
    id first = [self.container resolveClass:[MSIDDIContainerTestService class]];

    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return mock; }];

    id second = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertFalse(first == second);
    XCTAssertTrue(second == mock);
}

- (void)testRegisterProtocol_whenReregistered_shouldReplaceFactory
{
    [self.container registerProtocol:@protocol(MSIDDIContainerTestProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return [MSIDDIContainerTestService new]; }];

    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container registerProtocol:@protocol(MSIDDIContainerTestProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return mock; }];

    id<MSIDDIContainerTestProtocol> resolved = [self.container resolveProtocol:@protocol(MSIDDIContainerTestProtocol)];

    XCTAssertEqualObjects([resolved greeting], @"mocked");
}

- (void)testReset_whenCalled_shouldClearRegistrationsAndCache
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];
    [self.container resolveClass:[MSIDDIContainerTestService class]];

    [self.container reset];

    XCTAssertThrowsSpecificNamed([self.container resolveClass:[MSIDDIContainerTestService class]],
                                 NSException,
                                 NSInternalInconsistencyException);
}

- (void)testResolveClass_whenUnregistered_shouldThrow
{
    XCTAssertThrowsSpecificNamed([self.container resolveClass:[MSIDDIContainerTestService class]],
                                 NSException,
                                 NSInternalInconsistencyException);
}

- (void)testConcurrentResolution_whenSingletonLifetime_shouldReturnSameInstance
{
    __block NSInteger factoryInvocations = 0;
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id {
        @synchronized (self) { factoryInvocations++; }
        return [MSIDDIContainerTestService new];
    }];

    NSInteger iterations = 200;
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:iterations];
    NSLock *resultsLock = [NSLock new];

    dispatch_apply(iterations, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t __unused i) {
        id obj = [self.container resolveClass:[MSIDDIContainerTestService class]];
        [resultsLock lock];
        [results addObject:obj];
        [resultsLock unlock];
    });

    id first = results.firstObject;
    XCTAssertNotNil(first);
    for (id obj in results) XCTAssertTrue(obj == first);
    XCTAssertEqual(factoryInvocations, 1, @"Singleton factory must be invoked exactly once even under contention");
}

- (void)testResolveClass_whenFactoryReturnsNil_shouldThrow
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return nil; }];

    XCTAssertThrowsSpecificNamed([self.container resolveClass:[MSIDDIContainerTestService class]],
                                 NSException,
                                 NSInternalInconsistencyException);
}

#pragma mark - resolveClass:orDefault: / resolveProtocol:orDefault:

- (void)testResolveClassOrDefault_whenNothingRegistered_shouldReturnDefault
{
    MSIDDIContainerTestService *expected = [MSIDDIContainerTestService new];

    __block NSInteger calls = 0;
    id resolved = [self.container resolveClass:[MSIDDIContainerTestService class]
                                     orDefault:^id {
                                         calls++;
                                         return expected;
                                     }];

    XCTAssertEqual(resolved, expected);
    XCTAssertEqual(calls, 1);
}

- (void)testResolveClassOrDefault_whenFactoryRegistered_shouldNotInvokeDefault
{
    MSIDDIContainerTestService *factoryInstance = [MSIDDIContainerTestService new];
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return factoryInstance; }];

    __block NSInteger defaultCalls = 0;
    id resolved = [self.container resolveClass:[MSIDDIContainerTestService class]
                                     orDefault:^id {
                                         defaultCalls++;
                                         return [MSIDDIContainerTestService new];
                                     }];

    XCTAssertEqual(resolved, factoryInstance);
    XCTAssertEqual(defaultCalls, 0);
}

- (void)testResolveClassOrDefault_whenDefaultProviderReturnsNil_shouldThrow
{
    XCTAssertThrowsSpecificNamed([self.container resolveClass:[MSIDDIContainerTestService class]
                                                    orDefault:^id { return nil; }],
                                 NSException,
                                 NSInternalInconsistencyException);
}

- (void)testResolveClassOrDefault_whenCalledTwice_shouldInvokeDefaultEachTime
{
    // The container intentionally does NOT cache the default-provider result;
    // callers own their own singleton storage. This test pins that contract.
    __block NSInteger calls = 0;
    [self.container resolveClass:[MSIDDIContainerTestService class]
                       orDefault:^id {
                           calls++;
                           return [MSIDDIContainerTestService new];
                       }];
    [self.container resolveClass:[MSIDDIContainerTestService class]
                       orDefault:^id {
                           calls++;
                           return [MSIDDIContainerTestService new];
                       }];

    XCTAssertEqual(calls, 2);
}

- (void)testResolveProtocolOrDefault_whenNothingRegistered_shouldReturnDefault
{
    id<MSIDDIContainerTestProtocol> expected = [MSIDDIContainerTestService new];

    id resolved = [self.container resolveProtocol:@protocol(MSIDDIContainerTestProtocol)
                                        orDefault:^id { return expected; }];

    XCTAssertEqual(resolved, expected);
}

- (void)testSharedInstance_whenCalledTwice_shouldReturnSameContainer
{
    XCTAssertTrue([MSIDDIContainer sharedInstance] == [MSIDDIContainer sharedInstance]);
}

#pragma mark - Class-method seam

- (void)testResolveImplClassForProtocol_whenNothingRegistered_shouldReturnDefaultClass
{
    Class<MSIDDIContainerTestClassMethodProtocol> impl =
        (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
            resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                              orDefault:^Class {
                                  return [MSIDDIContainerTestClassMethodService class];
                              }];

    XCTAssertEqualObjects([impl greeting], @"hello-class");
}

- (void)testResolveImplClassForProtocol_whenClassFactoryRegistered_shouldReturnRegisteredClass
{
    [self.container registerProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return (id)[MSIDDIContainerTestClassMethodMockService class]; }];

    Class<MSIDDIContainerTestClassMethodProtocol> impl =
        (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
            resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                              orDefault:^Class {
                                  XCTFail(@"default should not be invoked when factory registered");
                                  return [MSIDDIContainerTestClassMethodService class];
                              }];

    XCTAssertEqualObjects([impl greeting], @"mocked-class");
}

- (void)testResolveImplClassForProtocol_whenDefaultProviderReturnsNil_shouldThrow
{
    XCTAssertThrowsSpecificNamed(([self.container
        resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                          orDefault:^Class { return Nil; }]),
        NSException, NSInternalInconsistencyException);
}

- (void)testResolveImplClassForClass_whenNothingRegistered_shouldReturnDefaultClass
{
    Class impl = [self.container
        resolveImplClassForClass:[MSIDDIContainerTestClassMethodService class]
                       orDefault:^Class {
                           return [MSIDDIContainerTestClassMethodService class];
                       }];

    XCTAssertEqual(impl, [MSIDDIContainerTestClassMethodService class]);
}

- (void)testResolveImplClassForClass_whenClassFactoryRegistered_shouldReturnRegisteredClass
{
    [self.container registerClass:[MSIDDIContainerTestClassMethodService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return (id)[MSIDDIContainerTestClassMethodMockService class]; }];

    Class impl = [self.container
        resolveImplClassForClass:[MSIDDIContainerTestClassMethodService class]
                       orDefault:^Class {
                           XCTFail(@"default should not be invoked when factory registered");
                           return [MSIDDIContainerTestClassMethodService class];
                       }];

    XCTAssertEqual(impl, [MSIDDIContainerTestClassMethodMockService class]);
}

- (void)testReset_whenAfterClassFactoryRegistered_shouldFallBackToDefault
{
    [self.container registerProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return (id)[MSIDDIContainerTestClassMethodMockService class]; }];
    [self.container reset];

    Class<MSIDDIContainerTestClassMethodProtocol> impl =
        (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
            resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                              orDefault:^Class {
                                  return [MSIDDIContainerTestClassMethodService class];
                              }];

    XCTAssertEqualObjects([impl greeting], @"hello-class");
}

#pragma mark - Conformance validation (Task 3612208)

- (void)testResolveImplClassForProtocol_whenRegisteredClassDoesNotConform_shouldAssert
{
    // Misregistration: a class that does NOT conform to the protocol is
    // installed via an (id)-cast. Unit tests run in Debug, so this MUST fire
    // an assertion when resolved.
    [self.container registerProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return (id)[MSIDDIContainerTestNonConformingService class]; }];

    XCTAssertThrows(([self.container
        resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                          orDefault:^Class {
                              return [MSIDDIContainerTestClassMethodService class];
                          }]));
}

- (void)testResolveImplClassForClass_whenRegisteredClassIsNotSubclass_shouldResolveWithoutThrow
{
    // resolveImplClassForClass: is intentionally duck-typed (see header) — no
    // subclass relationship is enforced. This test pins that contract: a
    // non-subclass resolves without throwing, so callers must still rely on
    // their own type knowledge / unrecognized-selector behavior.
    [self.container registerClass:[MSIDDIContainerTestClassMethodService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return (id)[MSIDDIContainerTestNonConformingService class]; }];

    Class resolved = [self.container
        resolveImplClassForClass:[MSIDDIContainerTestClassMethodService class]
                       orDefault:^Class { return [MSIDDIContainerTestClassMethodService class]; }];
    XCTAssertEqual(resolved, [MSIDDIContainerTestNonConformingService class]);
}

- (void)testResolveImplClassForProtocol_whenDefaultProviderUsed_shouldNotValidateAgainAfterFallback
{
    // Sanity: a properly-conforming default class flows through without
    // tripping the new validation. This pins that the validation is targeted
    // at the registered-factory path, not the unrelated default path.
    Class<MSIDDIContainerTestClassMethodProtocol> impl =
        (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
            resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                              orDefault:^Class {
                                  return [MSIDDIContainerTestClassMethodService class];
                              }];

    XCTAssertEqualObjects([impl greeting], @"hello-class");
}

#pragma mark - Concurrent registration + resolution stress test

- (void)testConcurrentRegistrationAndResolution_shouldNotCrashAndConverge
{
    // Race the public mutating API (registerProtocol:lifetime:factory:) against
    // resolveImplClassForProtocol:orDefault: across many iterations. The
    // container guards its mutable maps with a concurrent queue + barrier
    // writes; this test pins that no concurrent register/resolve pair can
    // crash or yield a torn class reference.
    NSInteger iterations = 100;

    dispatch_apply(iterations, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        if ((i % 2) == 0)
        {
            [self.container registerProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                                    lifetime:MSIDDIContainerLifetimeSingleton
                                     factory:^id { return (id)[MSIDDIContainerTestClassMethodMockService class]; }];
        }
        else
        {
            Class<MSIDDIContainerTestClassMethodProtocol> impl =
                (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
                    resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                                      orDefault:^Class {
                                          return [MSIDDIContainerTestClassMethodService class];
                                      }];
            // impl is either the registered mock or the default — both conform.
            NSString *greeting = [impl greeting];
            XCTAssertTrue([greeting isEqualToString:@"mocked-class"] || [greeting isEqualToString:@"hello-class"]);
        }
    });

    // Deterministic final state: register one last time, resolve, expect mock.
    [self.container registerProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return (id)[MSIDDIContainerTestClassMethodMockService class]; }];

    Class<MSIDDIContainerTestClassMethodProtocol> impl =
        (Class<MSIDDIContainerTestClassMethodProtocol>)[self.container
            resolveImplClassForProtocol:@protocol(MSIDDIContainerTestClassMethodProtocol)
                              orDefault:^Class { return [MSIDDIContainerTestClassMethodService class]; }];
    XCTAssertEqualObjects([impl greeting], @"mocked-class");
}

@end
