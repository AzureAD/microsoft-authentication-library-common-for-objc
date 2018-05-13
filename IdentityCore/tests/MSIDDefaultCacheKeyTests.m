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
#import "MSIDDefaultCredentialCacheKey.h"

@interface MSIDDefaultCacheKeyTests : XCTestCase

@end

@implementation MSIDDefaultCacheKeyTests

- (void)testDefaultKeyForAccessTokens_withRealm_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForAccessTokenWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client" realm:@"contoso.com" target:@"user.read user.write"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testDefaultKeyForAccessTokens_withAuthority_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForAccessTokenWithUniqueUserId:@"uid" authority:url clientId:@"client" scopes:[NSOrderedSet orderedSetWithObjects:@"user.read", @"user.write", nil]];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testDefaultKeyForAccessTokens_withAuthorityUpperCase_shouldReturnKeyLowerCase
{
    NSURL *url = [NSURL URLWithString:@"https://Login.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForAccessTokenWithUniqueUserId:@"Uid " authority:url clientId:@"Client" scopes:[NSOrderedSet orderedSetWithObjects:@"User.read", @"User.write", nil]];

    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);

    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForIDToken_withAllParameters_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForIDTokenWithUniqueUserId:@"uid" authority:url clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"idtoken-client-contoso.com-");
    XCTAssertEqualObjects(key.type, @2003);
    
    NSData *genericData = [@"idtoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForIDToken_withAllParametersUpperCase_shouldReturnKeyLowerCase
{
    NSURL *url = [NSURL URLWithString:@"https://Login.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForIDTokenWithUniqueUserId:@"Uid" authority:url clientId:@"Client"];

    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"idtoken-client-contoso.com-");
    XCTAssertEqualObjects(key.type, @2003);

    NSData *genericData = [@"idtoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForAccount_withAllParameters_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForAccountWithUniqueUserId:@"uid" authority:url username:@"username" accountType:MSIDAccountTypeAADV1];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"contoso.com");
    XCTAssertEqualObjects(key.generic, [@"username" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(key.type, @1001);
}

- (void)testKeyForAccount_withAllParametersUpperCase_shouldReturnKeyLowerCase
{
    NSURL *url = [NSURL URLWithString:@"https://loGin.microsoftonline.com/contoso.com"];
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForAccountWithUniqueUserId:@" Uid" authority:url username:@" Username" accountType:MSIDAccountTypeAADV1];

    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"contoso.com");
    XCTAssertEqualObjects(key.generic, [@"username" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(key.type, @1001);
}

- (void)testQueryForAllAccessTokens_withRealm_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey queryForAllAccessTokensWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client" realm:@"contoso.com"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertNil(key.service);
    
    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testQueryForAllAccessTokens_withAuthority_shouldReturnKey
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey queryForAllAccessTokensWithUniqueUserId:@"uid" authority:url clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertNil(key.service);
    
    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2001);
}

- (void)testQueryForAllAccessTokens_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey queryForAllAccessTokens];
    
    XCTAssertEqualObjects(key.type, @2001);
    XCTAssertNil(key.service);
    XCTAssertNil(key.generic);
    XCTAssertNil(key.account);
}

- (void)testKeyForRefreshToken_withAllParameters_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey keyForRefreshTokenWithUniqueUserId:@"uid" environment:@"login.microsoftonline.com" clientId:@"client"];
    
    XCTAssertEqualObjects(key.account, @"uid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"refreshtoken-client--");
    
    NSData *genericData = [@"refreshtoken-client-" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testQueryForAllTokensWithType_withRefreshTokenType_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey queryForAllTokensWithType:MSIDCredentialTypeRefreshToken];
    
    XCTAssertNil(key.account);
    XCTAssertNil(key.service);
    XCTAssertNil(key.generic);
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testQueryForAllRefreshTokensWithClientId_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [MSIDDefaultCredentialCacheKey queryForAllRefreshTokensWithClientId:@"client"];
    
    XCTAssertNil(key.account);
    XCTAssertNil(key.generic);
    XCTAssertEqualObjects(key.type, @2002);
    XCTAssertEqualObjects(key.service, @"refreshtoken-client--");
}

@end
