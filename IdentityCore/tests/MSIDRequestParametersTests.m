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
#import "MSIDRequestParameters.h"
#import "MSIDVersion.h"
#import "NSString+MSIDTestUtil.h"

@interface MSIDRequestParametersTests : XCTestCase

@end

@implementation MSIDRequestParametersTests

- (void)testInitParameters_withValidParameters_shouldInitReturnNonNil
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
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
}

- (void)testInitParameters_withIntersectingOIDCScopes_shouldFailAndReturnNil
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSOrderedSet *scopes = [NSOrderedSet orderedSetWithObjects:@"myscope1", @"myscope2", @"offline_access", nil];
    NSOrderedSet *oidcScopes = [NSOrderedSet orderedSetWithObjects:@"openid", @"offline_access", @"profile", nil];

    NSError *error = nil;
    MSIDRequestParameters *parameters = [[MSIDRequestParameters alloc] initWithAuthority:authority
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
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
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
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
                                                                             redirectUri:@"myredirect"
                                                                                clientId:@"myclient_id"
                                                                                  scopes:scopes
                                                                              oidcScopes:oidcScopes
                                                                           correlationId:nil
                                                                          telemetryApiId:nil
                                                                     intuneAppIdentifier:@"com.microsoft.mytest"
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

@end
