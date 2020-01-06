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
#import "MSIDAccountMetadataCacheItem.h"
#import "MSIDAccountMetadata.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAccountMetadataCacheItemTests : XCTestCase

@end

@implementation MSIDAccountMetadataCacheItemTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithClientId_whenClientNil_shouldReturnNil {
    NSString *clientId = nil;
    XCTAssertNil([[MSIDAccountMetadataCacheItem alloc] initWithClientId:clientId]);
}

- (void)testAddAccountMetadata_whenRequiredParamsNil_shouldReturnNo {
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"client-id"];
    
    NSError *error;
    
    MSIDAccountMetadata *accountMetadata = nil;
    XCTAssertFalse([cacheItem addAccountMetadata:accountMetadata forHomeAccountId:@"uid.utid" error:&error]);
    XCTAssertNotNil(error);
    
    error = nil;
    MSIDAccountMetadata *metadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"uid.utid" clientId:@"client-id"];
    
    NSString *homeAccountId = nil;
    XCTAssertFalse([cacheItem addAccountMetadata:metadata forHomeAccountId:homeAccountId error:&error]);
    XCTAssertNotNil(error);
}

- (void)testAddAccountMetadata_whenAccountMetadataValid_shouldAddIt {
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"client-id"];

    MSIDAccountMetadata *metadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"uid.utid" clientId:@"client-id"];
    [metadata updateSignInState:MSIDAccountMetadataStateSignedIn];
    NSError *error;
    XCTAssertTrue([cacheItem addAccountMetadata:metadata forHomeAccountId:@"uid.utid" error:&error]);
    XCTAssertNil(error);

    XCTAssertEqualObjects(metadata, [cacheItem accountMetadataForHomeAccountId:@"uid.utid"]);
}

- (void)testAccountMetadataForHomeAccountId_whenAccountMetadataMatched_shouldReturnIt {
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"client-id"];

    MSIDAccountMetadata *metadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"uid.utid" clientId:@"client-id"];
    [metadata updateSignInState:MSIDAccountMetadataStateSignedIn];
    XCTAssertTrue([cacheItem addAccountMetadata:metadata forHomeAccountId:@"uid.utid" error:nil]);

    XCTAssertNil([cacheItem accountMetadataForHomeAccountId:@"uid.utid2"]);
    XCTAssertEqualObjects(metadata, [cacheItem accountMetadataForHomeAccountId:@"uid.utid"]);
}

- (void)testJSONDictionary_whenAllFieldsSet_shouldReturnJSONDictionaryWithAccountKey
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];

    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    MSIDAccountMetadata *accountMetadata2 = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId2" clientId:@"clientId"];

    NSError *error;
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority3.com"]
                                  instanceAware:YES
                                          error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertTrue([cacheItem addAccountMetadata:accountMetadata forHomeAccountId:@"homeAccountId" error:nil]);

    XCTAssertNil(error);
    XCTAssertTrue([accountMetadata2 setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                   forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                   instanceAware:NO
                                           error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([cacheItem addAccountMetadata:accountMetadata2 forHomeAccountId:@"homeAccountId2" error:nil]);

    __auto_type *expected = @{
        MSID_CLIENT_ID_CACHE_KEY : @"clientId",
        MSID_ACCOUNT_METADATA_MAP_CACHE_KEY : @{@"homeAccountId" : @{ @"client_id" : @"clientId",
                                                                      @"home_account_id" : @"homeAccountId",
                                                                      @"sign_in_state" : @"signed_in",
                                                                      @"athority_map" : @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso.com", @"https://testAuthority2.com" : @"https://contoso2.com"}, @"URLMap-instance_aware=YES" :  @{ @"https://testAuthority3.com" : @"https://contoso3.com"}}},
                                                @"homeAccountId2" : @{ @"client_id" : @"clientId",
                                                                       @"home_account_id" : @"homeAccountId2",
                                                                       @"sign_in_state" : @"signed_in",
                                                                       @"athority_map" : @{ @"URLMap-" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}}}
        }};

    XCTAssertEqualObjects(cacheItem.jsonDictionary, expected);
}

- (void)testInitWithJSONDictionary_whenAllJSONFieldsSet_shouldHaveCorrectItem
{
    NSDictionary *accountMetadataJson1 = @{ @"client_id" : @"clientId",
                                            @"home_account_id" : @"homeAccountId",
                                            @"sign_in_state" : @"signed_in",
                                            @"athority_map" : @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso.com", @"https://testAuthority2.com" : @"https://contoso2.com"}, @"URLMap-instance_aware=YES" :  @{ @"https://testAuthority3.com" : @"https://contoso3.com"}}};
    NSDictionary *accountMetadataJson2 = @{ @"client_id" : @"clientId",
                                            @"home_account_id" : @"homeAccountId2",
                                            @"sign_in_state" : @"signed_in",
                                            @"athority_map" : @{ @"URLMap-" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}}};

    NSDictionary *jsonDictionary = @{
        MSID_CLIENT_ID_CACHE_KEY : @"clientId",
        MSID_ACCOUNT_METADATA_MAP_CACHE_KEY : @{@"homeAccountId" : accountMetadataJson1,
                                                @"homeAccountId2" : accountMetadataJson2}};

    NSError *error = nil;
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(cacheItem);
    XCTAssertEqualObjects(cacheItem.clientId, @"clientId");
    XCTAssertEqualObjects([cacheItem accountMetadataForHomeAccountId:@"homeAccountId"].jsonDictionary, accountMetadataJson1);
    XCTAssertEqualObjects([cacheItem accountMetadataForHomeAccountId:@"homeAccountId2"].jsonDictionary, accountMetadataJson2);
}

- (void)testIsEqual_whenSame_shouldReturnYes
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    cacheItem.principalAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];
     
    MSIDAccountMetadataCacheItem *cacheItem2 = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    cacheItem2.principalAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];

    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    NSError *error;
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertNil(error);

    MSIDAccountMetadata *accountMetadata2 = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata2 setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                   forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                   instanceAware:NO
                                           error:&error]);
    XCTAssertNil(error);

    XCTAssertTrue([cacheItem addAccountMetadata:accountMetadata forHomeAccountId:@"homeAccountId" error:nil]);
    XCTAssertTrue([cacheItem2 addAccountMetadata:accountMetadata2 forHomeAccountId:@"homeAccountId" error:nil]);

    XCTAssertTrue([cacheItem isEqual:cacheItem2]);
}

