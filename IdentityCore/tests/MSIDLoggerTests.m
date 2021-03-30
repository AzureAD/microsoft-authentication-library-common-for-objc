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
#import "MSIDLoggerConnecting.h"

@interface MSIDLoggerConnectorMock : NSObject <MSIDLoggerConnecting>

@property (nonatomic) MSIDLogLevel levelValue;
@property (nonatomic) BOOL nsLoggingEnabledValue;
@property (nonatomic) BOOL piiLoggingEnabledValue;
@property (nonatomic) MSIDLogMaskingLevel logMaskingLevelValue;
@property (nonatomic) BOOL shouldLogValue;
@property (nonatomic) BOOL sourceLineLoggingEnabledValue;
@property (nonatomic) BOOL loggingQueueEnabledValue;
@property (nonatomic) NSString *logMessageValue;

@end

@implementation MSIDLoggerConnectorMock

- (MSIDLogLevel)level
{
    return self.levelValue;
}

- (BOOL)nsLoggingEnabled
{
    return self.nsLoggingEnabledValue;
}

- (void)onLogWithLevel:(__unused MSIDLogLevel)level lineNumber:(__unused NSUInteger)lineNumber function:(__unused NSString *)function message:(NSString *)message
{
    self.logMessageValue = message;
}

- (BOOL)piiLoggingEnabled
{
    return self.piiLoggingEnabledValue;
}

- (BOOL)shouldLog:(__unused MSIDLogLevel)level
{
    return self.shouldLogValue;
}

- (BOOL)sourceLineLoggingEnabled
{
    return self.sourceLineLoggingEnabledValue;
}

- (BOOL)loggingQueueEnabled
{
    return self.loggingQueueEnabledValue;
}

- (MSIDLogMaskingLevel)logMaskingLevel
{
    return self.logMaskingLevelValue;
}

@end

@interface MSIDLoggerTests : XCTestCase

@end

@implementation MSIDLoggerTests

- (void)setUp
{
    [super setUp];
    [[MSIDTestLogger sharedLogger] reset];
    [MSIDTestLogger sharedLogger].callbackInvoked = NO;
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
}

#pragma mark - Basic logging

- (void)testLog_whenLogLevelNothingMessageValid_shouldNotThrow
{
    [self keyValueObservingExpectationForObject:[MSIDTestLogger sharedLogger] keyPath:@"callbackInvoked" expectedValue:@1];
    XCTAssertNoThrow([[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelNothing context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"Message"]);
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil([MSIDTestLogger sharedLogger].lastMessage);
}

- (void)testLog_whenLogLevelErrorMessageNil_shouldNotThrow
{
    XCTAssertNoThrow([[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:nil]);
}

#pragma mark - PII flag

- (void)testLog_whenPiiEnabled_maskEUIINo_PiiMessage_shouldReturnMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:YES filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertTrue(testLogger.containsPII);
}

- (void)testLog_whenPiiEnabled_maskEUIIYes_PiiMessage_shouldReturnedMaskedMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskEUIIOnly;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:YES filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"%@", MSID_PII_LOG_EMAIL(@"upn@test.com")];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@" auth.placeholder-8c09101e__test.com"]);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertTrue(testLogger.containsPII);
}

- (void)testLog_whenPiiEnabled_maskEUIINo_NonPiiMessage_shouldReturnSameMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@" non-pii-message"]);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiEnabled_maskEUIIYes_NonPiiMessage_shouldReturnSameMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskEUIIOnly;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@" non-pii-message"]);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabled_maskEUIINo_NonPiiMessage_shouldReturnSameMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@" non-pii-message"]);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabled_maskEUIIYes_NonPiiMessage_shouldReturnSameMessageInCallback
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskEUIIOnly;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"non-pii-message"];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@" non-pii-message"]);
    XCTAssertEqual(testLogger.lastLevel, MSIDLogLevelError);
    XCTAssertFalse(testLogger.containsPII);
}

- (void)testLog_whenPiiNotEnabled_maskEUIINo_PiiMessage_shouldInvokeCallbackWithMaskedMessage
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:YES filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"pii-message %@", MSID_PII_LOG_MASKABLE(@"test")];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@"pii-message Masked(not-null)"]);
}

- (void)testLog_whenPiiNotEnabled_maskEUIIYes_PiiMessage_shouldInvokeCallbackWithMaskedMessage
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDTestLogger *testLogger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:testLogger keyPath:@"callbackInvoked" expectedValue:@1];
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:YES filename:@__FILE__ lineNumber:__LINE__ function:@(__func__) format:@"pii-message %@", MSID_PII_LOG_EMAIL(@"upn@test.com")];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(testLogger.lastMessage);
    XCTAssertTrue([testLogger.lastMessage containsString:@"pii-message auth.placeholder-8c09101e__test.com"]);
}

#pragma mark - Log macros

- (void)testLogErrorMacro_shouldReturnMessageNoPIIErrorLevel
{
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Error message! %d", 0);
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
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Oh no, a %@ thing happened!", @"bad");
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
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"This informative message has been seen %d times", 20);
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
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,nil, @"So much noise, this message is %@ useful", @"barely");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"So much noise, this message is barely useful"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

