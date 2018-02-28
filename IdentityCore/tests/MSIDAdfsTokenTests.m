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
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDAdfsToken.h"

@interface MSIDAdfsTokenTests : XCTestCase

@end

@implementation MSIDAdfsTokenTests

#pragma mark - Copy tests

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    MSIDAdfsToken *token = [self createToken];
    MSIDAdfsToken *tokenCopy = [token copy];
    
    XCTAssertEqualObjects(tokenCopy, token);
}

#pragma mark - isEqual tests

- (void)testADFSTokenIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [self createToken];
    MSIDAdfsToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - MSIDAdfsToken

- (void)testADFSTokenIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"token 2" forKey:@"accessToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"token 1" forKey:@"accessToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"token 1" forKey:@"accessToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenCachedAtIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"cachedAt"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenCachedAtIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenScopesIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"1 3" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenScopesIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"1 2" forKey:@"target"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"1 2" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 2" forKey:@"target"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"target"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 1" forKey:@"target"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenRefreshTokenIsNotEqual_shouldReturnFalse
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 2" forKey:@"refreshToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testADFSTokenIsEqual_whenRefreshTokenIsEqual_shouldReturnTrue
{
    MSIDAdfsToken *lhs = [MSIDAdfsToken new];
    [lhs setValue:@"value 1" forKey:@"refreshToken"];
    MSIDAdfsToken *rhs = [MSIDAdfsToken new];
    [rhs setValue:@"value 1" forKey:@"refreshToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Private

- (MSIDAdfsToken *)createToken
{
    MSIDAdfsToken *token = [MSIDAdfsToken new];
    [token setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"spe_info" : @"value2"} forKey:@"additionalInfo"];
    [token setValue:@"uid.utid" forKey:@"uniqueUserId"];
    [token setValue:@"username" forKey:@"username"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"cachedAt"];
    [token setValue:@"token" forKey:@"accessToken"];
    [token setValue:@"idtoken" forKey:@"idToken"];
    [token setValue:@"resource" forKey:@"target"];
    [token setValue:@"scopes" forKey:@"target"];
    [token setValue:@"refreshToken" forKey:@"refreshToken"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
