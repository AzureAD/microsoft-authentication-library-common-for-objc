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


#import <XCTest/XCTest.h>
#import "MSIDTestBundle.h"
#import "MSIDRedirectUriVerifier.h"
#import "MSIDRedirectUri.h"

@interface MSIDRedirectUriVerifierTests : XCTestCase

@end

@implementation MSIDRedirectUriVerifierTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [MSIDTestBundle reset];
}

- (void)testMSIDRedirectUri_whenCustomRedirectUri_andNotBrokerCapable_shouldReturnUriBrokerCapableNo
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myapp"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"myapp://authtest";
    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:redirectUri
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertFalse(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSIDRedirectUri_whenCustomRedirectUri_andBrokerCapable_shouldReturnUriBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msauth.test.bundle.identifier"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"msauth.test.bundle.identifier://auth";
    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:redirectUri
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSIDRedirectUri_whenCustomRedirectUri_andLegacyBrokerCapable_shouldReturnUriBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"myscheme://test.bundle.identifier";
    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:redirectUri
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSIDRedirectUri_whenCustomRedirectUri_andNotRegistered_shouldReturnNilAndFillError
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"notregistered://test.bundle.identifier";
    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:redirectUri
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorRedirectSchemeNotRegistered);
}

- (void)testMSIDRedirectUri_whenDefaultRedirectUri_andBrokerCapableUrlRegistered_shouldReturnUriAndBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msauth.test.bundle.identifier"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:nil
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, @"msauth.test.bundle.identifier://auth");
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSIDRedirectUri_whenDefaultRedirectUri_andDefaultUrlRegistered_shouldReturnUriAndBrokerCapableNo
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msalmsidclient"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *clientId = @"msidclient";

    NSError *error = nil;
    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:nil
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, @"msalmsidclient://auth");
    XCTAssertFalse(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSIDRedirectUri_whenNoRedirectUriRegistered_shouldReturnNilAndFillError
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];
    NSString *clientId = @"msidclient";
    NSError *error = nil;

    MSIDRedirectUri *result = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:nil
                                                                           clientId:clientId
                                                           bypassRedirectValidation:NO
                                                                              error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorRedirectSchemeNotRegistered);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"\"msauth.test.bundle.identifier\""]);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"\"msauth.test.bundle.identifier://auth\""]);
}

- (void)testVerifyRegisteredSchemes_whenAllSchemesAreRegistered_shouldReturnYESAndNilError
{
    NSArray *urlTypes = @[@"myotherscheme", @"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"LSApplicationQueriesSchemes"];

    NSError *error;
    BOOL result = [MSIDRedirectUriVerifier verifyAdditionalRequiredSchemesAreRegistered:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testVerifyRegisteredSchemes_whenSchemeIsNotRegistered_shouldReturnNOAndFillError
{
    NSArray *urlTypes = @[@"msauthv2", @"msauthv-wrong"];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"LSApplicationQueriesSchemes"];

    NSError *error;
    BOOL result = [MSIDRedirectUriVerifier verifyAdditionalRequiredSchemesAreRegistered:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorRedirectSchemeNotRegistered);
}

@end
