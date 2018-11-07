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

#import "MSIDCommonCredential.h"
#import "NSDate+MSIDExtensions.h"
#import <XCTest/XCTest.h>

@interface MSIDCommonCredentialTests : XCTestCase

@end

@implementation MSIDCommonCredentialTests

#pragma mark - setUp / tearDown

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each
    // test method in the class.
    [super tearDown];
}

#pragma mark - MSIDCommonCredential tests

- (void)testcredentialTypeAsString_whenAccessTokenType_shouldReturnAccessTokenString {
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDAccessTokenType];
    XCTAssertEqualObjects(result, @"AccessToken");
}

- (void)testcredentialTypeAsString_whenRefreshTokenType_shouldReturnRefreshTokenString {
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDRefreshTokenType];
    XCTAssertEqualObjects(result, @"RefreshToken");
}

- (void)testcredentialTypeAsString_whenIDTokenType_shouldReturnIDTokenString {
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDIDTokenType];
    XCTAssertEqualObjects(result, @"IdToken");
}

- (void)testcredentialTypeAsString_whenLegacyTokenType_shouldReturnLegacyTokenString {
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDLegacySingleResourceTokenType];
    XCTAssertEqualObjects(result, @"LegacySingleResourceToken");
}

- (void)testcredentialTypeAsString_whenOtherTokenType_shouldReturnOtherTokenString {
    NSString *result = [MSIDCredentialTypeHelpers credentialTypeAsString:MSIDCredentialTypeOther];
    XCTAssertEqualObjects(result, @"token");
}

- (void)testTokenTypeFromString_whenAccessTokenString_shouldReturnAccessTokenType {
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"AccessToken"];
    XCTAssertEqual(result, MSIDAccessTokenType);
}

- (void)testTokenTypeFromString_whenRefreshTokenString_shouldReturnRefreshTokenType {
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"RefreshToken"];
    XCTAssertEqual(result, MSIDRefreshTokenType);
}

- (void)testTokenTypeFromString_whenIDTokenString_shouldReturnIDTokenType {
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"IdToken"];
    XCTAssertEqual(result, MSIDIDTokenType);
}

- (void)testTokenTypeFromString_whenLegacyTokenString_shouldReturnLegacyTokenType {
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"LegacySingleResourceToken"];
    XCTAssertEqual(result, MSIDLegacySingleResourceTokenType);
}

- (void)testTokenTypeFromString_whenOtherTokenString_shouldReturnOtherTokenType {
    MSIDCredentialType result = [MSIDCredentialTypeHelpers credentialTypeFromString:@"token"];
    XCTAssertEqual(result, MSIDCredentialTypeOther);
}

#pragma mark - IsEqualToItem handling

- (void)testCredentialIsEqualToItemBehavior {
    NSDictionary *credentialDict1 = @{
        @"credential_type": @"AccessToken",
        @"client_id": @"clientid1",
        @"secret": @"thesecret1",
        @"target": @"target1",
        @"realm": @"realm xyz",
        @"environment": @"environment abc",
        @"cached_at": @"0",
        @"expires_on": @"1000",
        @"extended_expires_on": @"2000",
        @"home_account_id": @"home account id1"
    };
    NSDictionary *credentialDict2 = @{
        @"credential_type": @"AccessToken",
        @"client_id": @"clientid2",
        @"secret": @"thesecret2",
        @"target": @"target2",
        @"realm": @"realm xyz",
        @"environment": @"environment abc",
        @"cached_at": @"11",
        @"expires_on": @"1111",
        @"extended_expires_on": @"2222",
        @"home_account_id": @"home account id2"
    };
    NSError *error = nil;
    MSIDCommonCredential *item1 = [[MSIDCommonCredential alloc] initWithJSONDictionary:credentialDict1 error:&error];
    XCTAssertNotNil(item1);
    XCTAssertNil(error);

    MSIDCommonCredential *item2 = [[MSIDCommonCredential alloc] initWithJSONDictionary:credentialDict2 error:&error];
    XCTAssertNotNil(item2);
    XCTAssertNil(error);
    XCTAssertFalse([item1 isEqualToItem:item2]);

    MSIDCommonCredential *item1copy = [[MSIDCommonCredential alloc] initWithJSONDictionary:credentialDict1
                                                                                     error:&error];
    XCTAssertNotNil(item1copy);
    XCTAssertNil(error);
    XCTAssertTrue([item1 isEqualToItem:item1copy]);

    item1copy.target = nil;
    XCTAssertFalse([item1 isEqualToItem:item1copy]);
    XCTAssertNil(item1copy.target);
    XCTAssertNotNil(item1.target);

    item1.target = nil;
    XCTAssertTrue([item1 isEqualToItem:item1copy]);
}

@end
