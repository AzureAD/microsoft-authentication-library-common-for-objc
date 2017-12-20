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
#import "MSIDJsonSerializer.h"
#import "MSIDToken.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDJsonSerializerTests : XCTestCase

@end

@implementation MSIDJsonSerializerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_whenSerializeToken_shouldReturnSameTokenOnDeserialize
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    MSIDToken *expectedToken = [MSIDToken new];
    [expectedToken setValue:@"refresh token value" forKey:@"token"];
    [expectedToken setValue:[[NSNumber alloc] initWithInt:MSIDTokenTypeRefreshToken] forKey:@"tokenType"];
    [expectedToken setValue:@"id token value" forKey:@"idToken"];
    [expectedToken setValue:[[NSDate alloc] initWithTimeIntervalSince1970:1513800870] forKey:@"expiresOn"];
    [expectedToken setValue:@"familyId value" forKey:@"familyId"];
    [expectedToken setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [expectedToken setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
    [expectedToken setValue:@"some resource" forKey:@"resource"];
    [expectedToken setValue:[NSURL URLWithString:@"https://contoso.com"] forKey:@"authority"];
    [expectedToken setValue:@"some clientId" forKey:@"clientId"];
    [expectedToken setValue:[[NSOrderedSet alloc] initWithArray:@[@"1", @"2"]] forKey:@"scopes"];
    
    NSData *data = [serializer serialize:expectedToken];
    MSIDToken *resultToken = [serializer deserialize:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, expectedToken);
}

- (void)testSerialize_whenTokenNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    
    NSData *data = [serializer serialize:nil];
    
    XCTAssertNil(data);
}

- (void)testSerialize_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    
    NSData *data = [serializer serialize:[MSIDToken new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserialize_whenDataNilNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    
    MSIDToken *token = [serializer deserialize:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserialize_whenDataInvalid_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDToken *token = [serializer deserialize:data];
    
    XCTAssertNil(token);
}

#pragma mark - Private

// TODO: move to helper method.
- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
