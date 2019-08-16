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
#import "MSIDExternalAADCacheSeeder.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDV1IdToken.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDTestURLResponse.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse+Util.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAggregatedDispatcher.h"
#import "MSIDTestTelemetryEventsObserver.h"
#import "MSIDTelemetry+Internal.h"

@interface MSIDExternalAADCacheSeederIntegrationTests : XCTestCase

@property (nonatomic) MSIDTestCacheDataSource *externalLegacyDataSource;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *externalLegacyAccessor;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents;
@property (nonatomic) MSIDAggregatedDispatcher *dispatcher;
@property (nonatomic) MSIDTestTelemetryEventsObserver *observer;

@end

@implementation MSIDExternalAADCacheSeederIntegrationTests

- (void)setUp
{
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new]
                                                                 otherCacheAccessors:nil];
    self.externalLegacyDataSource = [MSIDTestCacheDataSource new];
    self.externalLegacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:self.externalLegacyDataSource
                                                                       otherCacheAccessors:nil];
    
    self.receivedEvents = [NSMutableArray array];
    
    __auto_type observer = [MSIDTestTelemetryEventsObserver new];
    [observer setEventsReceivedBlock:^(NSArray<NSDictionary<NSString *, NSString *> *> *events)
     {
         self.receivedEvents = events;
     }];
    self.dispatcher = [[MSIDAggregatedDispatcher alloc] initWithObserver:observer];
    self.observer = observer;
    
    [[MSIDTelemetry sharedInstance] addDispatcher:self.dispatcher];
    
    [MSIDTelemetry sharedInstance].piiEnabled = NO;
    MSIDTelemetry.sharedInstance.notifyOnFailureOnly = NO;
}

- (void)tearDown
{
    [self.externalLegacyDataSource reset];
    
    [[MSIDTelemetry sharedInstance] removeAllDispatchers];
    self.receivedEvents = nil;
    self.observer = nil;
    self.dispatcher = nil;
}

#pragma mark - Tests

- (void)testSeedv2TokenResponse_whenNoLegacyIdTokenInCache_shouldGetLecayIdTokenFromServerAndSeedTokenResponse
{
    __auto_type seeder = [[MSIDExternalAADCacheSeeder alloc] initWithDefaultAccessor:self.defaultAccessor
                                                              externalLegacyAccessor:self.externalLegacyAccessor];
    
    // Create v2 token response.
    NSString *clientInfoRaw = [@{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSDictionary *jsonInput = @{
                                @"access_token": @"at",
                                @"client_info": clientInfoRaw,
                                @"expires_in": @599,
                                @"ext_expires_in": @599,
                                @"foci": @1,
                                @"id_token": [MSIDTestIdTokenUtil defaultV2IdToken],
                                @"refresh_token": @"rt",
                                @"scope": @"scope1 scope2",
                                };
    __auto_type tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:nil];
    
    // Create factory.
    __auto_type factory = [MSIDAADV2Oauth2Factory new];
    
    // Create request parameters.
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    metadata.tokenEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/token"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    authority.metadata = metadata;
    __auto_type redirectUri = @"myapp://com.example";
    __auto_type clientId = @"some id";
    __auto_type scopes = [[NSOrderedSet alloc] initWithArray:@[@"scope1", @"scope2"]];
    __auto_type oidcScopes = [[NSOrderedSet alloc] initWithArray:@[@"openid", @"profile", @"offline_access"]];
    __auto_type requestParameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                         redirectUri:redirectUri
                                                                            clientId:clientId
                                                                              scopes:scopes
                                                                          oidcScopes:oidcScopes
                                                                       correlationId:nil
                                                                      telemetryApiId:nil
                                                                 intuneAppIdentifier:nil
                                                                               error:nil];
    // Mock network request to token endpoint.
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
    headers[@"Content-Type"] = @"application/x-www-form-urlencoded";
    headers[@"x-app-name"] = [MSIDTestRequireValueSentinel sentinel];
    headers[@"x-app-ver"] = [MSIDTestRequireValueSentinel sentinel];
    headers[@"client-request-id"] = [MSIDTestRequireValueSentinel sentinel];
    headers[@"return-client-request-id"] = @"true";
    NSMutableDictionary *requestBody = [@{
                                          @"client_id": @"some id",
                                          @"client_info": @"1",
                                          @"grant_type": @"refresh_token",
                                          @"refresh_token": @"rt",
                                          @"scope": @"scope1 scope2 openid profile offline_access"
                                          } mutableCopy];
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/token"
                           requestHeaders:headers
                        requestParamsBody:requestBody
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:jsonInput];
    [MSIDTestURLSession addResponse:response];
    
    // Seed token response.
    XCTestExpectation *expectation = [self expectationWithDescription:@"Seed Token Response."];
    [seeder seedTokenResponse:tokenResponse factory:factory requestParameters:requestParameters completionBlock:^{
        __auto_type tokens = [self.externalLegacyDataSource allLegacyRefreshTokens];
        XCTAssertEqual(tokens.count, 1);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [[MSIDTelemetry sharedInstance] flush:[requestParameters telemetryRequestId]];
    
    XCTAssertNotNil(self.receivedEvents);
    XCTAssertEqual(self.receivedEvents.count, 1);
    NSDictionary *eventInfo = self.receivedEvents.firstObject;
    XCTAssertEqual(eventInfo.count, 12);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.cache_event_count"], @4);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.get_v1_id_token_http_event_count"], @1);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.http_event_count"], @1);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.oauth_error_code"], @"");
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.response_code"], @"200");
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.correlation_id"]);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.external_cache_seeding_status"], @"yes");
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.request_id"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_ver"]);
}

