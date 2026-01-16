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
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"
#import "MSIDInteractiveWebviewState.h"

@interface MSIDSpecialURLViewActionResolverTests : XCTestCase

@end

@implementation MSIDSpecialURLViewActionResolverTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Enroll URL Tests

- (void)testResolveActionForURL_withEnrollURL_shouldReturnLoadRequestAction
{
    NSURL *url = [NSURL URLWithString:@"msauth://enroll?cpurl=https://contoso.com/enroll-device"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequestInWebview);
    XCTAssertNotNil(action.request);
    XCTAssertEqualObjects(action.request.URL.absoluteString, @"https://contoso.com/enroll-device");
}

- (void)testResolveActionForURL_withEnrollURLMissingCpurl_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"msauth://enroll"];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:nil];
    
    XCTAssertNil(action);
}

#pragma mark - Compliance URL Tests

- (void)testResolveActionForURL_withComplianceURL_shouldReturnLoadRequestAction
{
    NSURL *url = [NSURL URLWithString:@"msauth://compliance?cpurl=https://contoso.com/check-compliance"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequestInWebview);
    XCTAssertNotNil(action.request);
    XCTAssertEqualObjects(action.request.URL.absoluteString, @"https://contoso.com/check-compliance");
}

#pragma mark - Install Profile URL Tests

- (void)testResolveActionForURL_withInstallProfileURLRequiringASWebAuth_shouldReturnOpenASWebAuthSessionAction
{
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://contoso.com/profile&requireASWebAuthenticationSession=true"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertEqualObjects(action.url.absoluteString, @"https://contoso.com/profile");
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeInstallProfile);
}

- (void)testResolveActionForURL_withInstallProfileURLNotRequiringASWebAuth_shouldReturnLoadRequestAction
{
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://contoso.com/profile&requireASWebAuthenticationSession=false"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeLoadRequestInWebview);
    XCTAssertNotNil(action.request);
    XCTAssertEqualObjects(action.request.URL.absoluteString, @"https://contoso.com/profile");
}

- (void)testResolveActionForURL_withInstallProfileURLMissingURL_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?requireASWebAuthenticationSession=true"];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:nil];
    
    XCTAssertNil(action);
}

- (void)testResolveActionForURL_withInstallProfileURLAndHeaders_shouldIncludeAuthTokenHeaderOnly
{
    // Simulate Intune response: msauth://installProfile with X-Intune-AuthToken header
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://contoso.com/profile&requireASWebAuthenticationSession=true"];
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    // Simulate headers captured from HTTP response
    state.responseHeaders = @{
        @"X-Intune-AuthToken": @"test-auth-token-12345",
        @"X-Install-Url": @"https://install.contoso.com/actual-profile",
        @"X-MS-Telemetry": @"telemetry-data"
    };
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    // URL should come from X-Install-Url header, not query param
    XCTAssertEqualObjects(action.url.absoluteString, @"https://install.contoso.com/actual-profile");
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeInstallProfile);
    
    // Verify only X-Intune-AuthToken is passed in additionalHeaders
    XCTAssertNotNil(action.additionalHeaders);
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"test-auth-token-12345");
    XCTAssertNil(action.additionalHeaders[@"X-MS-Telemetry"]); // Not included
    XCTAssertNil(action.additionalHeaders[@"X-Install-Url"]); // Not included (used for URL)
}

- (void)testResolveActionForURL_withInstallProfileURLAndXInstallUrlHeader_shouldUseHeaderURL
{
    // X-Install-Url header should take priority over url query parameter
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://query.param.url&requireASWebAuthenticationSession=true"];
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.responseHeaders = @{
        @"X-Install-Url": @"https://header.install.url",
        @"X-Intune-AuthToken": @"auth-token-xyz"
    };
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    // Should use X-Install-Url from header, not query param
    XCTAssertEqualObjects(action.url.absoluteString, @"https://header.install.url");
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"auth-token-xyz");
}

- (void)testResolveActionForURL_withInstallProfileURLWithoutXInstallUrlHeader_shouldFallbackToQueryParam
{
    // Without X-Install-Url header, should use url query parameter
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://query.param.url&requireASWebAuthenticationSession=true"];
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.responseHeaders = @{
        @"X-Intune-AuthToken": @"auth-token-xyz"
    };
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    // Should fall back to query param URL
    XCTAssertEqualObjects(action.url.absoluteString, @"https://query.param.url");
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"auth-token-xyz");
}

- (void)testResolveActionForURL_withInstallProfileURLAndOnlyXInstallUrlHeader_shouldWorkWithoutAuthToken
{
    // Should work with X-Install-Url but no X-Intune-AuthToken
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://fallback.url&requireASWebAuthenticationSession=true"];
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.responseHeaders = @{
        @"X-Install-Url": @"https://header.only.url"
    };
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertEqualObjects(action.url.absoluteString, @"https://header.only.url");
    XCTAssertNil(action.additionalHeaders); // No auth token to pass
}

- (void)testResolveActionForURL_withInstallProfileURLWithoutHeaders_shouldHaveNilHeaders
{
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://contoso.com/profile&requireASWebAuthenticationSession=true"];
    
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    // No headers set in state
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertNil(action.additionalHeaders);
}

#pragma mark - Profile Complete URL Tests

- (void)testResolveActionForURL_withProfileCompleteURL_shouldReturnCompleteWithURLAction
{
    NSURL *url = [NSURL URLWithString:@"msauth://profileComplete"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL);
    XCTAssertEqualObjects(action.url, url);
}

#pragma mark - Browser URL Tests

- (void)testResolveActionForURL_withBrowserURL_shouldReturnCompleteWithURLAction
{
    NSURL *url = [NSURL URLWithString:@"browser://example.com"];
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertNotNil(action);
    XCTAssertEqual(action.type, MSIDWebviewActionTypeCompleteWithURL);
    XCTAssertEqualObjects(action.url, url);
}

#pragma mark - Unknown URL Tests

- (void)testResolveActionForURL_withUnknownScheme_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"unknown://test"];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:nil];
    
    XCTAssertNil(action);
}

- (void)testResolveActionForURL_withUnknownMsauthHost_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"msauth://unknownHost"];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:nil];
    
    XCTAssertNil(action);
}

- (void)testResolveActionForURL_withNilURL_shouldReturnNil
{
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:nil state:nil];
    
    XCTAssertNil(action);
}

@end
