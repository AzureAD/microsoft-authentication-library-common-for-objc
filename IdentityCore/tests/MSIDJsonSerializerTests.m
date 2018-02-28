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
#import "MSIDBaseToken.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRefreshToken.h"

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
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeRefreshToken];
    MSIDRefreshToken *expectedToken = [MSIDRefreshToken new];
    [expectedToken setValue:@"refresh token value" forKey:@"refreshToken"];
    [expectedToken setValue:@"familyId value" forKey:@"familyId"];
    [expectedToken setValue:[self createClientInfo:@{@"key" : @"value"}] forKey:@"clientInfo"];
    [expectedToken setValue:@{@"spe_info" : @"test"} forKey:@"additionalInfo"];
    [expectedToken setValue:[NSURL URLWithString:@"https://contoso.com/common"] forKey:@"authority"];
    [expectedToken setValue:@"some clientId" forKey:@"clientId"];
    
    NSData *data = [serializer serialize:expectedToken];
    MSIDRefreshToken *resultToken = (MSIDRefreshToken *)[serializer deserialize:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, expectedToken);
}

- (void)testSerialize_whenTokenNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    NSData *data = [serializer serialize:nil];
    
    XCTAssertNil(data);
}

- (void)testSerialize_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    NSData *data = [serializer serialize:[MSIDRefreshToken new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserialize_whenDataNilNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    
    MSIDRefreshToken *token = (MSIDRefreshToken *)[serializer deserialize:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserialize_whenDataInvalid_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] initForTokenType:MSIDTokenTypeAccessToken];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDBaseCacheItem *token = [serializer deserialize:data];
    
    XCTAssertNil(token);
}

#pragma mark - Private

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
