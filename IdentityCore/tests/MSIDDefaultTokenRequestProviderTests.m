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
#import "MSIDDefaultTokenRequestProvider.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDDefaultBrokerTokenRequest.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDAccountMetadataCacheAccessor.h"

@interface MSIDDefaultTokenRequestProviderTests : XCTestCase

@end

@implementation MSIDDefaultTokenRequestProviderTests

- (void)testInteractiveTokenRequestWithParameters_whenParametersProvided_shouldReturnNonNilInteractiveTokenRequest
{
    MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] defaultAccessor:[MSIDDefaultTokenCacheAccessor new] accountMetadataAccessor:[MSIDAccountMetadataCacheAccessor new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    MSIDInteractiveTokenRequest *interactiveRequest = [provider interactiveTokenRequestWithParameters:[MSIDInteractiveRequestParameters new]];
    XCTAssertNotNil(interactiveRequest);
}

- (void)testSilentTokenRequestWithParameters_whenParametersProvided_shouldReturnDefaultSilentTokenRequest
{
    MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] defaultAccessor:[MSIDDefaultTokenCacheAccessor new] accountMetadataAccessor:[MSIDAccountMetadataCacheAccessor new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    MSIDSilentTokenRequest *silentRequest = [provider silentTokenRequestWithParameters:[MSIDRequestParameters new] forceRefresh:YES];
    XCTAssertNotNil(silentRequest);
    XCTAssertTrue([silentRequest isKindOfClass:[MSIDDefaultSilentTokenRequest class]]);
}

#if TARGET_OS_IPHONE

- (void)testBrokerTokenRequestWIthParameters_whenParametersProvided_shouldReturnDefaultBrokerTokenRequest
{
    MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] defaultAccessor:[MSIDDefaultTokenCacheAccessor new] accountMetadataAccessor:[MSIDAccountMetadataCacheAccessor new] tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    MSIDInteractiveRequestParameters *parameters = [MSIDInteractiveRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    parameters.redirectUri = @"x-msauth-testapp://auth";
    parameters.target = @"user.read";
    parameters.clientId = @"client_id";
    parameters.correlationId = [NSUUID UUID];

    NSError *error = nil;
    MSIDBrokerTokenRequest *brokerRequest = [provider brokerTokenRequestWithParameters:parameters brokerKey:@"brokerKey" brokerApplicationToken:@"brokerApplicationToken" error:&error];
    XCTAssertNotNil(brokerRequest);
    XCTAssertTrue([brokerRequest isKindOfClass:[MSIDDefaultBrokerTokenRequest class]]);
    XCTAssertNil(error);
}

#endif

@end
