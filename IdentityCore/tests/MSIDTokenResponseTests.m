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
#import "MSIDTokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDRefreshToken.h"

@interface MSIDTokenResponseTests : XCTestCase

@end

@implementation MSIDTokenResponseTests

- (void)testExpiresIn_whenStringExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresIn = [response expiresIn];
    XCTAssertEqual(expiresIn, 3600);
}

- (void)testExpiresIn_whenNumberExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresIn = [response expiresIn];
    XCTAssertEqual(expiresIn, 3600);
}

- (void)testExpiryDate_whenExpiresInAvailable_shouldReturnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNotNil(expiryDate);
}

- (void)testExpiryDate_whenExpiresInNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNil(expiryDate);
}

- (void)testIdTokenObj_whenIdTokenAvailable_shouldReturnIDToken
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"test" upn:@"upn" oid:nil tenantId:@"tenant"];
    
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"id_token": idToken,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNotNil(idTokenObj);
    XCTAssertEqualObjects(idTokenObj.rawIdToken, idToken);
}

- (void)testIdTokenObj_whenIdTokenAvailableButCorrupted_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"id_token": @"id token",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNil(idTokenObj);
}

- (void)testIdTokenObj_whenIdTokenNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    MSIDIdTokenClaims *idTokenObj = response.idTokenObj;
    XCTAssertNil(idTokenObj);
}

#pragma mark - Refresh token

- (void)testInitWithJson_andNilRefreshToken_shouldNotTakeFieldsFromRefreshToken
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                       refreshToken:nil
                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertNil(response.idToken);
}

- (void)testInitWithJson_andRefreshToken_shouldNotTakeFieldsFromRefreshTokenAndUpdate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt",
                                @"id_token": @"id token 2"
                                };
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.refreshToken = @"rt";

    NSError *error = nil;
    MSIDTokenResponse *response = [[MSIDTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                       refreshToken:refreshToken
                                                                              error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
    
    XCTAssertEqualObjects(response.idToken, @"id token 2");
}

@end
