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
#import "MSIDWebOAuth2Response.h"

@interface MSIDWebOAuth2ResponseTests : XCTestCase

@end

@implementation MSIDWebOAuth2ResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testInitWithParameters_whenNoAuthCodeAndNoError_shouldReturnNilAndInvalidParameterError
{
    NSError *error = nil;
    XCTAssertNil([[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://contoso.com"]
                                                    context:nil error:&error]);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInitWithParameters_whenAuthCode_shouldReturnAuthCode
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://contoso.com?code=authCode"]
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertEqualObjects(response.authorizationCode, @"authCode");
    XCTAssertNil(response.oauthError);
    XCTAssertNil(error);
}

- (void)testInitWithParameters_whenOAuthServerError_shouldReturnAuthCode
{
    NSError *error = nil;
    NSString *errorString = @"invalid_grant";
    NSString *errorDescription = @"error description";
    NSString *subError = @"suberror";

    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_ERROR : errorString,
                                 MSID_OAUTH2_ERROR_DESCRIPTION : errorDescription,
                                 MSID_OAUTH2_SUB_ERROR : subError,
                                 }.urlQueryItemsArray;
    
    
    
    
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:urlComponents.URL
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertNil(response.authorizationCode);
    XCTAssertNil(error);
    
    XCTAssertNotNil(response.oauthError);
    
    XCTAssertEqualObjects(response.oauthError.domain, MSIDOAuthErrorDomain);
    XCTAssertEqual(response.oauthError.code, MSIDErrorServerInvalidGrant);
    XCTAssertEqualObjects(response.oauthError.userInfo[MSIDErrorDescriptionKey], errorDescription);
    
    XCTAssertEqualObjects(response.oauthError.userInfo[MSIDOAuthErrorKey], errorString);
    XCTAssertEqualObjects(response.oauthError.userInfo[MSIDOAuthSubErrorKey], subError);
}

@end
