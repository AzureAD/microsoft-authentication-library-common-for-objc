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
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDBaseToken.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSIDCacheItemJsonSerializerTests : XCTestCase

@end

@implementation MSIDCacheItemJsonSerializerTests

#pragma mark - Token cache item

- (void)test_whenSerializeCredentialCacheItem_shouldReturnSameTokenOnDeserialize
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] init];
    cacheItem.secret = @"refresh token value";
    cacheItem.familyId = @"familyId value";
    cacheItem.speInfo = @"test";
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
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerializeCredentialCacheItem_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:[MSIDCredentialCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserializeCredentialCacheItem_whenDataNilNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserializeCredentialCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:data];
    
    XCTAssertNil(token);
}

#pragma mark - Account item

- (void)test_whenSerializeAccountCacheItem_shouldReturnSameAccountOnDeserialize
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDAccountCacheItem *cacheItem = [[MSIDAccountCacheItem alloc] init];
    cacheItem.clientInfo = [self createClientInfo:@{@"key" : @"value"}];
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.familyName = @"Smith";
    cacheItem.givenName = @"Test";
    cacheItem.localAccountId = @"00004-00004-00004";
    cacheItem.accountType = MSIDAccountTypeMSSTS;
    
    NSData *data = [serializer serializeCacheItem:cacheItem];
    MSIDAccountCacheItem *resultItem = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAccountCacheItem class]];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultItem, cacheItem);
}

- (void)testSerializeAccountCacheItem_whenAccountNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerializeAccountCacheItem_whenAccountWithDefaultProperties_shouldReturnNotNilData
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCacheItem:[MSIDAccountCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserializeAccountCacheItem_whenDataNilNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDAccountCacheItem *account = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:nil ofClass:[MSIDAccountCacheItem class]];
    
    XCTAssertNil(account);
}

- (void)testDeserializeAccountCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAccountCacheItem *token = (MSIDAccountCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAccountCacheItem class]];
    
    XCTAssertNil(token);
}

#pragma mark - App Metadata item

- (void)test_whenSerializeAppMetadataCacheItem_shouldReturnSameAppMetadataOnDeserialize
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDAppMetadataCacheItem *cacheItem = [[MSIDAppMetadataCacheItem alloc] init];
    cacheItem.clientId = @"clientId";
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.familyId = @"1";
    
    NSData *data = [serializer serializeCacheItem:cacheItem];
    MSIDAppMetadataCacheItem *resultItem = (MSIDAppMetadataCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAppMetadataCacheItem class]];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultItem, cacheItem);
}

- (void)testSerializeAppMetadataCacheItem_whenAppMetadataNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerializeAppMetadataCacheItem_whenAppMetadataWithDefaultProperties_shouldReturnNotNilData
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    NSData *data = [serializer serializeCacheItem:[MSIDAppMetadataCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserializeAppMetadataCacheItem_whenDataNilNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)[serializer deserializeCacheItem:nil ofClass:[MSIDAppMetadataCacheItem class]];
    
    XCTAssertNil(appMetadata);
}

- (void)testDeserializeAppMetadataCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAppMetadataCacheItem *appMetadata = (MSIDAppMetadataCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAppMetadataCacheItem class]];
    
    XCTAssertNil(appMetadata);
}

#pragma mark - Account metadata

- (void)testSerializeAccountMetadataCacheItem_andDeserialized_shouldReturnSameItem
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    [cacheItem setCachedURL:[NSURL URLWithString:@"https://internalcontoso.com"] forRequestURL:[NSURL URLWithString:@"https://consoto.com"] instanceAware:NO error:nil];
    
    NSData *data = [serializer serializeCacheItem:cacheItem];
    MSIDAccountMetadataCacheItem *resultItem = (MSIDAccountMetadataCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAccountMetadataCacheItem class]];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultItem, cacheItem);
}

- (void)testDeserializeAccountMetadata_whenDataIsValid_shouldReturnAccount {
    NSDictionary *jsonDict = @{ @"home_account_id": @"homeAccountId",
                                @"client_id": @"clientId",
                                @"account_metadata" : @{ @"URLMap-" :
                                                             @{ @"https://contoso.com" : @"https://internalcontoso.com" }
                                                         }};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:nil];
    
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    MSIDAccountMetadataCacheItem *cacheItem = (MSIDAccountMetadataCacheItem *)[serializer deserializeCacheItem:jsonData ofClass:[MSIDAccountMetadataCacheItem class]];
    
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    XCTAssertEqualObjects([cacheItem cachedURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO], [NSURL URLWithString:@"https://internalcontoso.com"]);
}

- (void)testSerializeAccountMetadataCacheItem_whenDataIsNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    NSData *data = [serializer serializeCacheItem:nil];
    XCTAssertNil(data);
}


- (void)testDeserializeAccountMetadataCacheItem_whenDataIsNil_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    MSIDAccountMetadataCacheItem *appMetadata = (MSIDAccountMetadataCacheItem *)[serializer deserializeCacheItem:nil ofClass:[MSIDAccountMetadataCacheItem class]];
    XCTAssertNil(appMetadata);
}

- (void)testDeserializeAccountMetadataCacheItem_whenDataInvalid_shouldReturnNil
{
    MSIDCacheItemJsonSerializer *serializer = [[MSIDCacheItemJsonSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDAccountMetadataCacheItem *appMetadata = (MSIDAccountMetadataCacheItem *)[serializer deserializeCacheItem:data ofClass:[MSIDAccountMetadataCacheItem class]];
    XCTAssertNil(appMetadata);
}



#pragma mark - Private

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
