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

#import "XCTest/XCTest.h"
#import "MSIDNonceTokenRequestMock.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestURLResponse.h"
#import "MSIDCache.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDAADAuthority.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADNetworkConfiguration.h"

@interface MSIDNonceTokenRequestTest: XCTestCase
@end

@implementation MSIDNonceTokenRequestTest

- (void)setUp
{
    [super setUp];
    MSIDCache *nonceCache = [MSIDNonceTokenRequest.class nonceCache];
    [nonceCache removeAllObjects];
    [MSIDTestURLSession clearResponses];
}

-(void)tearDown
{
    [super tearDown];
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:nil forKey:@"aadApiVersion"];
    [MSIDTestURLSession clearResponses];
    [MSIDAuthority.openIdConfigurationCache removeAllObjects];
}

- (void)testExecuteRequestWithCompletion_whenCachedNonceExists_shouldReturnCachedNonce
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"my-nonce"];
    MSIDCache *nonceCache = [MSIDNonceTokenRequest.class nonceCache];
    [nonceCache setObject:cachedNonce forKey:parameters.authority.environment];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Return cached Nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertEqualObjects(resultNonce, @"my-nonce");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}


- (void)testExecuteRequestWithCompletion_whenNoCachedNonceExists_shouldGetNonceAndCacheIt
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                              reponse:httpResponse];
    
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    
    __auto_type nonceResponseJson = @{
        @"Nonce": @"1234_nonce_abcd"
    };
    
    [nonceResponse setResponseJSON:nonceResponseJson];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire Nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNotNil(resultNonce);
        XCTAssertNil(error);
        XCTAssertEqualObjects(resultNonce, @"1234_nonce_abcd");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    MSIDCache *nonceCache = [MSIDNonceTokenRequest.class nonceCache];
    XCTAssertNotNil(nonceCache);
    MSIDCachedNonce *cachedNonce = [nonceCache objectForKey:parameters.authority.environment];
    XCTAssertEqualObjects(cachedNonce.nonce, @"1234_nonce_abcd");
}

- (void)testExecuteRequestWithCompletion_whenNoCachedNonceExists_whenNonceResponseReturnsError
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    NSError *nonceError = [[NSError alloc] initWithDomain:@"Test domain" code:-1 userInfo:@{@"MSIDErrorDescriptionKey": @"Could not get nonce from server."}];
    
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                     respondWithError:nonceError];
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire Nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(resultNonce);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Could not get nonce from server.");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecuteRequestWithCompletion_whenNoCachedNonceExists_InvalidNonceObtainedFromServer
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                              reponse:httpResponse];
    
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    
    __auto_type nonceResponseJson = @{};
    
    [nonceResponse setResponseJSON:nonceResponseJson];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire Nonce for invalid nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(resultNonce);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Didn't receive valid nonce in response");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [nonceResponse setResponseJSON:@[]];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Acquire Nonce for invalid nonce."];
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(resultNonce);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Response is not of the expected type: NSDictionary.");
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [nonceResponse setResponseJSON:@{@"nonce": @""}];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Acquire Nonce for invalid nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(resultNonce);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.userInfo[@"MSIDErrorDescriptionKey"], @"Didn't receive valid nonce in response");
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecuteRequestWithCompletion_whenExpiredCachedNonce_shouldGetNewNonceAndCacheIt
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"my-nonce"];
    [cachedNonce setValue:[[NSDate new] dateByAddingTimeInterval:-200] forKey:@"cachedDate"]; // Expired nonce
    MSIDCache *nonceCache = [MSIDNonceTokenRequest.class nonceCache];
    [nonceCache setObject:cachedNonce forKey:parameters.authority.environment];
    
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                              reponse:httpResponse];
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    
    __auto_type nonceResponseJson = @{
        @"Nonce": @"1234_nonce_abcd"
    };
    
    [nonceResponse setResponseJSON:nonceResponseJson];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire new Nonce."];
    
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertEqualObjects(resultNonce, @"1234_nonce_abcd");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    MSIDCachedNonce *newCachedNonce = [nonceCache objectForKey:parameters.authority.environment];
    XCTAssertEqualObjects(newCachedNonce.nonce, @"1234_nonce_abcd");
}

