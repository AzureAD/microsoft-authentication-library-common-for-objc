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
#import "MSIDInteractiveTokenRequestParameters.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTestIdentifiers.h"

@interface MSIDInteractiveTokenRequestParametersTests : XCTestCase

@end

@implementation MSIDInteractiveTokenRequestParametersTests

- (void)testInitWithAllSupportedParameters_shouldInitialize_returnNilError_Popflow
{
    [self testInitWithAllSupportedParameters_shouldInitialize_returnNilError:[MSIDAuthenticationSchemePop new]];
}

- (void)testInitWithAllSupportedParameters_shouldInitialize_returnNilError_Bearerflow
{
    [self testInitWithAllSupportedParameters_shouldInitialize_returnNilError:[MSIDAuthenticationScheme new]];
}

- (void)testInitWithAllSupportedParameters_shouldInitialize_returnNilError:(MSIDAuthenticationScheme *)authScheme
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSUUID *correlationID = [NSUUID UUID];
    
    NSError *error = nil;
    
    MSIDBrokerInvocationOptions *brokerOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:MSIDRequiredBrokerTypeDefault protocolType:MSIDBrokerProtocolTypeCustomScheme aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:authScheme
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:[@"openid openid2" msidScopeSet]
                                                                                          extraScopesToConsent:[@"extra extra2" msidScopeSet]
                                                                                                 correlationId:correlationID
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:brokerOptions
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:&error];
    
    XCTAssertNotNil(parameters);
    XCTAssertEqualObjects(parameters.authority, authority);
    XCTAssertEqualObjects(parameters.redirectUri, @"redirect");
    XCTAssertEqualObjects(parameters.clientId, @"clientid");
    XCTAssertEqualObjects(parameters.target, @"scope scope2");
    XCTAssertEqualObjects(parameters.oidcScope, @"openid openid2");
    XCTAssertEqualObjects(parameters.extraScopesToConsent, @"extra extra2");
    XCTAssertEqualObjects(parameters.correlationId, correlationID);
    XCTAssertEqualObjects(parameters.telemetryApiId, @"100");
    XCTAssertEqual(parameters.brokerInvocationOptions.minRequiredBrokerType, MSIDRequiredBrokerTypeDefault);
    XCTAssertEqual(parameters.brokerInvocationOptions.protocolType, MSIDBrokerProtocolTypeCustomScheme);
    XCTAssertEqual(parameters.brokerInvocationOptions.brokerAADRequestVersion, MSIDBrokerAADRequestVersionV2);
    XCTAssertEqual(parameters.requestType, MSIDRequestBrokeredType);
    XCTAssertEqual(parameters.authScheme, authScheme);

    XCTAssertNil(error);
}

- (void)testAllAuthorizeRequestScopes_whenOnlyResourceScopesProvided_shouldReturnResourceScopesOnly
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:nil
                                                                                          extraScopesToConsent:nil
                                                                                                 correlationId:nil
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:[MSIDBrokerInvocationOptions new] 
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:nil];
    
    NSOrderedSet *allScopes = [parameters allAuthorizeRequestScopes];
    XCTAssertEqualObjects([@"scope scope2" msidScopeSet], allScopes);
    
}

- (void)testAllAuthorizeRequestScopes_whenBothResourceAndOIDCScopesProvided_shouldReturnAllScopesCombined
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:[@"openid openid2" msidScopeSet]
                                                                                          extraScopesToConsent:nil
                                                                                                 correlationId:nil
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:[MSIDBrokerInvocationOptions new]
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:nil];
    
    NSOrderedSet *allScopes = [parameters allAuthorizeRequestScopes];
    XCTAssertEqualObjects([@"scope scope2 openid openid2" msidScopeSet], allScopes);
}

- (void)testAllAuthorizeRequestScopes_whenResource_AndOIDCS_AndExtraScopesProvided_shouldReturnAllScopesCombined
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:[@"openid openid2" msidScopeSet]
                                                                                          extraScopesToConsent:[@"extra1 extra5" msidScopeSet]
                                                                                                 correlationId:nil
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:[MSIDBrokerInvocationOptions new]
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:nil];
    
    NSOrderedSet *allScopes = [parameters allAuthorizeRequestScopes];
    XCTAssertEqualObjects([@"scope scope2 openid openid2 extra1 extra5" msidScopeSet], allScopes);
}

- (void)testAllAuthorizeRequestParameters_whenNoExtraParameters_shouldReturnAppMetaDataParams
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
     XCTAssertEqualObjects(eqp, parameters.appRequestMetadata);
}

- (void)testAllAuthorizeRequestParameters_whenOnlyAuthorizeParameters_shouldReturnAuthorizeParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.appRequestMetadata = nil;
    NSDictionary *authorizeEndpointParameters = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraAuthorizeURLQueryParameters = authorizeEndpointParameters;
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    XCTAssertEqualObjects(eqp, authorizeEndpointParameters);
}

