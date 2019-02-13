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
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDWebOAuth2ResponseTests : XCTestCase

@end

@implementation MSIDWebOAuth2ResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}


- (void)testInitWithParameters_whenNoRequestStateAndNoAuthCodeAndNoError_shouldReturnNilAndInvalidServerResponse
{
    NSError *error = nil;
    
    XCTAssertNil([[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://contoso.com"]
                                                    context:nil
                                                      error:&error]);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInitWithParameters_whenNoRequestStateAndAuthCode_shouldReturnAuthCode
{
    NSError *error = nil;
    
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://contoso.com?code=authCode"]
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertEqualObjects(response.authorizationCode, @"authCode");
    XCTAssertNil(response.oauthError);
    XCTAssertNil(error);
}

- (void)testInitWithParameters_whenNoRequestStateAndAuthCodeWithValidState_shouldReturnAuthCode
{
    NSError *error = nil;
    NSString *state = @"state";
    
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://contoso.com?code=authCode&state=%@", state.msidBase64UrlEncode]]
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertEqualObjects(response.authorizationCode, @"authCode");
    XCTAssertNil(response.oauthError);
    XCTAssertNil(error);
}

- (void)testInitWithParameters_whenAuthCodeIsEmptyString_shouldReturnNil
{
    NSError *error = nil;
    NSString *state = @"state";
    
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://contoso.com?code=&state=%@", state.msidBase64UrlEncode]]
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertNil(response.authorizationCode);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testInitWithParameters_whenNoRequestStateAndOAuthServerErrorWithValidState_shouldOAuthError
{
    NSError *error = nil;
    NSString *errorString = @"invalid_grant";
    NSString *errorDescription = @"error description";
    NSString *subError = @"suberror";
    NSString *state = @"state";
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_ERROR : errorString,
                                 MSID_OAUTH2_ERROR_DESCRIPTION : errorDescription,
                                 MSID_OAUTH2_SUB_ERROR : subError,
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode
                                 }.urlQueryItemsArray;
    
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:urlComponents.URL
                                                                    requestState:state
                                                              ignoreInvalidState:NO
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


- (void)testInitWithParameters_whenNoRequestStateAndOAuthServerError_shouldOAuthError
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

- (void)testInitWithParameters_whenNoStateReturnedAndNoAuthcodeAndNoOAuthError_shouldReturnNilWithInvalidStateError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:NO
                                                                         context:nil
                                                                           error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testInitWithParameters_whenNoStateReturnedAndAuthCode_shouldReturnNilWithInvalidStateError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/?code=iamacode"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:NO
                                                                         context:nil
                                                                           error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testInitWithParameters_whenNoStateReturnedAndOAuthError_shouldReturnNilWithInvalidStateError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:NO
                                                                         context:nil
                                                                           error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testInitWithParameters_whenInvalidStateAndAuthCode_shouldReturnNilWithInvalidStateError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/?code=iamacode&state=fake_state"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:NO
                                                                         context:nil
                                                                           error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testInitWithParameters_whenInvalidStateAndOAuthError_shouldReturnNilWithInvalidStateError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo&state=fake_state"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:NO
                                                                         context:nil
                                                                           error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}

- (void)testInitWithParameters_whenCode_InvalidState_NoStopAtVerification_shouldReturnAuthCode
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/?code=iamacode&state=fake_state"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:YES
                                                                         context:nil
                                                                           error:&error];
    XCTAssertEqualObjects(response.authorizationCode, @"iamacode");
    XCTAssertNil(response.oauthError);
    XCTAssertNil(error);
}

- (void)testInitWithParameters_whenOAuthError_InvalidState_NoStopAtVerification_shouldReturnNilWithOAuthError
{
    NSError *error = nil;
    MSIDWebOAuth2Response *response = [[MSIDWebOAuth2Response alloc] initWithURL:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo&state=fake_state"]
                                                                    requestState:@"requestState"
                                                              ignoreInvalidState:YES
                                                                         context:nil
                                                                           error:&error];
    
    XCTAssertNil(response.authorizationCode);
    XCTAssertNil(error);
    
    XCTAssertNotNil(response.oauthError);
    
    XCTAssertEqualObjects(response.oauthError.domain, MSIDOAuthErrorDomain);
}

@end

