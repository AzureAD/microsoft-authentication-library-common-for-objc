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
#import "MSIDAADWebviewFactory.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDWebviewConfiguration.h"
#import "MSIDDeviceId.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDWebWPJAuthResponse.h"
#import "MSIDWebAADAuthResponse.h"

@interface MSIDAADWebviewFactoryTests : XCTestCase

@end

@implementation MSIDAADWebviewFactoryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testAuthorizationParametersFromConfiguration_withValidParams_shouldContainAADConfiguration
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    __block NSUUID *correlationId = [NSUUID new];
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:[NSURL URLWithString:DEFAULT_TEST_AUTHORIZATION_ENDPOINT]
                                                                                           redirectUri:DEFAULT_TEST_REDIRECT_URI
                                                                                              clientId:DEFAULT_TEST_CLIENT_ID
                                                                                              resource:nil
                                                                                                scopes:[NSOrderedSet orderedSetWithObjects:@"scope1", nil]
                                                                                         correlationId:correlationId
                                                                                            enablePkce:NO];
    
    config.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    config.loginHint = @"fakeuser@contoso.com";
    config.claims = @"claims";
    config.promptBehavior = @"login";
    config.sliceParameters = DEFAULT_TEST_SLICE_PARAMS_DICT;
    
    NSString *requestState = @"state";
    
    NSDictionary *params = [factory authorizationParametersFromConfiguration:config requestState:requestState];

    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"claims" : @"claims",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"scope" : @"scope1 openid",
                                          @"prompt" : @"login",
                                          @"slice": @"myslice",
                                          @"haschrome" : @"1"
                                          }];
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    [expectedQPs addEntriesFromDictionary:DEFAULT_TEST_SLICE_PARAMS_DICT];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}


- (void)testResponseWithURL_whenURLSchemeMsauth_shouldReturnWPJResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"msauth://wpj?app_link=link"]
                                       requestState:nil
                                        verifyState:NO
                                            context:nil
                                              error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebWPJAuthResponse.class]);
    XCTAssertNil(error);
}


- (void)testResponseWithURL_whenURLSchemeNotMsauth_shouldReturnAADAuthResponse
{
    MSIDAADWebviewFactory *factory = [MSIDAADWebviewFactory new];
    
    NSError *error = nil;
    __auto_type response = [factory responseWithURL:[NSURL URLWithString:@"redirecturi://somepayload?code=authcode&cloud_instance_host_name=somename"]
                                       requestState:nil
                                        verifyState:NO
                                            context:nil
                                              error:&error];
    
    XCTAssertTrue([response isKindOfClass:MSIDWebAADAuthResponse.class]);
    XCTAssertNil(error);
}



@end
