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
#import "MSIDTestIdentifiers.h"
#import "MSIDPkce.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDeviceId.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDPkce.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAADV1WebviewFactoryTests : XCTestCase

@end

@implementation MSIDAADV1WebviewFactoryTests

- (void)testAuthorizationParametersFromParameters_withValidParams_shouldContainAADV1Configuration
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.extraAuthorizeURLQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.promptType = MSIDPromptTypeLogin;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.target = DEFAULT_TEST_RESOURCE;
    
    NSString *requestState = @"state";
    
    MSIDAADV1WebviewFactory *factory = [MSIDAADV1WebviewFactory new];
    
    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:nil requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"resource" : DEFAULT_TEST_RESOURCE,
                                          @"response_type" : @"code",
                                          @"eqp1" : @"val1",
                                          @"eqp2" : @"val2",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : parameters.correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"prompt" : @"login",
                                          @"haschrome" : @"1",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new]
                                          }];
    
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}

- (void)testAuthorizationParametersFromConfiguration_withValidParamsWithScopes_shouldContainAADV1ConfigurationWithScopes
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.target = DEFAULT_TEST_RESOURCE;
    parameters.oidcScope = @"openid";
    
    NSString *requestState = @"state";
    
    MSIDAADV1WebviewFactory *factory = [MSIDAADV1WebviewFactory new];
    
    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:nil requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"resource" : DEFAULT_TEST_RESOURCE,
                                          @"response_type" : @"code",
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : parameters.correlationId.UUIDString,
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"haschrome" : @"1",
                                          @"scope" : @"openid",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new]
                                          }];
    
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}


@end
