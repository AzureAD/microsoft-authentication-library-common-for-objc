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
#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDSSOExtensionRequestDelegate.h"

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MSIDSSOExtensionRequestDelegateTests : XCTestCase

@end

@implementation MSIDSSOExtensionRequestDelegateTests

- (void)testAuthorizationControllerDidCompleteWithError_whenErrorIsSSOCancelled_shouldReturnUserCancelError
{
    MSIDSSOExtensionRequestDelegate *delegate = [MSIDSSOExtensionRequestDelegate new];
    
    ASAuthorizationController *controller = nil;
    NSError *testError = [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorCanceled userInfo:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion block expectation"];
    
    delegate.completionBlock = ^(id response, NSError *error)
    {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorUserCancel);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"SSO extension authorization was canceled");
        [expectation fulfill];
    };
    
    [delegate authorizationController:controller didCompleteWithError:testError];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 120000
- (void)testAuthorizationControllerDidCompleteWithError_whenErrorIsSSOUIRequired_shouldReturnSSOUIRequired
{
    if (@available(iOS 15.0, macOS 12.0, *))
    {
        MSIDSSOExtensionRequestDelegate *delegate = [MSIDSSOExtensionRequestDelegate new];
        
        ASAuthorizationController *controller = nil;
        NSError *testError = [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorNotInteractive userInfo:nil];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"Completion block expectation"];
        
        delegate.completionBlock = ^(id response, NSError *error)
        {
            XCTAssertNil(response);
            XCTAssertNotNil(error);
            XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
            XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
            XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"SSO extension authorization requires interaction");
            [expectation fulfill];
        };
        
        [delegate authorizationController:controller didCompleteWithError:testError];
        [self waitForExpectationsWithTimeout:1 handler:nil];
    }
}
#endif

- (void)testAuthorizationControllerDidCompleteWithError_whenErrorIsMSALError_shouldReturnUnderlyingError
{
    MSIDSSOExtensionRequestDelegate *delegate = [MSIDSSOExtensionRequestDelegate new];
    
    ASAuthorizationController *controller = nil;
    
    NSError *underlyingError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"Test underlying error", @"oauth error", @"oauth suberror", nil, nil, nil, NO);
    NSError *testError = [NSError errorWithDomain:ASAuthorizationErrorDomain code:MSIDSSOExtensionUnderlyingError userInfo:@{NSUnderlyingErrorKey:underlyingError}];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion block expectation"];
    
    delegate.completionBlock = ^(id response, NSError *error)
    {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInteractionRequired);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Test underlying error");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthErrorKey], @"oauth error");
        XCTAssertEqualObjects(error.userInfo[MSIDOAuthSubErrorKey], @"oauth suberror");
        [expectation fulfill];
    };
    
    [delegate authorizationController:controller didCompleteWithError:testError];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAuthorizationControllerDidCompleteWithError_whenErrorIsMSALError_butErrorMissing_shouldReturnCorruptedResponseError
{
    MSIDSSOExtensionRequestDelegate *delegate = [MSIDSSOExtensionRequestDelegate new];
    
    ASAuthorizationController *controller = nil;
    
    NSError *testError = [NSError errorWithDomain:ASAuthorizationErrorDomain code:MSIDSSOExtensionUnderlyingError userInfo:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion block expectation"];
    
    delegate.completionBlock = ^(id response, NSError *error)
    {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorBrokerCorruptedResponse);
        XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"SSO extension returned corrupted error. Please upload Microsoft Authenticator logs to investigate.");
        [expectation fulfill];
    };
    
    [delegate authorizationController:controller didCompleteWithError:testError];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAuthorizationControllerDidCompleteWithError_whenErrorIsSSOError_shouldReturnSSOError
{
    MSIDSSOExtensionRequestDelegate *delegate = [MSIDSSOExtensionRequestDelegate new];
    
    ASAuthorizationController *controller = nil;
    NSError *testError = [NSError errorWithDomain:ASAuthorizationErrorDomain code:ASAuthorizationErrorInvalidResponse userInfo:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion block expectation"];
    
    delegate.completionBlock = ^(id response, NSError *error)
    {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, ASAuthorizationErrorDomain);
        XCTAssertEqual(error.code, ASAuthorizationErrorInvalidResponse);
        XCTAssertNil(error.userInfo[MSIDErrorDescriptionKey]);
        [expectation fulfill];
    };
    
    [delegate authorizationController:controller didCompleteWithError:testError];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
