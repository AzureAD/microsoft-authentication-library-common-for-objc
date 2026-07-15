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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDBrowserNativeMessageGetTokenRequestParametersFactory.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDClaimsRequest.h"
#import "MSIDOAuth2Constants.h"

@interface MSIDBrowserNativeMessageGetTokenRequestParametersFactoryTests : XCTestCase

@end

@implementation MSIDBrowserNativeMessageGetTokenRequestParametersFactoryTests

- (MSIDBrowserNativeMessageGetTokenRequest *)request
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                    rawTenant:nil
                                                      context:nil
                                                        error:nil];
    request.authScheme = [MSIDAuthenticationScheme new];
    request.clientId = @"parent-client";
    request.redirectUri = @"parent://redirect";
    request.scopes = @"User.Read OPENID profile offline_access user.read";
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                              homeAccountId:@"uid.utid"];
    request.prompt = MSIDPromptTypeConsent;
    request.loginHint = @"hint@contoso.com";
    request.claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"access_token": @{}}
                                                                        error:nil];
    request.nonce = @"nonce";
    request.instanceAware = YES;
    request.sender = [NSURL URLWithString:@"https://contoso.com/page"];
    request.platformSequence = @"browser|1,broker|2";
    request.extraParameters = @{@"custom": @"value",
                                @"child_client_id": @"child-client",
                                @"child_redirect_uri": @"child://redirect"};
    request.correlationId = [NSUUID UUID];
    return request;
}

- (void)testRequestParametersWithRequest_copiesAndTransformsCompleteRequest
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [self request];
    NSUUID *correlationOverride = [NSUUID UUID];
    NSError *error = nil;

    MSIDInteractiveTokenRequestParameters *parameters =
    [MSIDBrowserNativeMessageGetTokenRequestParametersFactory requestParametersWithRequest:request
                                                                                requestType:MSIDRequestBrokeredType
                                                            boundAppRefreshTokenRequested:YES
                                                                       correlationIdOverride:correlationOverride
                                                                                     error:&error];

    XCTAssertNotNil(parameters);
    XCTAssertNil(error);
    XCTAssertEqualObjects(parameters.target, @"user.read");
    XCTAssertEqualObjects(parameters.oidcScope, @"openid profile offline_access");
    XCTAssertEqualObjects(parameters.clientId, @"child-client");
    XCTAssertEqualObjects(parameters.redirectUri, @"child://redirect");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerClientId, @"parent-client");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerRedirectUri, @"parent://redirect");
    XCTAssertEqualObjects(parameters.extraURLQueryParameters, @{@"custom": @"value"});
    XCTAssertEqual(parameters.authScheme, request.authScheme);
    XCTAssertEqual(parameters.authority, request.authority);
    XCTAssertEqual(parameters.accountIdentifier, request.accountId);
    XCTAssertEqual(parameters.promptType, request.prompt);
    XCTAssertEqualObjects(parameters.loginHint, request.loginHint);
    XCTAssertEqual(parameters.claimsRequest, request.claimsRequest);
    XCTAssertEqualObjects(parameters.nonce, request.nonce);
    XCTAssertTrue(parameters.instanceAware);
    XCTAssertEqualObjects(parameters.webPageUri, request.sender.absoluteString);
    XCTAssertEqualObjects(parameters.platformSequence, request.platformSequence);
    XCTAssertTrue(parameters.allowAnyExtraURLQueryParameters);
    XCTAssertTrue(parameters.ignoreScopeValidation);
    XCTAssertTrue(parameters.bypassRedirectURIValidation);
    XCTAssertEqual(parameters.requestType, MSIDRequestBrokeredType);
    XCTAssertTrue(parameters.isBoundAppRefreshTokenRequested);
    XCTAssertEqualObjects(parameters.correlationId, correlationOverride);
}

- (void)testRequestParametersWithRequest_unpairedChildParameter_isForwardedWithoutNesting
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [self request];
    request.extraParameters = @{@"child_client_id": @"child-client", @"custom": @"value"};

    MSIDInteractiveTokenRequestParameters *parameters =
    [MSIDBrowserNativeMessageGetTokenRequestParametersFactory requestParametersWithRequest:request
                                                                                requestType:MSIDRequestLocalType
                                                            boundAppRefreshTokenRequested:NO
                                                                       correlationIdOverride:nil
                                                                                     error:nil];

    XCTAssertEqualObjects(parameters.clientId, @"parent-client");
    XCTAssertEqualObjects(parameters.redirectUri, @"parent://redirect");
    XCTAssertNil(parameters.nestedAuthBrokerClientId);
    XCTAssertNil(parameters.nestedAuthBrokerRedirectUri);
    XCTAssertEqualObjects(parameters.extraURLQueryParameters, request.extraParameters);
    XCTAssertEqual(parameters.requestType, MSIDRequestLocalType);
    XCTAssertFalse(parameters.isBoundAppRefreshTokenRequested);
    XCTAssertEqualObjects(parameters.correlationId, request.correlationId);
}

- (void)testRequestParametersWithRequest_missingAuthority_returnsError
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [self request];
    request.authority = nil;
    NSError *error = nil;

    MSIDInteractiveTokenRequestParameters *parameters =
    [MSIDBrowserNativeMessageGetTokenRequestParametersFactory requestParametersWithRequest:request
                                                                                requestType:MSIDRequestLocalType
                                                            boundAppRefreshTokenRequested:NO
                                                                       correlationIdOverride:nil
                                                                                     error:&error];

    XCTAssertNil(parameters);
    XCTAssertNotNil(error);
}

- (void)testRequestParametersWithRequest_preservesParsedPopAuthenticationScheme
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [self request];
    NSDictionary *schemeParameters = @{MSID_OAUTH2_TOKEN_TYPE: @"Pop",
                                       MSID_OAUTH2_REQUEST_CONFIRMATION: @"eyJraWQiOiJraWQifQ"};
    request.authScheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:schemeParameters];
    NSError *error = nil;

    MSIDInteractiveTokenRequestParameters *parameters =
    [MSIDBrowserNativeMessageGetTokenRequestParametersFactory requestParametersWithRequest:request
                                                                                requestType:MSIDRequestLocalType
                                                            boundAppRefreshTokenRequested:NO
                                                                       correlationIdOverride:nil
                                                                                     error:&error];

    XCTAssertNotNil(parameters);
    XCTAssertNil(error);
    XCTAssertEqual(parameters.authScheme, request.authScheme);
    XCTAssertEqual(parameters.authScheme.authScheme, MSIDAuthSchemePop);
    XCTAssertEqualObjects(parameters.authScheme.schemeParameters[MSID_OAUTH2_TOKEN_TYPE], @"Pop");
    XCTAssertEqualObjects(parameters.authScheme.schemeParameters[MSID_OAUTH2_REQUEST_CONFIRMATION], @"eyJraWQiOiJraWQifQ");
}

@end
