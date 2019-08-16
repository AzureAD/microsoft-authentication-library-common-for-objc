//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDDefaultCredentialCacheQuery.h"

@interface MSIDDefaultCredentialCacheQueryTests : XCTestCase

@end

@implementation MSIDDefaultCredentialCacheQueryTests

- (void)testDefaultCredentialCacheQuery_whenAccessToken_allParametersSet_shouldBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.clientId = @"client";

    XCTAssertTrue(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"accesstoken-client-contoso.com-user.read");
    XCTAssertEqualObjects(query.type, @2001);
    XCTAssertEqualObjects(query.generic, [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDefaultCredentialCacheQuery_whenAccessToken_allParametersSet_andIntuneEnrolled_shouldBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.clientId = @"client";
    query.applicationIdentifier = @"app.bundle.id";
    
    XCTAssertTrue(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"accesstoken-client-contoso.com-app.bundle.id-user.read");
    XCTAssertEqualObjects(query.type, @2001);
    XCTAssertEqualObjects(query.generic, [@"accesstoken-client-contoso.com-app.bundle.id" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDefaultCredentialCacheQuery_whenIDToken_allParametersSet_shouldBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDIDTokenType;
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.clientId = @"client";

    XCTAssertTrue(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"idtoken-client-contoso.com-");
    XCTAssertEqualObjects(query.type, @2003);
    XCTAssertEqualObjects(query.generic, [@"idtoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDefaultCredentialCacheQuery_whenRefreshToken_allParametersSet_shouldBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.target = @"user.read";
    query.clientId = @"client";

    XCTAssertTrue(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"refreshtoken-client--");
    XCTAssertEqualObjects(query.type, @2002);
    XCTAssertEqualObjects(query.generic, [@"refreshtoken-client-" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDefaultCredentialCacheQuery_whenFamilyRefreshToken_allParametersSet_shouldBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDRefreshTokenType;
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.target = @"user.read";
    query.clientId = @"client";
    query.familyId = @"family";

    XCTAssertTrue(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertEqualObjects(query.service, @"refreshtoken-family--");
    XCTAssertEqualObjects(query.type, @2002);
    XCTAssertEqualObjects(query.generic, [@"refreshtoken-family-" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testDefaultCredentialCacheQuery_whenMatchAnyTypeAndAccessToken_allParametersSet_shouldNotBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.target = @"user.read";
    query.clientId = @"client";
    query.matchAnyCredentialType = YES;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
}

- (void)testDefaultCredentialCacheQuery_whenMatchAnyTypeAndIDToken_allParametersSet_shouldNotBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.clientId = @"client";
    query.matchAnyCredentialType = YES;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
}

- (void)testDefaultCredentialCacheQuery_whenMatchAnyTypeAndRefreshToken_allParametersSet_shouldNotBeExactMatch
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.matchAnyCredentialType = YES;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
}

- (void)testDefaultCredentialCacheQuery_whenNoHomeAccountId_shouldReturnNilAccount
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDRefreshTokenType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.account);
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2002);
}

- (void)testDefaultCredentialCacheQuery_whenNoEnvironment_shouldReturnNilAccount
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.credentialType = MSIDRefreshTokenType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.account);
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2002);
}

- (void)testDefaultCredentialCacheQuery_whenRefreshToken_andNoClientId_shouldReturnNilServiceNilGeneric
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDRefreshTokenType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2002);
}

- (void)testDefaultCredentialCacheQuery_whenIDToken_andNoClientId_shouldReturnNilServiceNilGeneric
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.realm = @"contoso.com";
    query.credentialType = MSIDIDTokenType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2003);
}

- (void)testDefaultCredentialCacheQuery_whenIDToken_andNoRealm_shouldReturnNilServiceNilGeneric
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.clientId = @"client";
    query.credentialType = MSIDIDTokenType;

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2003);
}

- (void)testDefaultCredentialCacheQuery_whenAccessToken_andNoClientId_shouldReturnNilServiceNilGeneric
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDAccessTokenType;
    query.realm = @"contoso.com";
    query.target = @"user.read";

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2001);
}

- (void)testDefaultCredentialCacheQuery_whenAccessToken_andNoRealm_shouldReturnNilServiceNilGeneric
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.target = @"user.read";

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertNil(query.generic);
    XCTAssertEqualObjects(query.type, @2001);
}

- (void)testDefaultCredentialCacheQuery_whenAccessToken_andNoTarget_shouldReturnNilServiceAndNonNilGenetic
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertEqualObjects(query.generic, [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(query.type, @2001);
}

- (void)testDefaultCredentialCacheQuery_whenAccessToken_andTargetMatchingAny_shouldReturnNilServiceAndNonNilGenetic
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.homeAccountId = @"uid.utid";
    query.environment = @"login.microsoftonline.com";
    query.credentialType = MSIDAccessTokenType;
    query.clientId = @"client";
    query.realm = @"contoso.com";

    XCTAssertFalse(query.exactMatch);
    XCTAssertEqualObjects(query.account, @"uid.utid-login.microsoftonline.com");
    XCTAssertNil(query.service);
    XCTAssertEqualObjects(query.generic, [@"accesstoken-client-contoso.com" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(query.type, @2001);
}

- (void)testDefaultCredentialCacheQuery_whenMatchAnyType_shouldReturnNilType
{
    MSIDDefaultCredentialCacheQuery *query = [MSIDDefaultCredentialCacheQuery new];
    query.credentialType = MSIDAccessTokenType;
    query.matchAnyCredentialType = YES;

    XCTAssertFalse(query.exactMatch);
    XCTAssertNil(query.type);
}

@end
