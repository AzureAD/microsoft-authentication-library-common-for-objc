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
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:YES format:@"pii-message"];
    
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertTrue(testLogger.containsPII);
}

- (void)testLog_whenPiiEnabledNonPiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:NO format:@"non-pii-message"];
    
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabledNonPiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:NO format:@"non-pii-message"];
    
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabledPiiMessage_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = NO;
    [[MSIDLogger sharedLogger] logLevel:MSIDLogLevelError context:nil correlationId:nil isPII:YES format:@"pii-message"];
    
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    XCTAssertNil(testLogger.lastMessage);
}

#pragma mark - Log macros

- (void)testLogErrorMacro_shouldReturnMessageNoPIIErrorLevel
{
    MSID_LOG_ERROR(nil, nil, @"Error message! %d", 0);
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Error message! 0"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testLogWarningMacro_shouldReturnMessageNoPIIWarningLevel
{
    MSID_LOG_WARN(nil, nil, @"Oh no, a %@ thing happened!", @"bad");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"Oh no, a bad thing happened!"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelWarning);
}

- (void)testLogInfoMacro_shouldReturnMessageNoPIIInfoLevel
{
    MSID_LOG_INFO(nil, nil, @"This informative message has been seen %d times", 20);
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"This informative message has been seen 20 times"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelInfo);
}

- (void)testLogVerboseMacro_shouldReturnMessageNoPIIVerboseLevel
{
    MSID_LOG_VERBOSE(nil, nil, @"So much noise, this message is %@ useful", @"barely");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"So much noise, this message is barely useful"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

- (void)testLogErrorPiiMacro_shouldReturnMessagePIITrueErrorLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSID_LOG_ERROR_PII(nil, nil, @"userId: %@ failed to sign in", @"user@contoso.com");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"userId: user@contoso.com failed to sign in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testLogWarningPiiMacro_shouldReturnMessagePIITrueWarningLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSID_LOG_WARN_PII(nil, nil, @"%@ pressed the cancel button", @"user@contoso.com");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com pressed the cancel button"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelWarning);
}

- (void)testLogInfoPiiMacro_shouldReturnMessagePIITrueInfoLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSID_LOG_INFO_PII(nil, nil, @"%@ is trying to log in", @"user@contoso.com");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com is trying to log in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelInfo);
}

- (void)testLogVerbosePiiMacro_shouldReturnMessagePIITrueVerboseLevel
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = YES;
    MSID_LOG_VERBOSE_PII(nil, nil, @"waiting on response from %@", @"contoso.com");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

#pragma mark - Log level

- (void)testSetLogLevel_withLogLevelNothing_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelNothing;
    MSID_LOG_ERROR(nil, nil, @"test error message");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNil(logger.lastMessage);
}

- (void)testSetLogLevel_withLogErrorLoggingError_shouldInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    MSID_LOG_ERROR(nil, nil, @"test error message");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"test error message"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testSetLogLevel_withLogErrorLoggingVerbose_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    MSID_LOG_VERBOSE(nil, nil, @"test error message");
    
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    XCTAssertNil(logger.lastMessage);
}

@end
