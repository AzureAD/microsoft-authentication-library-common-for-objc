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
#import "MSIDTestLogger.h"
#import "MSIDLogger+Internal.h"

@interface MSIDLoggerTests : XCTestCase

@end

@implementation MSIDLoggerTests

- (void)setUp
{
    [super setUp];
    [[MSIDTestLogger sharedLogger] reset];
    [MSIDTestLogger sharedLogger].callbackInvoked = NO;
}

#pragma mark - Basic logging

- (void)testLog_whenLogLevelNothingMessageValid_shouldNotThrow
{
    XCTAssertNoThrow([[MSIDLogger sharedLogger] logLevel:MSIDLogLevelNothing context:nil correlationId:nil isPII:NO format:@"Message"]);
}

- (void)testLog_whenLogLevelErrorMessageNil_shouldNotThrow
{
    XCTAssertNoThrow([[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:NO format:nil]);
}

#pragma mark - PII flag

- (void)testLog_whenPiiEnabledPiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:YES format:@"pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertTrue(testLogger.containsPII);
}

- (void)testLog_whenPiiEnabledNonPiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:NO format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabledNonPiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:NO format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabledPiiMessage_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    __auto_type expectation = [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [expectation setInverted:YES];
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:YES format:@"pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(testLogger.lastMessage);
}

#pragma mark - Log macros

- (void)testLogErrorMacro_shouldReturnMessageNoPIIErrorLevel
{
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_ERROR(nil, @"Error message! %d", 0);
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Error message! 0"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testLogWarningMacro_shouldReturnMessageNoPIIWarningLevel
{
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WARN(nil, @"Oh no, a %@ thing happened!", @"bad");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Oh no, a bad thing happened!"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelWarning);
}

- (void)testLogInfoMacro_shouldReturnMessageNoPIIInfoLevel
{
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_INFO(nil, @"This informative message has been seen %d times", 20);
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"This informative message has been seen 20 times"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelInfo);
}

- (void)testLogVerboseMacro_shouldReturnMessageNoPIIVerboseLevel
{
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_VERBOSE(nil, @"So much noise, this message is %@ useful", @"barely");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"So much noise, this message is barely useful"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

- (void)testLogErrorPiiMacro_shouldReturnMessagePIITrueErrorLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_ERROR_PII(nil, @"userId: %@ failed to sign in", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"userId: user@contoso.com failed to sign in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testLogWarningPiiMacro_shouldReturnMessagePIITrueWarningLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WARN_PII(nil, @"%@ pressed the cancel button", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com pressed the cancel button"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelWarning);
}

- (void)testLogInfoPiiMacro_shouldReturnMessagePIITrueInfoLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_INFO_PII(nil, @"%@ is trying to log in", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com is trying to log in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelInfo);
}

- (void)testLogVerbosePiiMacro_shouldReturnMessagePIITrueVerboseLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_VERBOSE_PII(nil, @"waiting on response from %@", @"contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

#pragma mark - Log level

- (void)testSetLogLevel_withLogLevelNothing_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelNothing;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    __auto_type expectation = [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    [expectation setInverted:YES];
    MSID_LOG_ERROR(nil, @"test error message");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(logger.lastMessage);
}

- (void)testSetLogLevel_withLogErrorLoggingError_shouldInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_ERROR(nil, @"test error message");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"test error message"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testSetLogLevel_withLogErrorLoggingVerbose_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    __auto_type expectation = [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    [expectation setInverted:YES];
    MSID_LOG_VERBOSE(nil, @"test error message");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(logger.lastMessage);
}

- (void)testMaskedString_whenStringContainsAuthroizationCodeValue_shouldMaskIt
{
    __auto_type string = @"testapp://com.test.app/?code=qwertyuiopasdfghjklzxcvbnm&session_state=1234567890&x-client-Ver=2.6.4";
    
    __auto_type maskedString = [[MSIDLogger sharedLogger] maskedString:string];
    
    __auto_type expectedString = @"testapp://com.test.app/?code=<masked authorization code>&session_state=1234567890&x-client-Ver=2.6.4";
    XCTAssertEqualObjects(maskedString, expectedString);
}

- (void)testMaskedString_whenStringContainsTwoAuthroizationCodeValues_shouldMaskThem
{
    __auto_type string = @"testapp://com.test.app/?code=qwertyuiopasdfghjklzxcvbnm&session_state=1234567890&x-client-Ver=2.6.4, NSErrorFailingURLKey=testapp://com.test.app/?code=qwertyuiopasdfghjklzxcvbnm&session_state=78b666ea-757f-4afe-b945-6eb301b16fba&x-client-Ver=2.6.4";
    
    __auto_type maskedString = [[MSIDLogger sharedLogger] maskedString:string];
    
    __auto_type expectedString = @"testapp://com.test.app/?code=<masked authorization code>&session_state=1234567890&x-client-Ver=2.6.4, NSErrorFailingURLKey=testapp://com.test.app/?code=<masked authorization code>&session_state=78b666ea-757f-4afe-b945-6eb301b16fba&x-client-Ver=2.6.4";
    XCTAssertEqualObjects(maskedString, expectedString);
 }

- (void)testMaskedString_whenStringDoesntContainAuthroizationCodeValues_shouldReturnOriginalString
{
    __auto_type string = @"testapp://com.test.app/?session_state=1234567890&x-client-Ver=2.6.4, NSErrorFailingURLKey=testapp://com.test.app/?session_state=78b666ea-757f-4afe-b945-6eb301b16fba&x-client-Ver=2.6.4";
    
    __auto_type maskedString = [[MSIDLogger sharedLogger] maskedString:string];
    
    XCTAssertEqualObjects(maskedString, string);
}

@end
