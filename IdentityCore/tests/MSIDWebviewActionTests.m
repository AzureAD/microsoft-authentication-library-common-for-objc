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
#import "MSIDWebviewAction.h"

@interface MSIDWebviewActionTests : XCTestCase

@end

@implementation MSIDWebviewActionTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Noop Action Tests

- (void)testNoopAction_shouldReturnCorrectType
{
    MSIDWebviewAction *action = [MSIDWebviewAction noopAction];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeNoop);
    XCTAssertNil(action.request);
    XCTAssertNil(action.url);
    XCTAssertNil(action.error);
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeUnknown);
}

#pragma mark - LoadRequest Action Tests

- (void)testLoadRequestAction_shouldReturnCorrectTypeAndRequest
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/enroll"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    MSIDWebviewAction *action = [MSIDWebviewAction loadRequestAction:request];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequestInWebview);
    XCTAssertEqualObjects(action.request, request);
    XCTAssertNil(action.url);
    XCTAssertNil(action.error);
}

#pragma mark - OpenASWebAuthSession Action Tests

- (void)testOpenASWebAuthSessionAction_withInstallProfilePurpose_shouldReturnCorrectTypeAndProperties
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/profile"];
    
    MSIDWebviewAction *action = [MSIDWebviewAction openASWebAuthSessionAction:url
                                                                      purpose:MSIDSystemWebviewPurposeInstallProfile];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertEqualObjects(action.url, url);
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeInstallProfile);
    XCTAssertNil(action.request);
    XCTAssertNil(action.error);
}

- (void)testOpenASWebAuthSessionAction_withUnknownPurpose_shouldReturnCorrectProperties
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/auth"];
    
    MSIDWebviewAction *action = [MSIDWebviewAction openASWebAuthSessionAction:url
                                                                      purpose:MSIDSystemWebviewPurposeUnknown];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertEqualObjects(action.url, url);
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeUnknown);
}

#pragma mark - OpenExternalBrowser Action Tests

- (void)testOpenExternalBrowserAction_shouldReturnCorrectTypeAndURL
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    
    MSIDWebviewAction *action = [MSIDWebviewAction openExternalBrowserAction:url];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenExternalBrowser);
    XCTAssertEqualObjects(action.url, url);
    XCTAssertNil(action.request);
    XCTAssertNil(action.error);
}

#pragma mark - CompleteWithURL Action Tests

- (void)testCompleteWithURLAction_shouldReturnCorrectTypeAndURL
{
    NSURL *url = [NSURL URLWithString:@"msauth://profileComplete"];
    
    MSIDWebviewAction *action = [MSIDWebviewAction completeWithURLAction:url];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL);
    XCTAssertEqualObjects(action.url, url);
    XCTAssertNil(action.request);
    XCTAssertNil(action.error);
}

#pragma mark - FailWithError Action Tests

- (void)testFailWithErrorAction_shouldReturnCorrectTypeAndError
{
    NSError *error = [NSError errorWithDomain:@"TestDomain"
                                         code:123
                                     userInfo:@{NSLocalizedDescriptionKey: @"Test error"}];
    
    MSIDWebviewAction *action = [MSIDWebviewAction failWithErrorAction:error];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeFailWithError);
    XCTAssertEqualObjects(action.error, error);
    XCTAssertNil(action.request);
    XCTAssertNil(action.url);
}

@end
