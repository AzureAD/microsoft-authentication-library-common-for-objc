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
#import "MSIDBaseToken.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDBaseTokenTests : XCTestCase

@end

@implementation MSIDBaseTokenTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - isEqual tests

- (void)testIsEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [self createToken];
    MSIDBaseToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"token 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"token 1" forKey:@"idToken"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"token 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

/*
- (void)testIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}*/

- (void)testIsEqual_whenClientInfoIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[self createClientInfo:@{@"key2" : @"value2"}] forKey:@"clientInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientInfoIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[self createClientInfo:@{@"key1" : @"value1"}] forKey:@"clientInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@{@"key1" : @"value1"} forKey:@"additionalServerInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@1 forKey:@"tokenType"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@0 forKey:@"tokenType"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

/*
- (void)testIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"resource"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"resource"];
    
    XCTAssertEqualObjects(lhs, rhs);
}*/

- (void)testIsEqual_whenAuthorityIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso2.com"] forKey:@"authority"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAuthorityIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 2" forKey:@"clientId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:@"value 1" forKey:@"clientId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

/*
- (void)testIsEqual_whenScopesIsNotEqual_shouldReturnFalse
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @3]] forKey:@"scopes"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenScopesIsEqual_shouldReturnTrue
{
    MSIDBaseToken *lhs = [MSIDBaseToken new];
    [lhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    MSIDBaseToken *rhs = [MSIDBaseToken new];
    [rhs setValue:[[NSOrderedSet alloc] initWithArray:@[@1, @2]] forKey:@"scopes"];
    
    XCTAssertEqualObjects(lhs, rhs);
}*/

#pragma mark - Private

- (MSIDBaseToken *)createToken
{
    MSIDBaseToken *token = [MSIDBaseToken new];
    [token setValue:@"id token value" forKey:@"idToken"];
    [token setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [token setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    [token setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    
    return token;
}

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
