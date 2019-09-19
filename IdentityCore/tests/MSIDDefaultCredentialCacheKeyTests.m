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

- (void)testDefaultKeyForAccessToken_withRealm_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDAccessTokenType];

    key.realm = @"contoso.com";
    key.target = @"user.read user.write";

    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testDefaultKeyForAccessToken_withRealmAndEnrollmentId_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                          environment:@"login.microsoftonline.com"
                                                                                             clientId:@"client"
                                                                                       credentialType:MSIDAccessTokenType];
    
    key.realm = @"contoso.com";
    key.target = @"user.read user.write";
    key.applicationIdentifier = @"app.bundle.id";
    
    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-app.bundle.id-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);
    
    NSData *genericData = [@"accesstoken-client-contoso.com-app.bundle.id" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testDefaultKeyForAccessToken_withUpperCaseComponents_shouldReturnKeyLowerCase
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"UID.utid"
                                                                                         environment:@"LOGIN.microsoftonline.com"
                                                                                            clientId:@"CLIENT"
                                                                                      credentialType:MSIDAccessTokenType];

    key.realm = @"CONTOSO.COM";
    key.target = @"User.read User.write";

    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"accesstoken-client-contoso.com-user.read user.write");
    XCTAssertEqualObjects(key.type, @2001);

    NSData *genericData = [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForIDToken_withAllParameters_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDIDTokenType];

    key.realm = @"contoso.com";
    key.credentialType = MSIDIDTokenType;
    
    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"idtoken-client-contoso.com-");
    XCTAssertEqualObjects(key.type, @2003);
    
    NSData *genericData = [@"idtoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForIDToken_withAllParametersUpperCase_shouldReturnKeyLowerCase
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"UID.utid"
                                                                                         environment:@"login.MICROSOFTonline.com"
                                                                                            clientId:@"clieNT"
                                                                                      credentialType:MSIDIDTokenType];

    key.realm = @"contoso.COM";

    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"idtoken-client-contoso.com-");
    XCTAssertEqualObjects(key.type, @2003);

    NSData *genericData = [@"idtoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
}

- (void)testKeyForRefreshToken_withAllParameters_shouldReturnKey
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDRefreshTokenType];

    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"refreshtoken-client--");
    
    NSData *genericData = [@"refreshtoken-client-" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2002);
}

- (void)testKeyForRefreshToken_withFamilyId_shouldReturnKeyWithFamilyId
{
    MSIDDefaultCredentialCacheKey *key = [[MSIDDefaultCredentialCacheKey alloc] initWithHomeAccountId:@"uid.utid"
                                                                                         environment:@"login.microsoftonline.com"
                                                                                            clientId:@"client"
                                                                                      credentialType:MSIDRefreshTokenType];

    key.familyId = @"familyID";

    XCTAssertEqualObjects(key.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(key.service, @"refreshtoken-familyid--");

    NSData *genericData = [@"refreshtoken-familyid-" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(key.generic, genericData);
    XCTAssertEqualObjects(key.type, @2002);
}

@end
