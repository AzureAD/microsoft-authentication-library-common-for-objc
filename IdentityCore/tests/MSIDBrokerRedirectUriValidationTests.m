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
#import "NSURL+MSIDBrokerRedirectUri.h"

@interface MSIDBrokerRedirectUriValidationTests : XCTestCase

@end

@implementation MSIDBrokerRedirectUriValidationTests

- (void)test_default_non_broker_redirectUri_with_nil_or_empty_cliendid
{
    NSURL *redirectUri = [NSURL defaultNonBrokerRedirectUri:nil];
    XCTAssertNil(redirectUri);
    
    redirectUri = [NSURL defaultNonBrokerRedirectUri:@""];
    XCTAssertNil(redirectUri);
}

- (void)test_default_non_broker_redirectUri_with_valid_cliendid
{
    NSString *clientId = @"clientId";
    NSURL *redirectUri = [NSURL defaultNonBrokerRedirectUri:clientId];
    XCTAssertEqualObjects(redirectUri.absoluteString, @"msalclientId://auth");
}

- (void)test_get_default_broker_capable_redirectUri
{
    NSURL *redirectUri = [NSURL defaultBrokerCapableRedirectUri];
    XCTAssertNotNil(redirectUri);
}

- (void)test_redirectUri_is_broker_capable_with_nil_url
{
    XCTAssertFalse([NSURL redirectUriIsBrokerCapable:nil]);
}

- (void)test_redirectUri_is_broker_capable_with_invalid_url
{
    XCTAssertFalse([NSURL redirectUriIsBrokerCapable:[NSURL URLWithString:@"https://fakeurl.contoso.com"]]);
}

- (void)test_check_default_redirect_msal_format
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"msauth.com.microsoft.MSIDTestsHostApp://auth"];
#else
    url = [NSURL URLWithString:@"msauth.com.apple.dt.xctest.tool://auth"];
#endif
    XCTAssertTrue([NSURL redirectUriIsBrokerCapable:url]);

}

- (void)test_check_default_redirect_adal_format
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"myscheme://com.microsoft.MSIDTestsHostApp"];
#else
    url = [NSURL URLWithString:@"myscheme://com.apple.dt.xctest.tool"];
#endif
    XCTAssertTrue([NSURL redirectUriIsBrokerCapable:url]);

}

- (void)test_check_default_redirect_adal_format_without_scheme
{
    NSURL *url = nil;
#if TARGET_OS_IPHONE
    url = [NSURL URLWithString:@"com.microsoft.MSIDTestsHostApp"];
#else
    url = [NSURL URLWithString:@"com.apple.dt.xctest.tool"];
#endif
    XCTAssertFalse([NSURL redirectUriIsBrokerCapable:url]);

}

@end