- (void)testSeedv2TokenResponse_whenLegacyIdTokenInCache_shouldGetLecayIdTokenFromCacheAndSeedTokenResponse
{
    __auto_type seeder = [[MSIDExternalAADCacheSeeder alloc] initWithDefaultAccessor:self.defaultAccessor
                                                              externalLegacyAccessor:self.externalLegacyAccessor];
    
    // Create v2 token response.
    NSString *clientInfoRaw = [@{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    NSDictionary *jsonInput = @{
                                @"access_token": @"at",
                                @"client_info": clientInfoRaw,
                                @"expires_in": @599,
                                @"ext_expires_in": @599,
                                @"foci": @1,
                                @"id_token": [MSIDTestIdTokenUtil defaultV2IdToken],
                                @"refresh_token": @"rt",
                                @"scope": @"scope1 scope2",
                                };
    __auto_type tokenResponse = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:nil];
    
    // Create factory.
    __auto_type factory = [MSIDAADV2Oauth2Factory new];
    
    // Create request parameters.
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    metadata.tokenEndpoint = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common/oauth2/token"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:nil context:nil error:nil];
    authority.metadata = metadata;
    __auto_type redirectUri = @"myapp://com.example";
    __auto_type clientId = @"some id";
    __auto_type scopes = [[NSOrderedSet alloc] initWithArray:@[@"scope1", @"scope2"]];
    __auto_type oidcScopes = [[NSOrderedSet alloc] initWithArray:@[@"openid", @"profile", @"offline_access"]];
    __auto_type requestParameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                         redirectUri:redirectUri
                                                                            clientId:clientId
                                                                              scopes:scopes
                                                                          oidcScopes:oidcScopes
                                                                       correlationId:nil
                                                                      telemetryApiId:nil
                                                                 intuneAppIdentifier:nil
                                                                               error:nil];
    
    // Save v1 id token.
    __auto_type legacyIdToken = [MSIDV1IdToken new];
    legacyIdToken.clientId = @"some id";
    legacyIdToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                             homeAccountId:@"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.1234-5678-90abcdefg"];
    legacyIdToken.storageEnvironment = @"login.microsoftonline.com";
    legacyIdToken.environment = @"login.microsoftonline.com";
    legacyIdToken.realm = @"1234-5678-90abcdefg";
    legacyIdToken.rawIdToken = [MSIDTestIdTokenUtil defaultV1IdToken];
    BOOL result = [self.defaultAccessor saveToken:legacyIdToken context:requestParameters error:nil];
    XCTAssertTrue(result);
    
    // Seed token response.
    XCTestExpectation *expectation = [self expectationWithDescription:@"Seed Token Response."];
    [seeder seedTokenResponse:tokenResponse factory:factory requestParameters:requestParameters completionBlock:^{
        __auto_type tokens = [self.externalLegacyDataSource allLegacyRefreshTokens];
        XCTAssertEqual(tokens.count, 1);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [[MSIDTelemetry sharedInstance] flush:[requestParameters telemetryRequestId]];
    
    XCTAssertNotNil(self.receivedEvents);
    XCTAssertEqual(self.receivedEvents.count, 1);
    NSDictionary *eventInfo = self.receivedEvents.firstObject;
    XCTAssertEqual(eventInfo.count, 9);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.cache_event_count"], @4);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.get_v1_id_token_cache_event_count"], @1);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.correlation_id"]);
    XCTAssertEqualObjects(eventInfo[@"Microsoft.Test.external_cache_seeding_status"], @"yes");
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.request_id"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"Microsoft.Test.x_client_ver"]);
}

@end
