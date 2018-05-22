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
#import "MSIDAccountCacheItem.h"

@interface MSIDJsonSerializerTests : XCTestCase

@end

@implementation MSIDJsonSerializerTests

#pragma mark - Token cache item

- (void)test_whenSerializeCredentialCacheItem_shouldReturnSameTokenOnDeserialize
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] init];
    cacheItem.secret = @"refresh token value";
    cacheItem.familyId = @"familyId value";
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.additionalInfo = @{@"spe_info" : @"test"};
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.realm = @"contoso.com";
    cacheItem.clientId = @"some clientId";
    cacheItem.credentialType = MSIDRefreshTokenType;
    
    NSData *data = [serializer serializeCredentialCacheItem:cacheItem];
    MSIDCredentialCacheItem *resultToken = [serializer deserializeCredentialCacheItem:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, cacheItem);
}

- (void)testSerializeCredentialCacheItem_whenTokenNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerializeCredentialCacheItem_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:[MSIDCredentialCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserializeCredentialCacheItem_whenDataNilNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserializeCredentialCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:data];
    
    XCTAssertNil(token);
}

#pragma mark - Account item

- (void)test_whenSerializeAccountCacheItem_shouldReturnSameAccountOnDeserialize
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] init];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.familyName = @"Smith";
    cacheItem.givenName = @"Test";
    cacheItem.legacyUserId = @"upn";
    cacheItem.accountType = MSIDAccountTypeAADV2;
    
    NSData *data = [serializer serializeAccountCacheItem:cacheItem];
    MSIDAccountCacheItem *resultItem = [serializer deserializeAccountCacheItem:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultItem, cacheItem);
}

- (void)testSerializeAccountCacheItem_whenAccountNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeAccountCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerializeAccountCacheItem_whenAccountWithDefaultProperties_shouldReturnNotNilData
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeAccountCacheItem:[MSIDAccountCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserializeAccountCacheItem_whenDataNilNil_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    
    MSIDAccountCacheItem *account = [serializer deserializeAccountCacheItem:nil];
    
    XCTAssertNil(account);
}

- (void)testDeserializeAccountCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDJsonSerializer *serializer = [[MSIDJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAccountCacheItem *token = [serializer deserializeAccountCacheItem:data];
    
    XCTAssertNil(token);
}

#pragma mark - Private

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
