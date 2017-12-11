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
#import "MSIDToken.h"

@interface MSIDTokenTests : XCTestCase

@end

@implementation MSIDTokenTests

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
    MSIDToken *lhs = [self createToken];
    MSIDToken *rhs = [self createToken];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"token 1" forKey:@"token"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"token 2" forKey:@"token"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"token 1" forKey:@"token"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"token 1" forKey:@"token"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"idToken"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenIdTokenIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"idToken"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"idToken"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenExpiresOnIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:2000000000] forKey:@"expiresOn"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenExpiresOnIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"familyId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenFamilyIdIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"familyId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"familyId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientInfoIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key1" : @"value1"} forKey:@"clientInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key2" : @"value2"} forKey:@"clientInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientInfoIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key" : @"value"} forKey:@"clientInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key" : @"value"} forKey:@"clientInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key1" : @"value1"} forKey:@"additionalServerInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAdditionalServerInfoIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@{@"key" : @"value"} forKey:@"additionalServerInfo"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@1 forKey:@"tokenType"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenTokenTypeIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@0 forKey:@"tokenType"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@0 forKey:@"tokenType"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenResourceIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"resource"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenResourceIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"resource"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"resource"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAuthorityIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"authority"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"authority"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenAuthorityIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"authority"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"authority"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsNotEqual_shouldReturnFalse
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 2" forKey:@"clientId"];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenClientIdIsEqual_shouldReturnTrue
{
    MSIDToken *lhs = [MSIDToken new];
    [lhs setValue:@"value 1" forKey:@"clientId"];
    MSIDToken *rhs = [MSIDToken new];
    [rhs setValue:@"value 1" forKey:@"clientId"];
    
    XCTAssertEqualObjects(lhs, rhs);
}

#pragma mark - Private

- (MSIDToken *)createToken
{
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"access token value" forKey:@"token"];
    [token setValue:@"id token value" forKey:@"idToken"];
    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
    [token setValue:@"familyId value" forKey:@"familyId"];
    [token setValue:@{@"key" : @"value"} forKey:@"clientInfo"];
    [token setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    [token setValue:@"some resource" forKey:@"resource"];
    [token setValue:@"some authority" forKey:@"authority"];
    [token setValue:@"some clientId" forKey:@"clientId"];
    
    return token;
}

@end
