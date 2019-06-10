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
#import "MSIDDeviceId.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAdfsAuthorityResolver.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAADEndpointProvider.h"
#import "MSIDB2CAuthority.h"
#import "MSIDAADAuthority.h"
#import "MSIDADFSAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAuthority+Internal.h"

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
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    [MSIDAdfsAuthorityResolver.cache removeAllObjects];

    MSIDAADNetworkConfiguration.defaultConfiguration.endpointProvider = [MSIDAADEndpointProvider new];
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
    
    [MSIDTestURLSession clearResponses];
}

#pragma mark - loadOpenIdConfigurationInfo

- (void)testLoadOpenIdConfigurationInfo_whenSent2Times_shouldUseCacheFor2ndRequest
{
    __auto_type openIdConfigurationUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration"];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    
    __auto_type requestUrl = [@"https://example.com/common/.well-known/openid-configuration" msidUrl];

    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/{tenantid}/v2.0"
                                 };
    [response setResponseJSON:responseJson];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:response];
    
    __auto_type authority = [self loadAuthorityWithOpenIdConfigurationEndpoint:openIdConfigurationUrl];

    // Cache is empty, 'loadOpenIdConfigurationInfo' should make network request and save result into the cache (no network error).
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET OpenId Configuration Request"];
    
    [authority loadOpenIdMetadataWithContext:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
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

    // Send same request 2nd time. Now 'loadOpenIdConfigurationInfo' should not make network request, but take result from cache.
    expectation = [self expectationWithDescription:@"GET OpenId Configuration From Cache"];
    [authority loadOpenIdMetadataWithContext:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
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
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testLoadOpenIdConfigurationInfo_whenSent2TimesAnd1stResponseWasWithError_shouldNotUseCacheFor2ndRequest
{
    __auto_type openIdConfigurationUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration"];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://example.com/common/.well-known/openid-configuration" msidUrl];

    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:requestUrl
                                                         respondWithError:[NSError new]];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];
    
    __auto_type authority = [self loadAuthorityWithOpenIdConfigurationEndpoint:openIdConfigurationUrl];

    // 1st response with error.
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET OpenId Configuration Request"];
    [authority loadOpenIdMetadataWithContext:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
     {
         XCTAssertNil(metadata);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    __auto_type responseJson = @{
                                 @"authorization_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                                 @"token_endpoint" : @"https://login.microsoftonline.com/common/oauth2/v2.0/token",
                                 @"issuer" : @"https://login.microsoftonline.com/{tenantid}/v2.0"
                                 };
    [response setResponseJSON:responseJson];
    response->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:response];

    // 2nd response is valid and contains metadata.
    expectation = [self expectationWithDescription:@"GET OpenId Configuration From Cache"];
    [authority loadOpenIdMetadataWithContext:nil completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
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
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

#pragma mark - discoverAuthority, B2C

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateYesAuthroityIsKnown_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy/qwe" msidUrl];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateYesAuthroityIsNotKnown_shouldReturnError
{
    __auto_type authorityUrl = [@"https://example.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy/policy/qwe" msidUrl];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateNoAuthroityIsNotKnown_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://example.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy/qwe" msidUrl];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    [authority resolveAndValidate:NO userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://example.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy", authority.url.absoluteString);
         XCTAssertEqualObjects(@"https://example.com/tfp/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/policy/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - discoverAuthority, AAD

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsKnown_shouldReturnErrorNil
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/qwe" aadAuthority];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Foauth2%2Fauthorize&" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.url.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsNotKnown_shouldReturnErrorNil
{
    __auto_type authority = [@"https://example.com/common/qwe" aadAuthority];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Fexample.com%2Fcommon%2Foauth2%2Fauthorize&" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://example.com/common/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"example.com",
                                             @"preferred_cache" : @"example.com",
                                             @"aliases" : @[@"example.com"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://example.com/common", authority.url.absoluteString);
         XCTAssertEqualObjects(@"https://example.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenSent2Times_shouldUseCacheFor2ndRequest
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?&api-version=1.1&authorization_endpoint=https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Foauth2%2Fauthorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    // 2nd request
    expectation = [self expectationWithDescription:@"Get Authority Info From Cache"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenSent2TimesAnd1stResponseWasWithError_shouldNotUseCacheFor2ndRequest
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?&api-version=1.1&authorization_endpoint=https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Foauth2%2Fauthorize" msidUrl];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:nil];
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:requestUrl
                                                         respondWithError:error];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];

    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // 2nd request
    expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsInvalid_shouldReturnError
{
    __auto_type authorityUrl = [@"https://example.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:400 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Fexample.com%2Fcommon%2Foauth2%2Fauthorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"error" : @"invalid_instance"};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenAuthorityIsInvalid_shoulStoreInvalidRecordInCache
{
    __auto_type authorityUrl = [@"https://example.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:400 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Fexample.com%2Fcommon%2Foauth2%2Fauthorize&" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"error" : @"invalid_instance"};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    // 2nd request (no network call should happen)
    expectation = [self expectationWithDescription:@"Read Invalid Authority From Cache"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(openIdConfigurationEndpoint.absoluteString, @"https://example.com/common/.well-known/openid-configuration");
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsKnownAADApiVersionV2_shouldReturnErrorNil
{
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    
    __auto_type authorityUrl = [@"https://example.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Fexample.com%2Fcommon%2Foauth2%2Fv2.0%2Fauthorize&" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://example.com/common/v2.0/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

#pragma mark - discoverAuthority, ADFS

- (void)testDiscoverAuthority_whenAuthorityIsADFSValidateNo_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:NO userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenValidOnPremADFSAuthorityValidateYes_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";

    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // Web finger response.
    __auto_type webFingerRequestUrl = [@"https://example.com/.well-known/webfinger?resource=https%3A%2F%2Flogin.windows.com%2Fadfs" msidUrl];
    response = [MSIDTestURLResponse request:webFingerRequestUrl
                                    reponse:httpResponse];
    responseJson = @{@"links" : @[@{@"rel": @"http://schemas.microsoft.com/rel/trusted-realm",
                                    @"href" : @"https://login.windows.com/adfs"}]};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenWebFingerRequestFailed_shouldReturnError
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    
    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // Web finger response.
    __auto_type webFingerRequestUrl = [@"https://example.com/.well-known/webfinger?resource=https%3A%2F%2Flogin.windows.com%2Fadfs" msidUrl];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:nil];
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:webFingerRequestUrl
                                                         respondWithError:error];
    responseWithError->_requestHeaders = nil;
    [MSIDTestURLSession addResponse:responseWithError];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenValidCloudADFSAuthorityValidateYes_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";

    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:nil];
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:requestUrl
                                                         respondWithError:error];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];

    // Cloud Drs Response
    requestUrl = [@"https://enterpriseregistration.windows.net/microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type response = [MSIDTestURLResponse request:requestUrl
                                                reponse:httpResponse];
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // Web finger response.
    __auto_type webFingerRequestUrl = [@"https://example.com/.well-known/webfinger?resource=https%3A%2F%2Flogin.windows.com%2Fadfs" msidUrl];
    response = [MSIDTestURLResponse request:webFingerRequestUrl
                                    reponse:httpResponse];
    responseJson = @{@"links" : @[@{@"rel": @"http://schemas.microsoft.com/rel/trusted-realm",
                                    @"href" : @"https://login.windows.com/adfs"}]};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenValidCloudADFSWithNilResponseAndErrorAuthorityValidateYes_shouldReturnError
{
    __auto_type authority = [@"https://login.windows.com/adfs/qwe" adfsAuthority];
    __auto_type upn = @"user@microsoft.com";
    
    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:nil];
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:requestUrl
                                                         respondWithError:error];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];

    // Cloud Drs Response
    requestUrl = [@"https://enterpriseregistration.windows.net/microsoft.com/enrollmentserver/contract?api-version=1.0&" msidUrl];
    responseWithError = [MSIDTestURLResponse request:requestUrl
                                    respondWithError:error];
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenValidateNo_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:NO userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenSent2Requests_shouldUseCacheFor2ndRequest
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    
    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // Web finger response.
    __auto_type webFingerRequestUrl = [@"https://example.com/.well-known/webfinger?resource=https%3A%2F%2Flogin.windows.com%2Fadfs" msidUrl];
    response = [MSIDTestURLResponse request:webFingerRequestUrl
                                    reponse:httpResponse];
    responseJson = @{@"links" : @[@{@"rel": @"http://schemas.microsoft.com/rel/trusted-realm",
                                    @"href" : @"https://login.windows.com/adfs"}]};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    // 2nd request
    expectation = [self expectationWithDescription:@"Discover ADFS Authority (Using Cache)"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs", authority.url.absoluteString);
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenWebFingerResponseShowsThatAuthorityIsNotValid_shouldReturnError
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    
    // On Prem Drs Response
    __auto_type requestUrl = [@"https://enterpriseregistration.microsoft.com/enrollmentserver/contract?&api-version=1.0" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"IdentityProviderService" : @{@"PassiveAuthEndpoint" : @"https://example.com/adfs/ls"}};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    // Web finger response.
    __auto_type webFingerRequestUrl = [@"https://example.com/.well-known/webfinger?resource=https%3A%2F%2Flogin.windows.com%2Fadfs" msidUrl];
    response = [MSIDTestURLResponse request:webFingerRequestUrl
                                    reponse:httpResponse];
    responseJson = @{@"links" : @[@{@"rel": @"http://schemas.microsoft.com/rel/trusted-realm",
                                    @"href" : @"https://otherhost.com/adfs"}]};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:upn context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([MSIDTestURLSession noResponsesLeft]);
}

- (void)testDiscoverAuthority_whenValidateYesUpnNil_shouldReturnError
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenValidateNoUpnNil_shouldReturnErrorNil
{
    __auto_type authorityUrl = [@"https://login.windows.com/adfs/qwe" msidUrl];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover ADFS Authority"];
    [authority resolveAndValidate:NO userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.windows.com/adfs/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Private

- (MSIDAADAuthority *)loadAuthorityWithOpenIdConfigurationEndpoint:(NSURL *)openIdConfigurationEndpoint
{
    __auto_type authorityUrl = [@"https://example.com/common/qwe" msidUrl];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?&api-version=1.1&authorization_endpoint=https%3A%2F%2Fexample.com%2Fcommon%2Foauth2%2Fauthorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
#if TARGET_OS_IPHONE
    headers[@"x-ms-PkeyAuth"] = @"1.0";
#endif
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : openIdConfigurationEndpoint.absoluteString,
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"example.com",
                                             @"preferred_cache" : @"example.com",
                                             @"aliases" : @[@"example.com"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [authority resolveAndValidate:YES userPrincipalName:nil context:nil completionBlock:^(NSURL * openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    return authority;
}

@end
