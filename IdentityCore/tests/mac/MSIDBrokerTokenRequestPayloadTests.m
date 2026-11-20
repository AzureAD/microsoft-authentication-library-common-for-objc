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
#import "MSIDBrokerTokenRequest.h"
#import "MSIDDefaultBrokerTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDBrokerConstants.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDVersion.h"
#import "NSURL+MSIDExtensions.h"
#import "NSString+MSIDTestUtil.h"

@interface MSIDBrokerTokenRequestPayloadTests : XCTestCase

@property (nonatomic) MSIDIntuneEnrollmentIdsCache *originalEnrollmentCache;
@property (nonatomic) MSIDIntuneMAMResourcesCache *originalResourceCache;

@end

@implementation MSIDBrokerTokenRequestPayloadTests

- (void)setUp
{
    [super setUp];
    self.originalEnrollmentCache = MSIDIntuneEnrollmentIdsCache.sharedCache;
    self.originalResourceCache = MSIDIntuneMAMResourcesCache.sharedCache;
    MSIDIntuneEnrollmentIdsCache.sharedCache =
    [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:[MSIDIntuneInMemoryCacheDataSource new]];
    MSIDIntuneMAMResourcesCache.sharedCache =
    [[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:[MSIDIntuneInMemoryCacheDataSource new]];
}

- (void)tearDown
{
    MSIDIntuneEnrollmentIdsCache.sharedCache = self.originalEnrollmentCache;
    MSIDIntuneMAMResourcesCache.sharedCache = self.originalResourceCache;
    [super tearDown];
}

- (MSIDInteractiveTokenRequestParameters *)parameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    parameters.clientId = @"client-with-special&characters";
    parameters.target = @"user.read tasks.read";
    parameters.redirectUri = @"my-redirect://com.microsoft.test/callback";
    parameters.correlationId = [NSUUID UUID];
    parameters.clientSku = MSID_CLIENT_SKU_MSAL_OSX;
    parameters.brokerInvocationOptions =
    [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault
                                                     protocolType:MSIDBrokerProtocolTypeCustomScheme
                                                aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    return parameters;
}

- (void)testMacPayload_roundTripsEscapedIdentityAndOmitsIOSKeychainAndNonceFields
{
    MSIDInteractiveTokenRequestParameters *parameters = [self parameters];
    NSError *error = nil;
    MSIDBrokerTokenRequest *request =
    [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"unused-ios-key"
                                     brokerApplicationToken:@"application-token" sdkCapabilities:@[@"one", @"two"] error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    NSDictionary *query = request.brokerRequestURL.msidQueryParameters;
    XCTAssertEqualObjects(query[@"client_id"], parameters.clientId);
    XCTAssertEqualObjects(query[@"redirect_uri"], parameters.redirectUri);
    XCTAssertEqualObjects(query[@"authority"], parameters.authority.url.absoluteString);
    XCTAssertEqualObjects(query[@"correlation_id"], parameters.correlationId.UUIDString);
    XCTAssertEqualObjects(query[@"client_sku"], MSID_CLIENT_SKU_MSAL_OSX);
    XCTAssertEqualObjects(query[@"sdk_broker_capabilities"], @"one,two");
    XCTAssertEqualObjects(query[@"application_token"], @"application-token");
    XCTAssertNil(query[@"broker_key"]);
    XCTAssertNil(query[@"broker_nonce"]);
    XCTAssertNil(query[MSID_BOUND_RT_REDEEM]);
    XCTAssertEqualObjects(request.resumeDictionary[@"client_id"], parameters.clientId);
    XCTAssertEqualObjects(request.resumeDictionary[@"redirect_uri"], parameters.redirectUri);
    XCTAssertNil(request.resumeDictionary[@"keychain_group"]);
    XCTAssertNil(request.resumeDictionary[@"broker_nonce"]);
}

- (void)testMissingRequiredParameters_returnsDeveloperErrorWithoutPartialRequest
{
    for (NSString *key in @[@"authority", @"target", @"clientId", @"redirectUri", @"correlationId"])
    {
        MSIDInteractiveTokenRequestParameters *parameters = [self parameters];
        [parameters setValue:nil forKey:key];
        NSError *error = nil;
        MSIDBrokerTokenRequest *request =
        [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"unused-ios-key"
                                         brokerApplicationToken:@"application-token" sdkCapabilities:nil error:&error];
        XCTAssertNil(request, @"%@", key);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
        XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:key]);
    }
}

