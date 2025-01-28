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
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDWebResponseBaseOperation.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDAADWebviewFactory.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDWebOpenBrowserResponseOperation.h"

@interface MSIDWebResponseOperationFactoryTests : XCTestCase

@end

@implementation MSIDWebResponseOperationFactoryTests

- (void)test_openBroswerResponse_should_return_openBroserOperation
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type webResponse = [factory oAuthResponseWithURL:[NSURL URLWithString:@"browser://somehost"]
                                               requestState:nil
                                         ignoreInvalidState:NO
                                                    context:nil
                                                      error:nil];
    
    XCTAssertNotNil(webResponse);
    XCTAssertNil(error);
    MSIDWebResponseBaseOperation *operation = [MSIDWebResponseOperationFactory createOperationForResponse:webResponse
                                                                                                    error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(operation);
    XCTAssertTrue([operation isKindOfClass:MSIDWebOpenBrowserResponseOperation.class]);
    [MSIDWebResponseOperationFactory unRegisterforResponse:webResponse];
}

@end
