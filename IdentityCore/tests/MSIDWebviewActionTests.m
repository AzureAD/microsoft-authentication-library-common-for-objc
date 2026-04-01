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

- (void)testCancelAction_shouldHaveCorrectType
{
    MSIDWebviewAction *action = [MSIDWebviewAction cancelAction];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.actionType, MSIDWebviewActionTypeCancel);
    XCTAssertNil(action.request);
    XCTAssertNil(action.additionalHeaders);
    XCTAssertNil(action.completeURL);
}

- (void)testContinueAction_shouldHaveCorrectType
{
    MSIDWebviewAction *action = [MSIDWebviewAction continueAction];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.actionType, MSIDWebviewActionTypeContinue);
    XCTAssertNil(action.request);
    XCTAssertNil(action.additionalHeaders);
    XCTAssertNil(action.completeURL);
}

- (void)testLoadRequestAction_withRequest_shouldHaveCorrectProperties
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    MSIDWebviewAction *action = [MSIDWebviewAction loadRequestAction:request];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.actionType, MSIDWebviewActionTypeLoadRequest);
    XCTAssertEqualObjects(action.request, request);
    XCTAssertNil(action.additionalHeaders);
    XCTAssertNil(action.completeURL);
}

- (void)testLoadRequestAction_withRequestAndHeaders_shouldHaveCorrectProperties
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSDictionary *headers = @{@"X-Custom-Header": @"value"};
    
    MSIDWebviewAction *action = [MSIDWebviewAction loadRequestAction:request additionalHeaders:headers];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.actionType, MSIDWebviewActionTypeLoadRequest);
    XCTAssertEqualObjects(action.request, request);
    XCTAssertEqualObjects(action.additionalHeaders, headers);
    XCTAssertNil(action.completeURL);
}

- (void)testCompleteAction_withURL_shouldHaveCorrectProperties
{
    NSURL *url = [NSURL URLWithString:@"msauth://enroll?code=abc"];
    
    MSIDWebviewAction *action = [MSIDWebviewAction completeAction:url];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.actionType, MSIDWebviewActionTypeComplete);
    XCTAssertEqualObjects(action.completeURL, url);
    XCTAssertNil(action.request);
    XCTAssertNil(action.additionalHeaders);
}

@end
