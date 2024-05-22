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
#import "MSIDTestIdentifiers.h"
#import "MSIDRequestParameters.h"
#import "MSIDVersion.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDAuthenticationSchemeSshCert.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDRequestParametersTests : XCTestCase

@end

@implementation MSIDRequestParametersTests


- (void )testInitParameters_withValidParameters_shouldInitReturnNonNil
{
    [self testInitParameters_withValidParameters_shouldInitReturnNonNil_withAuthScheme:[MSIDAuthenticationScheme new]];
    [self testInitParameters_withValidParameters_shouldInitReturnNonNil_withAuthScheme:[MSIDAuthenticationSchemePop new]];
    [self testInitParameters_withValidParameters_shouldInitReturnNonNil_withAuthScheme:[MSIDAuthenticationSchemeSshCert new]];
}

- (void)testInitParameters_withValidParameters_shouldInitReturnNonNil_withAuthScheme:(MSIDAuthenticationScheme *)authScheme
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:authScheme
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqualObjects(parameters.authority, authority);
    XCTAssertEqualObjects(parameters.redirectUri, @"myredirect");
    XCTAssertEqualObjects(parameters.clientId, @"myclient_id");
    XCTAssertEqualObjects(parameters.target, @"myscope1 myscope2");
    XCTAssertEqualObjects(parameters.oidcScope, @"openid offline_access profile");
    XCTAssertNotNil(parameters.correlationId);
    XCTAssertNotNil(parameters.telemetryRequestId);
    XCTAssertEqualObjects(parameters.logComponent, [MSIDVersion sdkName]);
    XCTAssertNotNil(parameters.appRequestMetadata);
    XCTAssertEqualObjects(parameters.intuneApplicationIdentifier, @"com.microsoft.mytest");
    XCTAssertEqualObjects(parameters.authScheme, authScheme);
}
- (void)testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil_withAuthScheme
{
    [self testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil_withAuthScheme:[MSIDAuthenticationScheme new]];
    [self testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil_withAuthScheme:[MSIDAuthenticationSchemePop new]];
    [self testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil_withAuthScheme:[MSIDAuthenticationSchemeSshCert new]];
}

- (void)testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil_withAuthScheme:(MSIDAuthenticationScheme *)authScheme
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", @"offline_access", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:authScheme
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertNil(parameters);
}

- (void)testInitParameters_withClientIdAsScope_andAADAuthority_shouldFailAndReturnNil
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", @"myclient_id", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertNil(parameters);
}

- (void)testInitParameters_withClientIdAsScope_andB2CAuthority_shouldInitReturnNonNil
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/tfp/contoso.com/B2C_1_Signin" b2cAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", @"myclient_id", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqualObjects(parameters.authority, authority);
    XCTAssertEqualObjects(parameters.redirectUri, @"myredirect");
    XCTAssertEqualObjects(parameters.clientId, @"myclient_id");
    XCTAssertEqualObjects(parameters.target, @"myscope1 myscope2 myclient_id");
    XCTAssertEqualObjects(parameters.oidcScope, @"openid offline_access profile");
    XCTAssertNotNil(parameters.correlationId);
    XCTAssertNotNil(parameters.telemetryRequestId);
    XCTAssertEqualObjects(parameters.logComponent, [MSIDVersion sdkName]);
    XCTAssertNotNil(parameters.appRequestMetadata);
}

- (void)testUpdateAppRequestMetadata_whenAccountIdIsNil_shouldNotChangeMetadata
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(0, parameters.appRequestMetadata.count);
}

- (void)testUpdateAppRequestMetadata_whenAccountIdIsNotNil_shouldSetCSSHintWithId
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"Oid:fedcba98-7654-3210-0000-000000000000@00000000-0000-1234-5678-90abcdefffff");
}

- (void)testUpdateAppRequestMetadata_whenAccountIdIsNilAndNewIdProvided_shouldSetCSSHintWithNewId
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:DEFAULT_TEST_HOME_ACCOUNT_ID];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"Oid:fedcba98-7654-3210-0000-000000000000@00000000-0000-1234-5678-90abcdefffff");
}

- (void)testUpdateAppRequestMetadata_whenCSSHintIsNotNilAndNewCSSHintAvailable_shouldUpdateCSSHint
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.appRequestMetadata = @{MSID_CCS_HINT_KEY: @"UPN:user2@contoso.com"};
    
    [parameters updateAppRequestMetadata:DEFAULT_TEST_HOME_ACCOUNT_ID];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"Oid:fedcba98-7654-3210-0000-000000000000@00000000-0000-1234-5678-90abcdefffff");
}

- (void)testUpdateAppRequestMetadata_whenCSSHintIsNotNilAndNewCSSHintIsNotAvailable_shouldDeleteCSSHint
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.appRequestMetadata = @{MSID_CCS_HINT_KEY: @"UPN:user2@contoso.com"};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(0, parameters.appRequestMetadata.count);
}

- (void)testUpdateAppRequestMetadata_whenAccountIdIsNotNilAndNewIdProvided_shouldSetCSSHintWithNewId
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:@"uid1.utid1"];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"Oid:uid1@utid1");
}

- (void)testUpdateAppRequestMetadata_whenAccountIdContainsUpnOnly_shouldSetCSSHint
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:nil];
    parameters.appRequestMetadata = @{};
    
    [parameters updateAppRequestMetadata:nil];

    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    XCTAssertEqual(1, parameters.appRequestMetadata.count);
    XCTAssertEqualObjects(parameters.appRequestMetadata[MSID_CCS_HINT_KEY], @"UPN:user2@contoso.com");
}

- (void)testReverseNestedAuth_whenNoNestedAuthParametersPresent_shouldNotReverse
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    
    [parameters reverseNestedAuthParametersIfNeeded];
    
    XCTAssertEqualObjects(parameters.clientId, @"myclient_id");
    XCTAssertEqualObjects(parameters.redirectUri, @"myredirect");
    XCTAssertNil(parameters.nestedAuthBrokerClientId);
    XCTAssertNil(parameters.nestedAuthBrokerRedirectUri);
}

- (void)testReverseNestedAuth_whenNestedAuthParametersPresent_shouldReverse
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    
    parameters.nestedAuthBrokerClientId = @"nested_client_id";
    parameters.nestedAuthBrokerRedirectUri = @"brk-nested_redirect";
    
    [parameters reverseNestedAuthParametersIfNeeded];
    
    XCTAssertEqualObjects(parameters.clientId, @"nested_client_id");
    XCTAssertEqualObjects(parameters.redirectUri, @"brk-nested_redirect");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerClientId, @"myclient_id");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerRedirectUri, @"myredirect");
}

- (void)testReverseNestedAuth_whenNestedAuthParametersPresentCalledTwice_shouldReverseOnce
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];
    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                              authScheme:[MSIDAuthenticationScheme new]
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
                                                                             requestType:MSIDRequestLocalType
                                                                                   error:&error];
    
    parameters.nestedAuthBrokerClientId = @"nested_client_id";
    parameters.nestedAuthBrokerRedirectUri = @"brk-nested_redirect";
        
    [parameters reverseNestedAuthParametersIfNeeded];
    // Call again
    [parameters reverseNestedAuthParametersIfNeeded];
    
    XCTAssertEqualObjects(parameters.clientId, @"nested_client_id");
    XCTAssertEqualObjects(parameters.redirectUri, @"brk-nested_redirect");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerClientId, @"myclient_id");
    XCTAssertEqualObjects(parameters.nestedAuthBrokerRedirectUri, @"myredirect");
}

@end
