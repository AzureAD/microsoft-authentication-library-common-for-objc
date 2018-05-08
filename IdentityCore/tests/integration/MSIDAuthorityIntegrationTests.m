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
#import "MSIDAuthority.h"
#import "MSIDTestURLResponse.h"
#import "MSIDTestURLSession.h"
#import "MSIDOpenIdProviderMetadata.h"

@interface MSIDAuthorityIntegrationTests : XCTestCase

@end

@implementation MSIDAuthorityIntegrationTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    
    [MSIDAuthority.openIdConfigurationCache removeAllObjects];
}

#pragma mark - loadOpenIdConfigurationInfo

- (void)testLoadOpenIdConfigurationInfo_whenSent2Times_shouldUseCacheFor2ndRequest
{
    __auto_type openIdConfigurationUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration"];
    __auto_type httpResponse = [NSHTTPURLResponse new];
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:openIdConfigurationUrl
                                                         reponse:httpResponse];
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/{tenantid}/v2.0"
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    // Cache is empty, 'loadOpenIdConfigurationInfo' shoul make network request and save result into the cache (no network error).
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET OpenId Configuration Request"];
    [MSIDAuthority loadOpenIdConfigurationInfo:openIdConfigurationUrl context:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(metadata);
        XCTAssertTrue([metadata isKindOfClass:MSIDOpenIdProviderMetadata.class]);
        XCTAssertEqualObjects(metadata.authorizationEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize");
        XCTAssertEqualObjects(metadata.tokenEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/token");
        XCTAssertEqualObjects(metadata.issuer.absoluteString, @"https://login.microsoftonline.com/common/v2.0");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Send same request 2nd time. Now 'loadOpenIdConfigurationInfo' shoul not make network request, but take result from cache.
    expectation = [self expectationWithDescription:@"GET OpenId Configuration From Cache"];
    [MSIDAuthority loadOpenIdConfigurationInfo:openIdConfigurationUrl context:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(metadata);
         XCTAssertTrue([metadata isKindOfClass:MSIDOpenIdProviderMetadata.class]);
         XCTAssertEqualObjects(metadata.authorizationEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize");
         XCTAssertEqualObjects(metadata.tokenEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/token");
         XCTAssertEqualObjects(metadata.issuer.absoluteString, @"https://login.microsoftonline.com/common/v2.0");
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testLoadOpenIdConfigurationInfo_whenSent2TimesAnd1stResponseWasWithError_shouldNotUseCacheFor2ndRequest
{
    __auto_type openIdConfigurationUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration"];
    __auto_type httpResponse = [NSHTTPURLResponse new];
    
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:openIdConfigurationUrl
                                                         respondWithError:[NSError new]];
    [responseWithError setRequestHeaders:nil];
    [MSIDTestURLSession addResponse:responseWithError];
    
    // 1st response with error.
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET OpenId Configuration Request"];
    [MSIDAuthority loadOpenIdConfigurationInfo:openIdConfigurationUrl context:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         XCTAssertNil(metadata);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:openIdConfigurationUrl
                                                         reponse:httpResponse];
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/{tenantid}/v2.0"
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    // 2nd response is valid and contains metadata.
    expectation = [self expectationWithDescription:@"GET OpenId Configuration From Cache"];
    [MSIDAuthority loadOpenIdConfigurationInfo:openIdConfigurationUrl context:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(metadata);
         XCTAssertTrue([metadata isKindOfClass:MSIDOpenIdProviderMetadata.class]);
         XCTAssertEqualObjects(metadata.authorizationEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize");
         XCTAssertEqualObjects(metadata.tokenEndpoint.absoluteString, @"https://login.microsoftonline.com/common/oauth2/v2.0/token");
         XCTAssertEqualObjects(metadata.issuer.absoluteString, @"https://login.microsoftonline.com/common/v2.0");
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
