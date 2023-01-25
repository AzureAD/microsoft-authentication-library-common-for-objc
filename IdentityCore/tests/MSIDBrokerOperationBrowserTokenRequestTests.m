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
#import "MSIDBrokerOperationBrowserTokenRequest.h"

@interface MSIDBrokerOperationBrowserTokenRequest(Test)

+ (NSString *)protocolLogNameForRequestURL:(NSURL *)requestURL;

@end

@interface MSIDBrokerOperationBrowserTokenRequestTests : XCTestCase

@end

@implementation MSIDBrokerOperationBrowserTokenRequestTests

- (void)testProtocolLogNameForRequestURL_whenValidOAuth2URL_shouldReturnOAuthIdentifier
{
    NSString *url = @"https://login.microsoftonline.com/contoso.com/oauth2/v2.0/authorize?client_id=client";

    NSString *result = [MSIDBrokerOperationBrowserTokenRequest protocolLogNameForRequestURL:[NSURL URLWithString:url]];

    XCTAssertEqualObjects(result, @"OAuth2 Authorize");
}

- (void)testProtocolLogNameForRequestURL_whenNonCommonIdentifier_shouldReturnNAIdentifier
{
    NSString *url = @"https://login.microsoftonline.com/contoso.com/oauth2/v2.0/fido";

    NSString *result = [MSIDBrokerOperationBrowserTokenRequest protocolLogNameForRequestURL:[NSURL URLWithString:url]];

    XCTAssertEqualObjects(result, @"N/A");
}

@end
