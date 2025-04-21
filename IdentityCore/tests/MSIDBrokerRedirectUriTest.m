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
#import "MSIDRedirectUri.h"

@interface MSIDBrokerRedirectUriTest : XCTestCase

@end

@implementation MSIDBrokerRedirectUriTest

- (void)test_default_non_broker_redirectUri_with_nil_or_empty_cliendid
{
    NSURL *redirectUri = [MSIDRedirectUri defaultNonBrokerRedirectUri:@""];
    XCTAssertNil(redirectUri);
}

- (void)test_default_non_broker_redirectUri_with_valid_cliendid
{
    NSString *clientId = @"clientId";
    NSURL *redirectUri = [MSIDRedirectUri defaultNonBrokerRedirectUri:clientId];
    XCTAssertEqualObjects(redirectUri.absoluteString, @"msalclientId://auth");
}

- (void)test_get_default_broker_capable_redirectUri
{
    NSURL *redirectUri = [MSIDRedirectUri defaultBrokerCapableRedirectUri];
    XCTAssertNotNil(redirectUri);
}

- (void)test_check_empty_redirectUri
{
    NSError *error = nil;
    MSIDRedirectUriValidationResult result = [MSIDRedirectUri redirectUriIsBrokerCapable:[NSURL URLWithString:@""] error:&error];
    
    XCTAssertEqual(result, MSIDRedirectUriValidationResultNilOrEmpty);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);
}

- (void)test_redirectUri_is_broker_capable_with_https_url
{
    NSError *error = nil;
    MSIDRedirectUriValidationResult result = [MSIDRedirectUri redirectUriIsBrokerCapable:[NSURL URLWithString:@"https://fakeurl.contoso.com"] error:&error];
    
    XCTAssertEqual(result, MSIDRedirectUriValidationResultHttpFormatNotSupport);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);
}

- (void)test_check_default_redirect_msal_format
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"msauth.com.microsoft.MSIDTestsHostApp://auth"];
#else
    url = [NSURL URLWithString:@"msauth.com.apple.dt.xctest.tool://auth"];
#endif

    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:url error:&error], MSIDRedirectUriValidationResultMatched);
    XCTAssertNil(error);

}

- (void)test_check_default_redirect_adal_format
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"myscheme://com.microsoft.MSIDTestsHostApp"];
#else
    url = [NSURL URLWithString:@"myscheme://com.apple.dt.xctest.tool"];
#endif

    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:url error:&error], MSIDRedirectUriValidationResultMatched);
    XCTAssertNil(error);
}

- (void)test_check_default_redirect_adal_format_without_scheme
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"com.microsoft.MSIDTestsHostApp"];
#else
    url = [NSURL URLWithString:@"com.apple.dt.xctest.tool"];
#endif

    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:url error:&error], MSIDRedirectUriValidationResultSchemeNilOrEmpty);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);

}

- (void)test_checkRedirect_uri_miss_host
{
    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:[NSURL URLWithString:@"myscheme://"] error:&error], MSIDRedirectUriValidationResultHostNilOrEmpty);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);
}

- (void)test_checkRedirect_uri_msal_format_miss_host
{
    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:[NSURL URLWithString:@"msauth.com.microsoft.MSIDTestsHostApp://"] error:&error], MSIDRedirectUriValidationResultMSALFormatHostNilOrEmpty);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);
}

- (void)test_checkRedirect_uri_msal_format_miss_scheme
{
    NSError *error = nil;
    XCTAssertEqual([MSIDRedirectUri redirectUriIsBrokerCapable:[NSURL URLWithString:@"://auth"] error:&error], MSIDRedirectUriValidationResultSchemeNilOrEmpty);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertNotNil(error.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqual(error.code, MSIDErrorInvalidRedirectURI);
}

@end
