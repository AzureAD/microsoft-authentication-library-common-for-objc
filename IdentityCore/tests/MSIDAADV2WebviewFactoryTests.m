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
#import "MSIDAADV2WebviewFactory.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDPkce.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDeviceId.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDPkce.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAADV2WebviewFactoryTests : XCTestCase

@end

@implementation MSIDAADV2WebviewFactoryTests

- (void)testAuthorizationParametersFromParameters_withValidParams_shouldContainAADV2Configuration
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"fakeuser@contoso.com" homeAccountId:@"uid.utid"];
    
    NSString *requestState = @"state";
    
    MSIDAADV2WebviewFactory *factory = [MSIDAADV2WebviewFactory new];
    
    MSIDPkce *pkce = [MSIDPkce new];
    
    NSDictionary *params = [factory authorizationParametersFromRequestParameters:parameters pkce:pkce requestState:requestState];
    
    NSMutableDictionary *expectedQPs = [NSMutableDictionary dictionaryWithDictionary:
                                        @{
                                          @"client_id" : DEFAULT_TEST_CLIENT_ID,
                                          @"redirect_uri" : DEFAULT_TEST_REDIRECT_URI,
                                          @"response_type" : @"code",
                                          @"code_challenge_method" : @"S256",
                                          @"code_challenge" : pkce.codeChallenge,
                                          @"return-client-request-id" : @"true",
                                          @"client-request-id" : parameters.correlationId.UUIDString,
                                          @"login_hint" : @"fakeuser@contoso.com",
                                          @"state" : requestState.msidBase64UrlEncode,
                                          @"scope" : @"scope1",
                                          @"client_info" : @"1",
                                          @"login_req" : @"uid",
                                          @"domain_req" : @"utid",
                                          @"haschrome" : @"1",
                                          @"x-app-name" : [MSIDTestRequireValueSentinel new],
                                          @"x-app-ver" : [MSIDTestRequireValueSentinel new],
                                          @"x-client-Ver" : [MSIDTestRequireValueSentinel new]
                                          }];
    
    [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
    
    XCTAssertTrue([expectedQPs compareAndPrintDiff:params]);
}


@end
