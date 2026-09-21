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
#if MSID_ENABLE_SSO_EXTENSION
#import "MSIDSSOTokenResponseHandler.h"
#import "MSIDTokenResult.h"
#import "MSIDOnboardingBlobFieldKeys.h"

@interface MSIDSSOTokenResponseHandler (Testing)

- (MSIDRequestCompletionBlock)wrapCompletionBlock:(MSIDRequestCompletionBlock)completionBlock
                               withOnboardingBlob:(NSString *)onboardingBlob;

@end

@interface MSIDSSOTokenResponseHandlerTests : XCTestCase

@end

@implementation MSIDSSOTokenResponseHandlerTests

- (void)testWrapCompletionBlock_whenResultReturned_shouldSetOnboardingBlobOnResult
{
    MSIDSSOTokenResponseHandler *handler = [MSIDSSOTokenResponseHandler new];
    MSIDTokenResult *expectedResult = [MSIDTokenResult new];
    NSString *onboardingBlob = @"{\"steps_list\":[{\"step_id\":\"MDMEnrollmentRequired\"}]}";
    __block MSIDTokenResult *actualResult = nil;
    __block NSError *actualError = nil;
    MSIDRequestCompletionBlock completionBlock = ^(MSIDTokenResult *result, NSError *error)
    {
        actualResult = result;
        actualError = error;
    };

    MSIDRequestCompletionBlock wrappedCompletion = [handler wrapCompletionBlock:completionBlock
                                                             withOnboardingBlob:onboardingBlob];
    wrappedCompletion(expectedResult, nil);

    XCTAssertEqual(actualResult, expectedResult);
    XCTAssertEqualObjects(actualResult.onboardingBlob, onboardingBlob);
    XCTAssertNil(actualError);
}

- (void)testWrapCompletionBlock_whenErrorReturned_shouldSetOnboardingBlobOnErrorUserInfo
{
    MSIDSSOTokenResponseHandler *handler = [MSIDSSOTokenResponseHandler new];
    NSString *onboardingBlob = @"{\"steps_list\":[{\"step_id\":\"MDMEnrollmentRequired\"}]}";
    NSError *expectedError = [NSError errorWithDomain:@"MSIDTestErrorDomain"
                                                 code:123
                                             userInfo:@{@"existing_key" : @"existing_value"}];
    __block MSIDTokenResult *actualResult = nil;
    __block NSError *actualError = nil;
    MSIDRequestCompletionBlock completionBlock = ^(MSIDTokenResult *result, NSError *error)
    {
        actualResult = result;
        actualError = error;
    };

    MSIDRequestCompletionBlock wrappedCompletion = [handler wrapCompletionBlock:completionBlock
                                                             withOnboardingBlob:onboardingBlob];
    wrappedCompletion(nil, expectedError);

    XCTAssertNil(actualResult);
    XCTAssertEqualObjects(actualError.domain, expectedError.domain);
    XCTAssertEqual(actualError.code, expectedError.code);
    XCTAssertEqualObjects(actualError.userInfo[@"existing_key"], @"existing_value");
    XCTAssertEqualObjects(actualError.userInfo[MSIDOnboardingBlobIPCKey], onboardingBlob);
}

@end

#endif