- (void)testAllAuthorizeRequestParameters_whenOnlyTokenParameters_shouldReturnTokenParameters
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.appRequestMetadata = nil;
    NSDictionary *additionalParams = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraURLQueryParameters = additionalParams;
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    XCTAssertEqualObjects(eqp, additionalParams);
}

- (void)testAllAuthorizeRequestParameters_whenBothAuthorizeAndTokenParameters_shouldReturnAllParametersCombined
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    parameters.appRequestMetadata = nil;
    NSDictionary *authorizeEndpointParameters = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraAuthorizeURLQueryParameters = authorizeEndpointParameters;
    parameters.extraURLQueryParameters = @{@"add1": @"val1", @"add2": @"val2"};
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    NSDictionary *expectedParams = @{@"eqp1": @"val1", @"eqp2": @"val2", @"add1": @"val1", @"add2": @"val2"};
    XCTAssertEqualObjects(eqp, expectedParams);
}

- (void)testAllAuthorizeRequestParameters_whenOnlyAuthorizeParametersAndAppMetadata_shouldReturnAuthorizeParametersAndAppMetadata
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    NSDictionary *authorizeEndpointParameters = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraAuthorizeURLQueryParameters = authorizeEndpointParameters;
    NSMutableDictionary *combinedParameters = [NSMutableDictionary new];
    [combinedParameters addEntriesFromDictionary:parameters.appRequestMetadata];
    [combinedParameters addEntriesFromDictionary:authorizeEndpointParameters];
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    XCTAssertEqualObjects(eqp, combinedParameters);
}

- (void)testAllAuthorizeRequestParameters_whenOnlyTokenParametersAndAppMetadata_shouldReturnTokenParametersAndAppMetadata
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    NSDictionary *tokenParameters = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraURLQueryParameters = tokenParameters;
    NSMutableDictionary *combinedParameters = [NSMutableDictionary new];
    [combinedParameters addEntriesFromDictionary:parameters.appRequestMetadata];
    [combinedParameters addEntriesFromDictionary:tokenParameters];
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    XCTAssertEqualObjects(eqp, combinedParameters);
}

- (void)testAllAuthorizeRequestParameters_whenAllAuthorizeAndTokenParametersAndAppMetadata_shouldReturnAllParametersCombined
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters new];
    NSDictionary *authorizeEndpointParameters = @{@"eqp1": @"val1", @"eqp2": @"val2"};
    parameters.extraAuthorizeURLQueryParameters = authorizeEndpointParameters;
    NSDictionary *tokenParameters = @{@"add1": @"val1", @"add2": @"val2"};
    parameters.extraURLQueryParameters = tokenParameters;
    NSMutableDictionary *combinedParameters = [NSMutableDictionary new];
    [combinedParameters addEntriesFromDictionary:parameters.appRequestMetadata];
    [combinedParameters addEntriesFromDictionary:authorizeEndpointParameters];
    [combinedParameters addEntriesFromDictionary:tokenParameters];
    
    NSDictionary *eqp = [parameters allAuthorizeRequestExtraParametersWithMetadata:YES];
    XCTAssertNotNil(eqp);
    XCTAssertEqualObjects(eqp, combinedParameters);
}

- (void)testUpdateAppRequestMetadata_whenLoginHintIsNotNilAndNoCSSHint_shouldSetCSSHint
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSError *error = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:[@"openid openid2" msidScopeSet]
                                                                                          extraScopesToConsent:[@"extra1 extra5" msidScopeSet]
                                                                                                 correlationId:nil
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:[MSIDBrokerInvocationOptions new]
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:nil];
    parameters.loginHint = @"user2@contoso.com";
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"UPN:user2@contoso.com");
}

- (void)testUpdateAppRequestMetadata_whenLoginHintIsNotNilAndAccountIdIsAvailable_shouldSetAccountIdAsCSSHint
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSError *error = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                                                   redirectUri:@"redirect"
                                                                                                      clientId:@"clientid"
                                                                                                        scopes:[@"scope scope2" msidScopeSet]
                                                                                                    oidcScopes:[@"openid openid2" msidScopeSet]
                                                                                          extraScopesToConsent:[@"extra1 extra5" msidScopeSet]
                                                                                                 correlationId:nil
                                                                                                telemetryApiId:@"100"
                                                                                                 brokerOptions:[MSIDBrokerInvocationOptions new]
                                                                                                   requestType:MSIDRequestBrokeredType
                                                                                           intuneAppIdentifier:@"com.microsoft.mytest"
                                                                                                         error:nil];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    parameters.loginHint = @"user2@contoso.com";
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"Oid:fedcba98-7654-3210-0000-000000000000@00000000-0000-1234-5678-90abcdefffff");
}

@end
