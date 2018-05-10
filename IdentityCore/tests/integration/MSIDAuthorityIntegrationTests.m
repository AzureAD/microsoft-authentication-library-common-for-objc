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
#import "MSIDAadAuthorityCache+TestUtil.h"

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
    [[MSIDAadAuthorityCache sharedInstance] clear];
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

#pragma mark - discoverAuthority, B2C

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateYesAuthroityIsKnown_shouldReturnNormalizedAuthorityErrorNil
{
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/common/policy/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/tfp/common/policy", authority.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/tfp/common/policy/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateYesAuthroityIsNotKnown_shouldReturnError
{
    __auto_type authority = [@"https://example.com/tfp/common/policy/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(authority);
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsB2CValidateNoAuthroityIsNotKnown_shouldReturnNormalizedAuthorityErrorNil
{
    __auto_type authority = [@"https://example.com/tfp/common/policy/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover B2C Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:NO
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://example.com/tfp/common/policy", authority.absoluteString);
         XCTAssertEqualObjects(@"https://example.com/tfp/common/policy/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - discoverAuthority, AAD

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsKnown_shouldReturnNormalizedAuthorityErrorNil
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [NSHTTPURLResponse new];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://login.microsoftonline.com/common/oauth2/authorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
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
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsNotKnown_shouldReturnNormalizedAuthorityErrorNil
{
    __auto_type authority = [@"https://example.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [NSHTTPURLResponse new];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://example.com/common/oauth2/authorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
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
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://example.com/common", authority.absoluteString);
         XCTAssertEqualObjects(@"https://example.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenSent2Times_shouldUseCacheFor2ndRequest
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [NSHTTPURLResponse new];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://login.microsoftonline.com/common/oauth2/authorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
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
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // 2nd request
    expectation = [self expectationWithDescription:@"Get Authority Info From Cache"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenSent2TimesAnd1stResponseWasWithError_shouldNotUseCacheFor2ndRequest
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://login.microsoftonline.com/common/oauth2/authorize" msidUrl];
    __auto_type error = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:nil];
    
    MSIDTestURLResponse *responseWithError = [MSIDTestURLResponse request:requestUrl
                                                         respondWithError:error];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
    responseWithError->_requestHeaders = headers;
    [MSIDTestURLSession addResponse:responseWithError];
    
    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(authority.absoluteString);
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    __auto_type httpResponse = [NSHTTPURLResponse new];
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
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common", authority.absoluteString);
         XCTAssertEqualObjects(@"https://login.microsoftonline.com/common/.well-known/openid-configuration", openIdConfigurationEndpoint.absoluteString);
         XCTAssertTrue(validated);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthorityIsAADValidateYesAuthroityIsInvalid_shouldReturnError
{
    __auto_type authority = [@"https://example.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [NSHTTPURLResponse new];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://example.com/common/oauth2/authorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"error" : @"invalid_instance"};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(authority.absoluteString);
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDiscoverAuthority_whenAuthroityIsInvalid_shoulStoreInvalidRecordInCache
{
    __auto_type authority = [@"https://example.com/common/qwe" msidUrl];
    __auto_type upn = @"user@microsoft.com";
    __auto_type httpResponse = [NSHTTPURLResponse new];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https://example.com/common/oauth2/authorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
    response->_requestHeaders = headers;
    __auto_type responseJson = @{@"error" : @"invalid_instance"};
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
    
    // 1st request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Discover AAD Authority"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(authority.absoluteString);
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1222 handler:nil];
    
    // 2nd request (no network call should happen)
    expectation = [self expectationWithDescription:@"Read Invalid Authority From Cache"];
    [MSIDAuthority discoverAuthority:authority
                   userPrincipalName:upn
                            validate:YES
                             context:nil
                     completionBlock:^(NSURL *authority, NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         XCTAssertNil(authority.absoluteString);
         XCTAssertNil(openIdConfigurationEndpoint.absoluteString);
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1222 handler:nil];
}

@end
