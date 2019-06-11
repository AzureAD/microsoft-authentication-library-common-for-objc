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
#import "MSIDKeyedArchiverSerializer.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDLegacyTokenCacheItem.h"
#import "MSIDClientInfo.h"

@interface MSIDKeyedArchiverSerializerTests : XCTestCase

@end

@implementation MSIDKeyedArchiverSerializerTests

#pragma mark - Token cache item

- (void)test_whenSerializeToken_shouldReturnSameTokenOnDeserialize
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    
    MSIDLegacyTokenCacheItem *cacheItem = [[MSIDLegacyTokenCacheItem alloc] init];
    cacheItem.refreshToken = @"refresh token value";
    cacheItem.familyId = @"familyId value";
    cacheItem.environment = @"contoso.com";
    cacheItem.realm = @"common";
    cacheItem.speInfo = @"test";
    cacheItem.clientId = @"some clientId";
    cacheItem.credentialType = MSIDRefreshTokenType;
    cacheItem.oauthTokenType = @"access token type";
    cacheItem.secret = cacheItem.refreshToken;
    
    NSData *data = [serializer serializeCredentialCacheItem:cacheItem];
    MSIDCredentialCacheItem *resultToken = [serializer deserializeCredentialCacheItem:data];
    
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(resultToken, cacheItem);
}

- (void)test_whenSerializeCredential_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];

    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] init];
    cacheItem.secret = @"refresh token value";
    cacheItem.familyId = @"familyId value";
    cacheItem.speInfo = @"test";
    cacheItem.environment = @"login.microsoftonline.com";
    cacheItem.clientId = @"some clientId";
    cacheItem.credentialType = MSIDRefreshTokenType;

    NSData *data = [serializer serializeCredentialCacheItem:cacheItem];
    XCTAssertNil(data);
}

- (void)testSerialize_whenTokenNil_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:nil];
    
    XCTAssertNil(data);
}

- (void)testSerialize_whenTokenWithDefaultProperties_shouldReturnNotNilData
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    
    NSData *data = [serializer serializeCredentialCacheItem:[MSIDLegacyTokenCacheItem new]];
    
    XCTAssertNotNil(data);
}

- (void)testDeserialize_whenDataNilNil_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:nil];
    
    XCTAssertNil(token);
}

- (void)testDeserialize_whenDataInvalid_shouldReturnNil
{
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    NSData *data = [@"some" dataUsingEncoding:NSUTF8StringEncoding];
    
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:data];
    
    XCTAssertNil(token);
}

#pragma mark - Wipe data

- (void)testDeserializeCredentialCacheItem_whenWipeData_shouldReturnNil
{
    NSDictionary *wipeInfo = @{ @"bundleId" : @"bundleId",
                                @"wipeTime" : [NSDate date]
                                };
    
    NSData *wipeData = [NSKeyedArchiver archivedDataWithRootObject:wipeInfo];
    
    MSIDKeyedArchiverSerializer *serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    MSIDCredentialCacheItem *token = [serializer deserializeCredentialCacheItem:wipeData];
    
    XCTAssertNil(token);
}

#pragma mark - Private

- (MSIDClientInfo *)createClientInfo:(NSDictionary *)clientInfoDict
{
    NSString *base64String = [clientInfoDict msidBase64UrlJson];
    return [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
}

@end
