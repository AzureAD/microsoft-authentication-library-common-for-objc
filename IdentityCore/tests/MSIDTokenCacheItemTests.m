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
#import "MSIDTokenCacheItem.h"
#import "MSIDTestCacheIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSIDTokenCacheItemTests : XCTestCase

@end

@implementation MSIDTokenCacheItemTests

- (void)test_whenKeyedArchivingToken_shouldReturnSameTokenOnDeserialize
{
    MSIDTokenCacheItem *cacheItem = [MSIDTokenCacheItem new];
    cacheItem.authority = [NSURL URLWithString:DEFAULT_TEST_AUTHORITY];
    cacheItem.username = DEFAULT_TEST_ID_TOKEN_USERNAME;
    cacheItem.uniqueUserId = DEFAULT_TEST_ID_TOKEN_USERNAME;
    
    NSString *clientInfoString = [@{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID} msidBase64UrlJson];
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:clientInfoString error:nil];
    cacheItem.clientInfo = clientInfo;
    cacheItem.additionalInfo = @{@"test": @"2"};
    cacheItem.clientId = DEFAULT_TEST_CLIENT_ID;
    cacheItem.tokenType = MSIDTokenTypeAccessToken;
    cacheItem.accessToken = DEFAULT_TEST_ACCESS_TOKEN;
    cacheItem.refreshToken = DEFAULT_TEST_REFRESH_TOKEN;
    cacheItem.idToken = DEFAULT_TEST_ID_TOKEN;
    cacheItem.target = DEFAULT_TEST_RESOURCE;
    
    NSDate *expiresOn = [NSDate date];
    NSDate *cachedAt = [NSDate date];
    
    cacheItem.expiresOn = expiresOn;
    cacheItem.cachedAt = cachedAt;
    cacheItem.familyId = DEFAULT_TEST_FAMILY_ID;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cacheItem];
    
    XCTAssertNotNil(data);
    
    MSIDTokenCacheItem *newItem = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertNotNil(newItem);
    
    XCTAssertEqualObjects(newItem.authority, [NSURL URLWithString:DEFAULT_TEST_AUTHORITY]);
    XCTAssertEqualObjects(newItem.username, DEFAULT_TEST_ID_TOKEN_USERNAME);
    XCTAssertEqualObjects(newItem.additionalInfo, @{@"test": @"2"});
    XCTAssertEqualObjects(newItem.clientInfo, clientInfo);
    
    NSString *uniqueUserId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    XCTAssertEqualObjects(newItem.uniqueUserId, uniqueUserId);
    XCTAssertEqualObjects(newItem.clientId, DEFAULT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(newItem.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
    XCTAssertEqualObjects(newItem.refreshToken, DEFAULT_TEST_REFRESH_TOKEN);
    XCTAssertEqualObjects(newItem.idToken, DEFAULT_TEST_ID_TOKEN);
    XCTAssertEqualObjects(newItem.target, DEFAULT_TEST_RESOURCE);
    XCTAssertEqualObjects(newItem.expiresOn, expiresOn);
    XCTAssertEqualObjects(newItem.cachedAt, cachedAt);
    XCTAssertEqualObjects(newItem.familyId, DEFAULT_TEST_FAMILY_ID);
}

@end
