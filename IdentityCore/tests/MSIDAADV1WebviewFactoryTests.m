//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAADV1WebviewFactory.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDPkce.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDeviceId.h"

@interface MSIDAADV1WebviewFactoryTests : XCTestCase

@end

@implementation MSIDAADV1WebviewFactoryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testAuthorizationParametersFromConfiguration_withValidParams_shouldContainAADV1Configuration
{
    __block NSUUID *correlationId = [NSUUID new];
    
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:DEFAULT_TEST_RESOURCE
                                                                                                scopes:nil
                                                                                         correlationId:correlationId
                                                                                            enablePkce:NO];
    
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    config.promptBehavior = @"login";
    config.claims = @"claims";
    config.loginHint = @"fakeuser@contoso.com";
    
    NSString *requestState = @"state";
    
    MSIDAADV1WebviewFactory *factory = [MSIDAADV1WebviewFactory new];
    
    NSDictionary *params = [factory authorizationParametersFromConfiguration:config requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"resource" : DEFAULT_TEST_RESOURCE,
                                          @"response_type" : @"code",
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"claims" : @"claims",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"prompt" : @"login",
                                          @"haschrome" : @"1"
                                          }];
    
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testAuthorizationParametersFromConfiguration_withValidParamsWithScopes_shouldContainAADV1ConfigurationWithScopes
{
    __block NSUUID *correlationId = [NSUUID new];
    
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:DEFAULT_TEST_RESOURCE
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:@"scope1", nil]
                                                                                         correlationId:correlationId
                                                                                            enablePkce:NO];
    
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    config.promptBehavior = @"login";
    config.claims = @"claims";
    config.loginHint = @"fakeuser@contoso.com";
    
    NSString *requestState = @"state";
    
    MSIDAADV1WebviewFactory *factory = [MSIDAADV1WebviewFactory new];
    
    NSDictionary *params = [factory authorizationParametersFromConfiguration:config requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"resource" : DEFAULT_TEST_RESOURCE,
                                          @"response_type" : @"code",
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"claims" : @"claims",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"prompt" : @"login",
                                          @"haschrome" : @"1",
                                          @"scope" : @"scope1"
                                          }];
    
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}


@end
