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
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTokenResult.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponse.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccount.h"

@interface MSIDDefaultTokenResponseValidatorTests : XCTestCase

@property (nonatomic) MSIDDefaultTokenResponseValidator *validator;

@end

@implementation MSIDDefaultTokenResponseValidatorTests

- (void)setUp
{
    self.validator = [MSIDDefaultTokenResponseValidator new];
}

- (void)tearDown
{
}

#pragma mark - Tests

- (void)testValidateTokenResult_whenSomeScopesRejectedByServer_shouldReturnErrorWithGrantedScopesButWithoutDefaultOidcScopes
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:@"fakescope1 fakescope2"];
    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:nil
                                                               responseRT:nil
                                                               responseID:nil
                                                            responseScope:@"openid profile offline_access user.read user.write"
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    NSError *error;
    
    [self.validator validateTokenResult:result
                          configuration:configuration
                              oidcScope:defaultOidcScope
                          correlationID:correlationID
                                  error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerDeclinedScopes);
    NSArray *declinedScopes = @[@"fakescope1", @"fakescope2"];
    XCTAssertEqualObjects(error.userInfo[MSIDDeclinedScopesKey], declinedScopes);
    NSArray *grantedScopes = @[@"user.read", @"user.write"];
    XCTAssertEqualObjects(error.userInfo[MSIDGrantedScopesKey], grantedScopes);
}

- (void)testValidateTokenResult_whenWithValidResponse_shouldReturnValidResult
{
    __auto_type defaultOidcScope = @"openid profile offline_access";
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];

    NSError *error;
    
    BOOL validated = [self.validator validateTokenResult:result
                                        configuration:configuration
                                            oidcScope:defaultOidcScope
                                        correlationID:correlationID
                                                error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenUIDMatch_shouldReturnYES
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    
    NSError *error;
    
    BOOL validated = [self.validator validateAccount:account.accountIdentifier
                                         tokenResult:result
                                       correlationID:correlationID
                                               error:&error];
    
    XCTAssertTrue(validated);
    XCTAssertNil(error);
}

- (void)testValidateAccount_whenUIDMismatch_shouldReturnNO
{
    __auto_type correlationID = [NSUUID new];
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                        redirectUri:@"some_uri"
                                                                           clientId:@"myclient"
                                                                             target:DEFAULT_TEST_SCOPE];
    
    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2DefaultTokenResponse];
    
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:configuration];
    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                              refreshToken:nil
                                                                   idToken:response.idToken
                                                                   account:account
                                                                 authority:authority
                                                             correlationId:correlationID
                                                             tokenResponse:response];
    
    NSError *error;
    
    BOOL validated = [self.validator validateAccount:[[MSIDAccountIdentifier alloc] initWithDisplayableId:@"somedisplayableid"
                                                                                            homeAccountId:@"someuid.someutid"]
                                         tokenResult:result
                                       correlationID:correlationID
                                               error:&error];
    
    XCTAssertFalse(validated);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorMismatchedAccount);
}


@end
