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
#import "MSIDDefaultTokenCacheKey.h"

@interface MSIDDefaultCacheKeyTests : XCTestCase

@end

@implementation MSIDDefaultCacheKeyTests

- (void)testDefaultKeyForAccessTokens_withRealm_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client" realm:@"contoso.com" target:@"user.read user.write"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"AccessToken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"AccessToken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testDefaultKeyForAccessTokens_withAuthority_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccessTokenWithUniqueUserId:@"uid" authority:url clientId:@"client" scopes:[NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil]];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"AccessToken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"AccessToken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForIDToken_withAllParameters_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForIDTokenWithUniqueUserId:@"uid" authority:url clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"IdToken-client-contoso.com");
    XCTAssertEqualObjects(key.type, @2003);
    
    NSData *genericData = [@"IdToken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForAccount_withAllParameters_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForAccountWithUniqueUserId:@"uid" authority:url clientId:@"client" username:@"username" accountType:MSIDAccountTypeAADV1];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"contoso.com");
    XCTAssertEqualObjects(key.generic, [@"username" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(key.type, @1001);
}

- (void)testQueryForAllAccessTokens_withRealm_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client" realm:@"contoso.com"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertNil(key.service);
    
    NSData *genericData = [@"AccessToken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testQueryForAllAccessTokens_withAuthority_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokensWithUniqueUserId:@"uid" authority:url clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertNil(key.service);
    
    NSData *genericData = [@"AccessToken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testQueryForAllAccessTokens_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllAccessTokens];
    
    XCTAssertEqualObjects(key.type, @2001);
    XCTAssertNil(key.service);
    XCTAssertNil(key.generic);
    XCTAssertNil(key.account);
}

- (void)testKeyForRefreshToken_withAllParameters_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey keyForRefreshTokenWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"RefreshToken-client");
    
    NSData *genericData = [@"RefreshToken-client" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testQueryForAllTokensWithType_withRefreshTokenType_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllTokensWithType:MSIDTokenTypeRefreshToken];
    
    XCTAssertNil(key.account);
    XCTAssertNil(key.service);
    XCTAssertNil(key.generic);
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testQueryForAllRefreshTokensWithClientId_shouldReturnKey
{
    MSIDDefaultTokenCacheKey *key = [MSIDDefaultTokenCacheKey queryForAllRefreshTokensWithClientId:@"client"];
    
    XCTAssertNil(key.account);
    XCTAssertNil(key.generic);
    XCTAssertEqualObjects(key.type, @2002);
    XCTAssertEqualObjects(key.service, @"RefreshToken-client");
}

@end