- (void)testLogErrorPiiMacro_shouldReturnMessagePIITrueErrorLevel
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"userId: %@ failed to sign in", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"userId: user@contoso.com failed to sign in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelError);
}

- (void)testLogWarningPiiMacro_shouldReturnMessagePIITrueWarningLevel
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"%@ pressed the cancel button", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com pressed the cancel button"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelWarning);
}

- (void)testLogInfoPiiMacro_shouldReturnMessagePIITrueInfoLevel
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"%@ is trying to log in", @"user@contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"user@contoso.com is trying to log in"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelInfo);
}

- (void)testLogVerbosePiiMacro_shouldReturnMessagePIITrueVerboseLevel
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"waiting on response from %@", @"contoso.com");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"waiting on response from contoso.com"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

- (void)testLogWithContextMacro_whenContainsPii_andPiiDisabled_shouldLogMessageWithMaskedPii
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"My pii message %@, pii param %@", @"arg1", MSID_PII_LOG_MASKABLE(@"very sensitive data"));
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertFalse(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"My pii message arg1, pii param Masked(not-null)"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

- (void)testLogWithContextMacro_whenContainsPii_andPiiEnabled_shouldLogMessageWithRawPii
{
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskSecretsOnly;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"My pii message %@, pii param %@", @"arg1", MSID_PII_LOG_MASKABLE(@"very sensitive data"));
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(logger.lastMessage);
    XCTAssertTrue(logger.containsPII);
    XCTAssertTrue([logger.lastMessage containsString:@"My pii message arg1, pii param very sensitive data"]);
    XCTAssertEqual(logger.lastLevel, MSIDLogLevelVerbose);
}

#pragma mark - Log level

- (void)testSetLogLevel_withLogLevelNothing_shouldNotInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelNothing;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    __auto_type expectation = [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    [expectation setInverted:YES];
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"test error message");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(logger.lastMessage);
}

- (void)testSetLogLevel_withLogErrorLoggingError_shouldInvokeCallback
{
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    MSIDTestLogger *logger = [MSIDTestLogger sharedLogger];
    
    [self keyValueObservingExpectationForObject:logger keyPath:@"callbackInvoked" expectedValue:@1];
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"test error message");
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
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,nil, @"test error message");
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(logger.lastMessage);
}

#pragma mark - Logger Connector

- (void)testLogLevel_whenConnectorIsSet_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.levelValue = MSIDLogLevelWarning;
    [MSIDLogger sharedLogger].level = MSIDLogLevelError;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    
    XCTAssertEqual([MSIDLogger sharedLogger].level, MSIDLogLevelWarning);
}

- (void)testNsLoggingEnabled_whenConnectorIsSet_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.nsLoggingEnabledValue = YES;
    [MSIDLogger sharedLogger].nsLoggingEnabled = NO;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    
    XCTAssertTrue([MSIDLogger sharedLogger].nsLoggingEnabled);
}

- (void)testPiiLoggingEnabled_whenConnectorIsSet_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.piiLoggingEnabledValue = YES;
    [MSIDLogger sharedLogger].logMaskingLevel = MSIDLogMaskingSettingsMaskAllPII;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    XCTAssertEqual([MSIDLogger sharedLogger].logMaskingLevel, MSIDLogMaskingSettingsMaskAllPII);
}

- (void)testSourceLineLoggingEnabled_whenConnectorIsSet_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.sourceLineLoggingEnabledValue = YES;
    [MSIDLogger sharedLogger].sourceLineLoggingEnabled = NO;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    
    XCTAssertTrue([MSIDLogger sharedLogger].sourceLineLoggingEnabled);
}

- (void)testLogWithLevel_whenConnectorIsSetAndLogQueueEnabled_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.shouldLogValue = YES;
    connectorMock.loggingQueueEnabledValue = YES;
    [MSIDLogger sharedLogger].level = MSIDLogLevelNothing;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    [self keyValueObservingExpectationForObject:connectorMock keyPath:@"logMessageValue" handler:^BOOL(id observedObject, __unused NSDictionary *change)
    {
        return [((MSIDLoggerConnectorMock *)observedObject).logMessageValue containsString:@"some message"];
    }];
    
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:nil lineNumber:1 function:nil format:@"some message"];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testLogWithLevel_whenConnectorIsSetAndLogQueueDisabled_shouldReturnValueFromConnector
{
    MSIDLoggerConnectorMock *connectorMock = [MSIDLoggerConnectorMock new];
    connectorMock.shouldLogValue = YES;
    connectorMock.loggingQueueEnabledValue = NO;
    [MSIDLogger sharedLogger].level = MSIDLogLevelNothing;
    [MSIDLogger sharedLogger].loggerConnector = connectorMock;
    [self keyValueObservingExpectationForObject:connectorMock keyPath:@"logMessageValue" handler:^BOOL(id observedObject, __unused NSDictionary *change)
    {
        return [((MSIDLoggerConnectorMock *)observedObject).logMessageValue containsString:@"some message"];
    }];
    
    [[MSIDLogger sharedLogger] logWithLevel:MSIDLogLevelError context:nil correlationId:nil containsPII:NO filename:nil lineNumber:1 function:nil format:@"some message"];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}
@end
