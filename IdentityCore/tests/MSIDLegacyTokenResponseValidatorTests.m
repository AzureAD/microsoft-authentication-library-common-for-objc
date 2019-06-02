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
#import "MSIDLegacyTokenResponseValidator.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResult.h"
#import "MSIDConfiguration.h"
#import "MSIDTokenResponse.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccessToken.h"

@interface MSIDLegacyTokenResponseValidatorTests : XCTestCase

@property (nonatomic) MSIDLegacyTokenResponseValidator *validator;

@end

@implementation MSIDLegacyTokenResponseValidatorTests

- (void)setUp
{
    [super setUp];
    self.validator = [MSIDLegacyTokenResponseValidator new];
}

#pragma mark - Tests

- (void)testValidateAccount_whenAccountTypeIsRequiredDisplayableId_andAccountMismatch_shouldReturnError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:nil];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeRequiredDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorMismatchedAccount);
}

- (void)testValidateAccount_whenAccountTypeIsRequiredDisplayableId_andNoAccountProvided_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [MSIDAccountIdentifier new];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeRequiredDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsRequiredDisplayableId_andAccountMatches_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:nil];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeRequiredDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsOptionalDisplayableId_andAccountMatches_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:nil];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeOptionalDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsOptionalDisplayableId_andNoInputAccount_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [MSIDAccountIdentifier new];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeOptionalDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsOptionalDisplayableId_andAccountMismatch_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:nil];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeOptionalDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsUniqueId_andAccountMismatch_shouldReturnError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [MSIDAccountIdentifier new];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeUniqueNonDisplayableId;
    testAccount.localAccountId = @"oid2";
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorMismatchedAccount);
}

- (void)testValidateAccount_whenAccountTypeIsUniqueId_andNoInputAccount_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [MSIDAccountIdentifier new];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeUniqueNonDisplayableId;
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenAccountTypeIsUniqueId_andAccountMatches_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    MSIDAccountIdentifier *testAccount = [MSIDAccountIdentifier new];
    testAccount.legacyAccountIdentifierType = MSIDLegacyIdentifierTypeUniqueNonDisplayableId;
    testAccount.localAccountId = @"unique_oid";
    
    NSError *error = nil;
    BOOL result = [self.validator validateAccount:testAccount
                                      tokenResult:testResult
                                    correlationID:[NSUUID new]
                                            error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testValidateTokenResult_whenResultContainsAccount_shouldReturnNoError
{
    MSIDTokenResult *testResult = [self testTokenResult];
    
    NSError *error = nil;
    BOOL result = [self.validator validateTokenResult:testResult
                                        configuration:[MSIDConfiguration new]
                                            oidcScope:nil
                                        correlationID:[NSUUID new]
                                                error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - Helpers

- (MSIDTokenResult *)testTokenResult
{
    MSIDAccount *account = [MSIDAccount new];
    account.username = @"user@contoso.com";
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.utid"];
    account.localAccountId = @"unique_oid";
    account.accountIdentifier = accountIdentifier;
    
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:[MSIDAccessToken new]
                                                              refreshToken:nil
                                                                   idToken:@"id token"
                                                                   account:account
                                                                 authority:[@"https://login.microsoftonline.com/contoso.com" aadAuthority]
                                                             correlationId:[NSUUID new]
                                                             tokenResponse:nil];
    
    return result;
}

@end
