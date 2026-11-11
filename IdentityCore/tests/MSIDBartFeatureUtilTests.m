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

#import <XCTest/XCTest.h>
#import "MSIDBartFeatureUtil.h"

static NSString *const MSIDBartLegacyDefaultsKey = @"com.microsoft.msid.bart_feature_enabled";
static void *MSIDBartDefaultsObservationContext = &MSIDBartDefaultsObservationContext;

@interface MSIDBartFeatureUtilTests : XCTestCase

@property (nonatomic, strong) id originalDefaultsValue;
@property (nonatomic) BOOL originalBartEnabled;
@property (nonatomic) BOOL observingDefaults;
@property (atomic) BOOL defaultsChanged;

@end

@implementation MSIDBartFeatureUtilTests

- (void)setUp
{
    [super setUp];
    self.originalDefaultsValue = [[NSUserDefaults standardUserDefaults] objectForKey:MSIDBartLegacyDefaultsKey];
    self.originalBartEnabled = [[MSIDBartFeatureUtil sharedInstance] isBartFeatureEnabled];
    self.defaultsChanged = NO;
}

- (void)tearDown
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.observingDefaults)
    {
        [defaults removeObserver:self forKeyPath:MSIDBartLegacyDefaultsKey context:MSIDBartDefaultsObservationContext];
        self.observingDefaults = NO;
    }

    if (self.originalDefaultsValue)
    {
        [defaults setObject:self.originalDefaultsValue forKey:MSIDBartLegacyDefaultsKey];
    }
    else
    {
        [defaults removeObjectForKey:MSIDBartLegacyDefaultsKey];
    }

    [[MSIDBartFeatureUtil sharedInstance] setBartSupportInAppCache:self.originalBartEnabled];
    [super tearDown];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                      context:(void *)context
{
    if (context == MSIDBartDefaultsObservationContext)
    {
        self.defaultsChanged = YES;
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)testIsBartFeatureEnabled_whenPersistedFlagIsEnabled_shouldStartDisabled
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MSIDBartLegacyDefaultsKey];

    MSIDBartFeatureUtil *feature = [MSIDBartFeatureUtil new];
    XCTAssertFalse([feature isBartFeatureEnabled]);
}

- (void)testSetBartSupportInAppCache_whenReconfigured_shouldUseCurrentApplicationValue
{
    MSIDBartFeatureUtil *feature = [MSIDBartFeatureUtil sharedInstance];
    MSIDBartFeatureUtil *otherClient = [MSIDBartFeatureUtil sharedInstance];

    [feature setBartSupportInAppCache:YES];
    [feature setBartSupportInAppCache:YES];
#if TARGET_OS_IPHONE
    XCTAssertTrue([otherClient isBartFeatureEnabled]);
#else
    XCTAssertFalse([otherClient isBartFeatureEnabled]);
#endif

    [otherClient setBartSupportInAppCache:NO];
    [otherClient setBartSupportInAppCache:NO];
    XCTAssertFalse([feature isBartFeatureEnabled]);
}

- (void)testSetBartSupportInAppCache_whenLegacyDefaultsExist_shouldNeitherUseNorModifyThem
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    MSIDBartFeatureUtil *feature = [MSIDBartFeatureUtil sharedInstance];

    [defaults removeObjectForKey:MSIDBartLegacyDefaultsKey];
    [feature setBartSupportInAppCache:YES];
    XCTAssertNil([defaults objectForKey:MSIDBartLegacyDefaultsKey]);

    [defaults setBool:YES forKey:MSIDBartLegacyDefaultsKey];
    [feature setBartSupportInAppCache:NO];
    XCTAssertFalse([feature isBartFeatureEnabled]);
    XCTAssertTrue([defaults boolForKey:MSIDBartLegacyDefaultsKey]);

    [defaults setBool:NO forKey:MSIDBartLegacyDefaultsKey];
    [feature setBartSupportInAppCache:YES];
#if TARGET_OS_IPHONE
    XCTAssertTrue([feature isBartFeatureEnabled]);
#else
    XCTAssertFalse([feature isBartFeatureEnabled]);
#endif
    XCTAssertFalse([defaults boolForKey:MSIDBartLegacyDefaultsKey]);
}

- (void)testSetBartSupportInAppCache_whenMainThreadIsWaiting_shouldCompleteWithoutNotifyingDefaultsObservers
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:MSIDBartLegacyDefaultsKey];
    [defaults addObserver:self
              forKeyPath:MSIDBartLegacyDefaultsKey
                 options:0
                 context:MSIDBartDefaultsObservationContext];
    self.observingDefaults = YES;

    MSIDBartFeatureUtil *feature = [MSIDBartFeatureUtil new];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [feature setBartSupportInAppCache:YES];
        [feature isBartFeatureEnabled];
        [feature setBartSupportInAppCache:NO];
        [feature isBartFeatureEnabled];
    });

    // Keep the wait bounded so a main-queue dependency fails instead of hanging the test runner.
    long result = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    XCTAssertEqual(result, 0);
    XCTAssertFalse(self.defaultsChanged);
}

- (void)testSetBartSupportInAppCache_whenAccessedConcurrently_shouldAllowSubsequentDisablement
{
    MSIDBartFeatureUtil *feature = [MSIDBartFeatureUtil new];
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger worker = 0; worker < 8; worker++)
    {
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            for (NSUInteger iteration = 0; iteration < 1000; iteration++)
            {
                [feature setBartSupportInAppCache:(iteration + worker) % 2 != 0];
                [feature isBartFeatureEnabled];
            }
        });
    }

    long result = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    XCTAssertEqual(result, 0);
    [feature setBartSupportInAppCache:NO];
    XCTAssertFalse([feature isBartFeatureEnabled]);
}

@end
