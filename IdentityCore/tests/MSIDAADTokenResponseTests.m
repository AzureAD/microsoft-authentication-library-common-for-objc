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
#import "MSIDAADTokenResponse.h"
#import "MSIDRefreshToken.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestIdentifiers.h"

@interface MSIDAADTokenResponseTests : XCTestCase

@end

@implementation MSIDAADTokenResponseTests

- (void)testExpiresOn_whenStringExpiresOn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_on": @"3600000",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresOn = [response expiresOn];
    XCTAssertEqual(expiresOn, 3600000);
}

- (void)testExpiresOn_whenNumberExpiresOn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_on": @3600000,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger expiresOn = [response expiresOn];
    XCTAssertEqual(expiresOn, 3600000);
}

- (void)testExpiryDate_whenExpiresOnAvailable_shouldReturnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_on": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNotNil(expiryDate);
}

- (void)testExpiryDate_whenExpiresOnNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response expiryDate];
    XCTAssertNil(expiryDate);
}

- (void)testExtExpiresIn_whenStringExtExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"ext_expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger extExpiresIn = [response extendedExpiresIn];
    XCTAssertEqual(extExpiresIn, 3600);
}

- (void)testExtExpiresIn_whenNumberExtExpiresIn_shouldReturnValue
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"ext_expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSInteger extExpiresIn = [response extendedExpiresIn];
    XCTAssertEqual(extExpiresIn, 3600);
}

- (void)testExtendedExpiryDate_whenExtendedExpiresOnAvailable_shouldReturnDate
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"ext_expires_in": @3600,
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response extendedExpiresOnDate];
    XCTAssertNotNil(expiryDate);
}

- (void)testExtendedExpiryDate_whenExtendedExpiresInNotAvailable_shouldReturnNil
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    NSDate *expiryDate = [response extendedExpiresOnDate];
    XCTAssertNil(expiryDate);
}

#pragma mark - Refresh token

- (void)testInitWithJson_andRefreshToken_andNilRefreshTokenInResponse_shouldTakeRefreshTokenFromInput
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600"};

    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.refreshToken = @"rt from refresh token";

    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                             refreshToken:refreshToken
                                                                                    error:&error];

    XCTAssertNotNil(response);
    XCTAssertNil(error);

    XCTAssertEqualObjects(response.refreshToken, @"rt from refresh token");
}

- (void)testInitWithJson_andNilRefreshToken_shouldNotTakeFieldsFromRefreshToken
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt"};
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                             refreshToken:nil
                                                                                    error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    XCTAssertNil(response.clientInfo);
}

- (void)testInitWithJson_andRefreshToken_shouldNotTakeFieldsFromRefreshTokenAndUpdate
{
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"3600",
                                @"refresh_token": @"rt",
                                @"client_info": clientInfoString
                                };
    
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    refreshToken.refreshToken = @"rt2";
    
    NSError *error = nil;
    MSIDAADTokenResponse *response = [[MSIDAADTokenResponse alloc] initWithJSONDictionary:jsonInput
                                                                             refreshToken:refreshToken
                                                                                    error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(response.clientInfo.rawClientInfo, clientInfoString);
    XCTAssertEqualObjects(response.refreshToken, @"rt");
}

@end
