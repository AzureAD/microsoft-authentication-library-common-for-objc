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
#import "MSIDError.h"
#import "MSIDErrorConverting.h"
#import "MSIDErrorConverter.h"

@interface MSIDTestErrorConverter : NSObject <MSIDErrorConverting>

@end

@implementation MSIDTestErrorConverter

- (nullable NSError *)errorWithDomain:(nonnull NSString *)domain
                                 code:(NSInteger)code
                     errorDescription:(nullable NSString *)errorDescription
                           oauthError:(nullable NSString *)oauthError
                             subError:(nullable NSString *)subError
                      underlyingError:(nullable NSError *)underlyingError
                        correlationId:(nullable NSUUID *)correlationId
                             userInfo:(nullable NSDictionary *)userInfo
{
    NSString *newDomain = [NSString stringWithFormat:@"custom_%@", domain];
    NSInteger errorCode = 1000 + code;

    NSMutableDictionary *customUserInfo = [userInfo mutableCopy];
    customUserInfo[@"custom_description"] = errorDescription;
    customUserInfo[self.oauthErrorKey] = oauthError;
    customUserInfo[self.subErrorKey] = subError;
    customUserInfo[@"custom_underlyingerror"] = underlyingError;
    customUserInfo[@"custom_correlationid"] = [correlationId UUIDString];

    NSError *resultError = [NSError errorWithDomain:newDomain code:errorCode userInfo:customUserInfo];
    return resultError;
}

- (NSString *)oauthErrorKey
{
    return @"custom_oautherror";
}

- (nonnull NSString *)subErrorKey
{
    return @"custom_suberror";
}

@end

@interface MSIDErrorTests : XCTestCase

@end

@implementation MSIDErrorTests

- (void)tearDown
{
    // Use default error converter in case another test set a different one
    MSIDErrorConverter.errorConverter = nil;
    [super tearDown];
}

- (void)testMSIDCreateError_withAllParametersAndNoAdditionalUserInfo_withDefaultErrorConverter_shouldReturnErrorWithUserInfo
{
    NSError *underlyingError = [NSError errorWithDomain:@"UnderlyingDomain" code:-5556 userInfo:@{@"underlying": @"error"}];
    NSUUID *correlationId = [NSUUID UUID];
    NSError *result = MSIDCreateError(@"TestDomain", -5555, @"Test description", @"oauth_error", @"suberror", underlyingError, correlationId, nil);

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.domain, @"TestDomain");
    XCTAssertEqual(result.code, -5555);
    XCTAssertEqualObjects(result.userInfo[MSIDErrorDescriptionKey], @"Test description");
    XCTAssertEqualObjects(result.userInfo[MSIDOAuthErrorKey], @"oauth_error");
    XCTAssertEqualObjects(result.userInfo[MSIDOAuthSubErrorKey], @"suberror");
    XCTAssertEqualObjects(result.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(result.userInfo[MSIDCorrelationIdKey], [correlationId UUIDString]);
}

- (void)testMSIDCreateError_withAllParametersAndAdditionalUserInfo_withDefaultErrorConverter_shouldReturnErrorWithUserInfo
{
    NSError *underlyingError = [NSError errorWithDomain:@"UnderlyingDomain" code:-5556 userInfo:@{@"underlying": @"error"}];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *additionalUserInfo = @{@"userinfo": @"userinfo2", @"additional2": @"additional3"};
    NSError *result = MSIDCreateError(@"TestDomain", -5555, @"Test description", @"oauth_error", @"suberror", underlyingError, correlationId, additionalUserInfo);

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.domain, @"TestDomain");
    XCTAssertEqual(result.code, -5555);
    XCTAssertEqualObjects(result.userInfo[MSIDErrorDescriptionKey], @"Test description");
    XCTAssertEqualObjects(result.userInfo[MSIDOAuthErrorKey], @"oauth_error");
    XCTAssertEqualObjects(result.userInfo[MSIDOAuthSubErrorKey], @"suberror");
    XCTAssertEqualObjects(result.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(result.userInfo[MSIDCorrelationIdKey], [correlationId UUIDString]);
    XCTAssertEqualObjects(result.userInfo[@"userinfo"], @"userinfo2");
    XCTAssertEqualObjects(result.userInfo[@"additional2"], @"additional3");
}

- (void)testMSIDCreateError_withAllParametersAndAdditionalUserInfo_withCustomErrorConverter_shouldReturnCustomErrorWithUserInfo
{
    MSIDErrorConverter.errorConverter = [MSIDTestErrorConverter new];

    NSError *underlyingError = [NSError errorWithDomain:@"UnderlyingDomain" code:-5556 userInfo:@{@"underlying": @"error"}];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *additionalUserInfo = @{@"userinfo": @"userinfo2", @"additional2": @"additional3"};
    NSError *result = MSIDCreateError(@"TestDomain", -5555, @"Test description", @"oauth_error", @"suberror", underlyingError, correlationId, additionalUserInfo);

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.domain, @"custom_TestDomain");
    XCTAssertEqual(result.code, -4555);
    XCTAssertEqualObjects(result.userInfo[@"custom_description"], @"Test description");
    XCTAssertEqualObjects(result.userInfo[@"custom_oautherror"], @"oauth_error");
    XCTAssertEqualObjects(result.userInfo[@"custom_suberror"], @"suberror");
    XCTAssertEqualObjects(result.userInfo[@"custom_underlyingerror"], underlyingError);
    XCTAssertEqualObjects(result.userInfo[@"custom_correlationid"], [correlationId UUIDString]);
    XCTAssertEqualObjects(result.userInfo[@"userinfo"], @"userinfo2");
    XCTAssertEqualObjects(result.userInfo[@"additional2"], @"additional3");
}

- (void)testMSIDCreateError_withNilDomain_shouldReturnNil
{
    NSError *result = MSIDCreateError(nil, 0, nil, nil, nil, nil, nil, nil);
    XCTAssertNil(result);
}

@end