- (void)testExecuteRequestWithCompletion_whenCachedNonceSetInFuture_shouldGetNewNonceAndCacheIt
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    
    MSIDCachedNonce *cachedNonce = [[MSIDCachedNonce alloc] initWithNonce:@"my-nonce"];
    [cachedNonce setValue:[[NSDate new] dateByAddingTimeInterval:300] forKey:@"cachedDate"]; // Nonce incorrectly cached in the future
    MSIDCache *nonceCache = [MSIDNonceTokenRequest.class nonceCache];
    [nonceCache setObject:cachedNonce forKey:parameters.authority.environment];
    
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                              reponse:httpResponse];
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    
    __auto_type nonceResponseJson = @{
        @"Nonce": @"1234_nonce_abcd"
    };
    
    [nonceResponse setResponseJSON:nonceResponseJson];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequest *request = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:parameters];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire new Nonce."];
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertEqualObjects(resultNonce, @"1234_nonce_abcd");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    MSIDCachedNonce *newCachedNonce = [nonceCache objectForKey:parameters.authority.environment];
    XCTAssertEqualObjects(newCachedNonce.nonce, @"1234_nonce_abcd");
}

- (void)testExecuteRequestWithCompletion_whenOpenIdMetadataIsNotLoaded
{
    MSIDInteractiveTokenRequestParameters *parameters = [self testRequestParameters];
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    MSIDTestURLResponse *nonceResponse = [MSIDTestURLResponse request:parameters.authority.metadata.tokenEndpoint
                                                              reponse:httpResponse];
    
    nonceResponse->_requestHeaders = [self mockedRequestHeaders];
    
    __auto_type nonceResponseJson = @{
        @"Nonce": @"1234_nonce_abcd"
    };
    
    [MSIDAADNetworkConfiguration.defaultConfiguration setValue:@"v2.0" forKey:@"aadApiVersion"];
    
    [nonceResponse setResponseJSON:nonceResponseJson];
    [MSIDTestURLSession addResponse:nonceResponse];
    
    MSIDNonceTokenRequestMock *request = [[MSIDNonceTokenRequestMock alloc] initWithRequestParameters:parameters];
    request.openIdMetadataToUpdateInAuthority = parameters.authority.metadata;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire new Nonce."];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:parameters.authority.url.absoluteString];
    discoveryResponse.requestHeaders = [self mockedRequestHeaders];
    [MSIDTestURLSession addResponse:discoveryResponse];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:parameters.authority.url.absoluteString];
    oidcResponse.requestHeaders = [self mockedRequestHeaders];
    [MSIDTestURLSession addResponse:oidcResponse];
    
    request.openIdMetadataToUpdateInAuthority.tokenEndpoint = nil;
    [request executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        XCTAssertNil(error);
        XCTAssertEqualObjects(resultNonce, @"1234_nonce_abcd");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Utils

- (MSIDInteractiveTokenRequestParameters *)testRequestParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/1234567"]
                                                       rawTenant:nil
                                                         context:nil
                                                           error:nil];
    parameters.authority.metadata = [MSIDOpenIdProviderMetadata new];
    parameters.authority.metadata.tokenEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/1234567/oauth2/v2.0/token"];
    parameters.providedAuthority = parameters.authority;
    parameters.clientId = @"29d9ed98-a469-4536-ade2-f981bc1d605e";
    parameters.redirectUri = @"redirect_uri";
    return parameters;
}

- (NSMutableDictionary *)mockedRequestHeaders
{
    NSDictionary *requestHeaders =
    @{
            @"Accept" : [[MSIDTestIgnoreSentinel alloc] init],
            @"Content-Length" : [[MSIDTestIgnoreSentinel alloc] init],
            @"Content-Type" : [[MSIDTestIgnoreSentinel alloc] init],
            @"User-Agent" : [[MSIDTestIgnoreSentinel alloc] init],
            @"x-client-SKU": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-client-OS": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-app-name": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-ms-PkeyAuth+": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-client-Ver": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-client-CPU": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-app-ver": [[MSIDTestIgnoreSentinel alloc] init],
            @"x-client-DM": [[MSIDTestIgnoreSentinel alloc] init],
            @"Connection": [MSIDTestIgnoreSentinel sentinel],
    };
    
    return [requestHeaders mutableCopy];
}
@end