- (void)testIsEqual_whenPrincipalAccountIdDifferent_shouldReturnNO
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    cacheItem.principalAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid2"];
     
    MSIDAccountMetadataCacheItem *cacheItem2 = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    cacheItem2.principalAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];

    XCTAssertFalse([cacheItem isEqual:cacheItem2]);
}

- (void)testIsEqual_whenClientIdDifferent_shouldReturnNo
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    MSIDAccountMetadataCacheItem *cacheItem2 = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId2"];
    XCTAssertFalse([cacheItem isEqual:cacheItem2]);
}

- (void)testIsEqual_whenAccountMetadataDifferent_shouldReturnNo
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    MSIDAccountMetadataCacheItem *cacheItem2 = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];

    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    NSError *error;
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertNil(error);

    MSIDAccountMetadata *accountMetadata2 = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata2 setCachedURL:[NSURL URLWithString:@"https://contoso.com2"]
                                   forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                   instanceAware:NO
                                           error:&error]);
    XCTAssertNil(error);

    XCTAssertTrue([cacheItem addAccountMetadata:accountMetadata forHomeAccountId:@"homeAccountId" error:nil]);
    XCTAssertTrue([cacheItem2 addAccountMetadata:accountMetadata2 forHomeAccountId:@"homeAccountId" error:nil]);
    
    XCTAssertFalse([cacheItem isEqual:cacheItem2]);
}

- (void)testGenerateCacheKey_whenGenerateKey_shouldReturnExpectedKey
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];

    MSIDCacheKey *key = [cacheItem generateCacheKey];
    XCTAssertEqualObjects(key.account, MSID_APP_METADATA_AUTHORITY_MAP_TYPE);
    XCTAssertEqualObjects(key.service, @"clientId");
}

- (void)testCopy_whenCopy_shouldDeepCopy
{
    MSIDAccountMetadataCacheItem *cacheItem = [[MSIDAccountMetadataCacheItem alloc] initWithClientId:@"clientId"];
    cacheItem.principalAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"upn@upn.com" homeAccountId:@"uid.utid"];

    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    NSError *error;
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([cacheItem addAccountMetadata:accountMetadata forHomeAccountId:@"homeAccountId" error:nil]);

    MSIDAccountMetadataCacheItem *cacheItem2 = [cacheItem copy];

    MSIDAccountMetadata *metadata = [cacheItem accountMetadataForHomeAccountId:@"homeAccountId"];
    MSIDAccountMetadata *metadata2 = [cacheItem2 accountMetadataForHomeAccountId:@"homeAccountId"];

    XCTAssertNotEqual(metadata, metadata2);
    XCTAssertEqualObjects(metadata, metadata2);
    XCTAssertEqualObjects(cacheItem, cacheItem2);
}

@end