- (void)testMissingBrokerKey_returnsDeveloperErrorAndSupportsNullErrorPointer
{
    NSError *error = nil;
    NSString *missingKey = nil;
    MSIDBrokerTokenRequest *request =
    [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:[self parameters] brokerKey:missingKey
                                     brokerApplicationToken:@"application-token" sdkCapabilities:nil error:&error];
    XCTAssertNil(request);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"brokerKey"]);
    XCTAssertNil([[MSIDBrokerTokenRequest alloc] initWithRequestParameters:[self parameters] brokerKey:missingKey
                                                  brokerApplicationToken:@"application-token" sdkCapabilities:nil error:nil]);
}

- (void)testNestedPopPayload_preservesSchemeAndBrokerIdentityInResumeState
{
    MSIDInteractiveTokenRequestParameters *parameters = [self parameters];
    parameters.nestedAuthBrokerClientId = @"nested-client";
    parameters.nestedAuthBrokerRedirectUri = @"nested-redirect://callback";
    NSString *confirmation = @"eyJraWQiOiJlQWkyNE9leml1czc5VlRadDhsZlhldFJTejdsR2thSmloWEJFWkIwMnV3In0";
    parameters.authScheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:@{@"token_type": @"Pop",
                                                                                          @"req_cnf": confirmation}];
    XCTAssertNotNil(parameters.authScheme);
    NSError *error = nil;
    MSIDBrokerTokenRequest *request =
    [[MSIDBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"unused-ios-key"
                                     brokerApplicationToken:@"application-token" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    NSDictionary *query = request.brokerRequestURL.msidQueryParameters;
    for (NSDictionary *contents in @[query, request.resumeDictionary])
    {
        XCTAssertEqualObjects(contents[@"token_type"], @"Pop");
        XCTAssertEqualObjects(contents[@"req_cnf"], confirmation);
        XCTAssertEqualObjects(contents[MSID_NESTED_AUTH_BROKER_CLIENT_ID], @"nested-client");
        XCTAssertEqualObjects(contents[MSID_NESTED_AUTH_BROKER_REDIRECT_URI], @"nested-redirect://callback");
    }
}

- (void)testDefaultBrokerPayload_includesFederatedCredentialButOmitsAbsentOptionalValues
{
    MSIDInteractiveTokenRequestParameters *parameters = [self parameters];
    parameters.userFederatedIdentityToken = @"federated&credential=one";
    NSError *error = nil;
    MSIDDefaultBrokerTokenRequest *request =
    [[MSIDDefaultBrokerTokenRequest alloc] initWithRequestParameters:parameters brokerKey:@"unused-ios-key"
                                            brokerApplicationToken:@"application-token" sdkCapabilities:nil error:&error];
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    NSDictionary *query = request.brokerRequestURL.msidQueryParameters;
    XCTAssertEqualObjects(query[@"x-ms-UserFederatedIdentityCredential"], parameters.userFederatedIdentityToken);
    XCTAssertNil(query[@"sdk_broker_capabilities"]);
    XCTAssertNil(query[@"claims"]);
    XCTAssertNil(query[MSID_NESTED_AUTH_BROKER_CLIENT_ID]);
    XCTAssertNil(query[MSID_NESTED_AUTH_BROKER_REDIRECT_URI]);
}

@end
