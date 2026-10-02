//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#if !MSID_EXCLUDE_WEBKIT

#import <XCTest/XCTest.h>
#import "MSIDAuthenticationStatusScriptMessageHandler.h"
#import "MSIDAuthenticationAvailabilityStatus.h"

@interface MSIDAuthenticationAvailabilityStatus (Testing)

- (instancetype)initWithBrokerAppAvailabilityProbe:(BOOL (^)(void))brokerAppAvailabilityProbe
                     ssoExtensionAvailabilityProbe:(BOOL (^)(void))ssoExtensionAvailabilityProbe;

@end

@interface MSIDAuthenticationStatusScriptMessageHandler (Testing)

- (instancetype)initWithStatusProvider:
    (MSIDAuthenticationAvailabilityStatus *(^)(void))statusProvider;

- (void)handleRequestFromURL:(NSURL *)requestURL
                 isMainFrame:(BOOL)isMainFrame
                replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler;

@end

@interface MSIDAuthenticationStatusScriptMessageHandlerTests : XCTestCase

@end

@implementation MSIDAuthenticationStatusScriptMessageHandlerTests

- (void)testInstall_whenCalledTwice_shouldInstallOneMainFrameScript
{
    WKUserContentController *contentController = [WKUserContentController new];

    [MSIDAuthenticationStatusScriptMessageHandler
        installInUserContentController:contentController];
    [MSIDAuthenticationStatusScriptMessageHandler
        installInUserContentController:contentController];

    XCTAssertEqual(contentController.userScripts.count, 1);
    WKUserScript *script = contentController.userScripts.firstObject;
    XCTAssertTrue([script.source containsString:@"window.identity.getAuthenticationStatus"]);
    XCTAssertEqual(script.injectionTime, WKUserScriptInjectionTimeAtDocumentStart);
    XCTAssertTrue(script.forMainFrameOnly);
}

- (void)testHandleRequest_whenSecureMainFrame_shouldReturnStatus
{
    MSIDAuthenticationStatusScriptMessageHandler *handler =
        [self handlerWithBrokerAvailable:YES ssoExtensionAvailable:NO];
    __block NSDictionary *result = nil;
    __block NSString *errorMessage = nil;

    [handler handleRequestFromURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]
                     isMainFrame:YES
                    replyHandler:^(id reply, NSString *error)
    {
        result = reply;
        errorMessage = error;
    }];

    XCTAssertNil(errorMessage);
    XCTAssertEqualObjects(result, (@{
        @"brokerAppAvailable" : @YES,
        @"ssoExtensionAvailable" : @NO
    }));
}

- (void)testHandleRequest_whenCalledFromSubframe_shouldRejectRequest
{
    MSIDAuthenticationStatusScriptMessageHandler *handler =
        [self handlerWithBrokerAvailable:YES ssoExtensionAvailable:YES];
    __block id result = nil;
    __block NSString *errorMessage = nil;

    [handler handleRequestFromURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]
                     isMainFrame:NO
                    replyHandler:^(id reply, NSString *error)
    {
        result = reply;
        errorMessage = error;
    }];

    XCTAssertNil(result);
    XCTAssertEqualObjects(
        errorMessage,
        @"Authentication status is available only to the main frame.");
}

- (void)testHandleRequest_whenOriginIsNotSecure_shouldRejectRequest
{
    MSIDAuthenticationStatusScriptMessageHandler *handler =
        [self handlerWithBrokerAvailable:YES ssoExtensionAvailable:YES];
    __block id result = nil;
    __block NSString *errorMessage = nil;

    [handler handleRequestFromURL:[NSURL URLWithString:@"http://login.microsoftonline.com"]
                     isMainFrame:YES
                    replyHandler:^(id reply, NSString *error)
    {
        result = reply;
        errorMessage = error;
    }];

    XCTAssertNil(result);
    XCTAssertEqualObjects(
        errorMessage,
        @"Authentication status requires a secure web origin.");
}

- (MSIDAuthenticationStatusScriptMessageHandler *)handlerWithBrokerAvailable:
    (BOOL)brokerAvailable
    ssoExtensionAvailable:(BOOL)ssoExtensionAvailable
{
    return [[MSIDAuthenticationStatusScriptMessageHandler alloc]
        initWithStatusProvider:^MSIDAuthenticationAvailabilityStatus *
        {
            return [[MSIDAuthenticationAvailabilityStatus alloc]
                initWithBrokerAppAvailabilityProbe:^BOOL
                {
                    return brokerAvailable;
                }
                ssoExtensionAvailabilityProbe:^BOOL
                {
                    return ssoExtensionAvailable;
                }];
        }];
}

@end

#endif
