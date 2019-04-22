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
#import "MSIDWebAADAuthResponse.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDWebAADAuthResponseTests : XCTestCase

@end

@implementation MSIDWebAADAuthResponseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit_whenRequestStateIsNil_shouldReturnNil
{
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"code",
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost",
                                 MSID_OAUTH2_STATE : @"somestate"
                                 }.urlQueryItemsArray;
    
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:nil ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}


- (void)testInit_whenReturnStateIsNil_shouldReturnNil
{
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"code",
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost"
                                 }.urlQueryItemsArray;
    
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    
    XCTAssertEqual(error.code, MSIDErrorServerInvalidState);
}



- (void)testInit_whenAllValuesExist_shouldContainResponseWithAllValues
{
    NSString *state = @"state";
    
    NSError *error;
    NSString *rawClientInfo = @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0";
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"code",
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost",
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode,
                                 MSID_OAUTH2_CLIENT_INFO : rawClientInfo
                                 }.urlQueryItemsArray;
    MSIDClientInfo *expectedClientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:nil];
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
    XCTAssertEqualObjects(response.clientInfo, expectedClientInfo);
}

- (void)testInit_whenURLContainsBothFragmentAndQuery_withCodeInQuery_shouldContainResponseWithAllValues
{
    NSString *state = @"state";
    
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"code",
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost",
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode
                                 }.urlQueryItemsArray;
    urlComponents.fragment = @"_=_";
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
}

- (void)testInit_whenURLContainsBothFragmentAndQuery_withCodeInFragment_shouldContainResponseWithAllValues
{
    NSString *state = @"state";
    
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost",
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode
                                 }.urlQueryItemsArray;
    urlComponents.fragment = @"code=fragment_code";
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"fragment_code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
}

- (void)testInit_whenURLContainsBothFragmentAndQuery_withCodeInBoth_shouldUseCodeFromTheQuery
{
    NSString *state = @"state";
    
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"query_code",
                                 MSID_AUTH_CLOUD_INSTANCE_HOST_NAME : @"cloudHost",
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode
                                 }.urlQueryItemsArray;
    urlComponents.fragment = @"code=fragment_code&_=_";
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"query_code");
    XCTAssertEqualObjects(response.cloudHostName, @"cloudHost");
}

- (void)testInit_whenNoCloudHostInstanceNameExistsAndNoClientInfoReturned_shouldNotContainCloudInstanceHostNameOrClientInfo
{
    NSString *state = @"state";
    
    NSError *error;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:@"https://contoso.com"];
    urlComponents.queryItems = @{
                                 MSID_OAUTH2_CODE : @"code",
                                 MSID_OAUTH2_STATE : state.msidBase64UrlEncode
                                 }.urlQueryItemsArray;
    
    
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:urlComponents.URL requestState:@"state" ignoreInvalidState:NO context:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.authorizationCode, @"code");
    XCTAssertNil(response.cloudHostName);
    XCTAssertNil(response.clientInfo);
}


@end
