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
    if (self) _identifier = [[NSUUID UUID] UUIDString];
    return self;
}
- (NSString *)greeting { return @"hello"; }
@end

@interface MSIDDIContainerTestMockService : NSObject <MSIDDIContainerTestProtocol>
@end

@implementation MSIDDIContainerTestMockService
- (NSString *)greeting { return @"mocked"; }
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

- (void)testResolveClass_whenOverrideInstalled_shouldReturnOverrideOverFactory
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];

    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container setOverrideForClass:[MSIDDIContainerTestService class] instance:mock];

    id resolved = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertTrue(resolved == mock);
}

- (void)testResolveProtocol_whenOverrideInstalled_shouldReturnOverride
{
    [self.container registerProtocol:@protocol(MSIDDIContainerTestProtocol)
                            lifetime:MSIDDIContainerLifetimeSingleton
                             factory:^id { return [MSIDDIContainerTestService new]; }];

    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container setOverrideForProtocol:@protocol(MSIDDIContainerTestProtocol) instance:mock];

    id<MSIDDIContainerTestProtocol> resolved = [self.container resolveProtocol:@protocol(MSIDDIContainerTestProtocol)];

    XCTAssertEqualObjects([resolved greeting], @"mocked");
}

- (void)testResetAllOverrides_whenCalled_shouldRestoreFactoryBehavior
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];
    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container setOverrideForClass:[MSIDDIContainerTestService class] instance:mock];

    [self.container resetAllOverrides];
    id resolved = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertFalse(resolved == mock);
    XCTAssertTrue([resolved isKindOfClass:[MSIDDIContainerTestService class]]);
}

- (void)testRemoveOverrideForClass_whenCalled_shouldClearOnlyThatOverride
{
    [self.container registerClass:[MSIDDIContainerTestService class]
                         lifetime:MSIDDIContainerLifetimeSingleton
                          factory:^id { return [MSIDDIContainerTestService new]; }];
    MSIDDIContainerTestMockService *mock = [MSIDDIContainerTestMockService new];
    [self.container setOverrideForClass:[MSIDDIContainerTestService class] instance:mock];

    [self.container removeOverrideForClass:[MSIDDIContainerTestService class]];
    id resolved = [self.container resolveClass:[MSIDDIContainerTestService class]];

    XCTAssertTrue([resolved isKindOfClass:[MSIDDIContainerTestService class]]);
    XCTAssertFalse(resolved == mock);
}

- (void)testResolveClass_whenUnregisteredAndNoOverride_shouldThrow
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
    XCTAssertGreaterThanOrEqual(factoryInvocations, 1);
}

- (void)testSharedInstance_whenCalledTwice_shouldReturnSameContainer
{
    XCTAssertTrue([MSIDDIContainer sharedInstance] == [MSIDDIContainer sharedInstance]);
}

@end
