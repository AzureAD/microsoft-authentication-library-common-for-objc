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
#import "MSIDLastRequestTelemetry+Tests.h"
#import "MSIDAADTokenRequestServerTelemetry.h"
#import "MSIDTestSwizzle.h"
#import "MSIDTestContext.h"

@interface MSIDAADTokenRequestServerTelemetryTests : XCTestCase

@property (nonatomic) MSIDTestContext *context;

@end

@implementation MSIDAADTokenRequestServerTelemetryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [MSIDTestSwizzle reset];
    __auto_type context = [MSIDTestContext new];
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    self.context = context;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [MSIDTestSwizzle reset];
}

- (void)test_whenNoError_passIn_handleErrorWithContext_shouldResetTelemetry
{
    MSIDAADTokenRequestServerTelemetry *telemetry = [MSIDAADTokenRequestServerTelemetry new];
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetry setValue:telemetryObject forKey:@"lastRequestTelemetry"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"resetTelemetry triggerred"];
    [MSIDTestSwizzle instanceMethod:@selector(resetTelemetry)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        [expectation fulfill];

     }];
    
    [MSIDTestSwizzle instanceMethod:@selector(addErrorInfo:)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        XCTFail(@"addErrorInfo should not be triggerred");
     }];
    
    [telemetry handleError:nil context:self.context];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_whenError_passIn_handleErrorWithContext_shouldAddErrorInfo
{
    MSIDAADTokenRequestServerTelemetry *telemetry = [MSIDAADTokenRequestServerTelemetry new];
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetry setValue:telemetryObject forKey:@"lastRequestTelemetry"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"addErrorInfo triggerred"];
    [MSIDTestSwizzle instanceMethod:@selector(resetTelemetry)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        XCTFail(@"resetTelemetry should not be triggerred");
     }];
    
    [MSIDTestSwizzle instanceMethod:@selector(addErrorInfo:)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    [telemetry handleError:[NSError new] context:self.context];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_whenNoError_passIn_handleErrorWithMessageAndContext_shouldAddErrorInfo
{
    MSIDAADTokenRequestServerTelemetry *telemetry = [MSIDAADTokenRequestServerTelemetry new];
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetry setValue:telemetryObject forKey:@"lastRequestTelemetry"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"resetTelemetry triggerred"];
    [MSIDTestSwizzle instanceMethod:@selector(resetTelemetry)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        XCTFail(@"resetTelemetry should not be triggerred");
     }];
    
    [MSIDTestSwizzle instanceMethod:@selector(addErrorInfo:)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    [telemetry handleError:nil errorString:@"error string" context:self.context];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_whenError_passIn_handleErrorWithMessageAndContext_shouldAddErrorInfo
{
    MSIDAADTokenRequestServerTelemetry *telemetry = [MSIDAADTokenRequestServerTelemetry new];
    MSIDLastRequestTelemetry *telemetryObject = [MSIDLastRequestTelemetry sharedInstance];
    [telemetry setValue:telemetryObject forKey:@"lastRequestTelemetry"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"resetTelemetry triggerred"];
    [MSIDTestSwizzle instanceMethod:@selector(resetTelemetry)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        XCTFail(@"resetTelemetry should not be triggerred");
     }];
    
    [MSIDTestSwizzle instanceMethod:@selector(addErrorInfo:)
                              class:[MSIDLastRequestTelemetry class]
                              block:(id)^(void)
     {
        [expectation fulfill];
     }];
    
    [telemetry handleError:[NSError new] errorString:@"error string" context:self.context];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
