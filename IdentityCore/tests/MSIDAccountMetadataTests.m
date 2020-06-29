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
#import "MSIDAccountMetadata.h"
#import "MSIDAccountIdentifier.h"

@interface MSIDAccountMetadataTests : XCTestCase

@end

@implementation MSIDAccountMetadataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testJSONDictionary_whenAllFieldsSet_shouldReturnJSONDictionaryWithAccountKey
{
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    
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
    XCTAssertNil(error);
    
    __auto_type *expected = @{ @"athority_map" : @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso.com", @"https://testAuthority2.com" : @"https://contoso2.com"}, @"URLMap-instance_aware=YES" :  @{ @"https://testAuthority3.com" : @"https://contoso3.com"} },
                               @"client_id" : @"clientId",
                               @"home_account_id" : @"homeAccountId",
                               @"sign_in_state" : @"signed_in"
    };
    
    XCTAssertEqualObjects(accountMetadata.jsonDictionary, expected);
}

#pragma mark - JSON deserialization

- (void)testInitWithJSONDictionary_whenAllJSONFieldsSet_shouldHaveCorrectItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId" };
    
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accountMetadata);
    XCTAssertEqualObjects(accountMetadata.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(accountMetadata.clientId, @"clientId");
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateUnknown);
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority.com"] instanceAware:NO]);
}

- (void)testInitWithJSONDictionary_whenEmptyAccountMetadata_shouldReturnNilItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId",
                                      @"sign_in_state" : @"signed_in",
                                      @"athority_map" : @{}
    };
    
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accountMetadata);
    XCTAssertEqualObjects(accountMetadata.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(accountMetadata.clientId, @"clientId");
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedIn);
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority.com"] instanceAware:NO]);
}

- (void)testInitWithJSONDictionary_whenAccountMetadataAvailable_shouldReturnCorrectItem
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId",
                                      @"sign_in_state" : @"signed_in",
                                      @"athority_map" : @{ @"URLMap-" : @{
                                                                   @"https://testAuthority1.com" : @"https://contoso1.com",
                                                                   @"https://testAuthority2.com" : @"https://contoso2.com"},
                                                           @"URLMap-instance_aware=YES" : @{
                                                                   @"https://testAuthority3.com" : @"https://contoso3.com"}
                                      }
    };
    
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accountMetadata);
    XCTAssertEqualObjects(accountMetadata.homeAccountId, @"homeAccountId");
    XCTAssertEqualObjects(accountMetadata.clientId, @"clientId");
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedIn);
    //not available because of url
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://notexist.com"] instanceAware:NO]);
    //not available because of instance aware
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:YES]);
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority3.com"] instanceAware:NO]);
    //available
    XCTAssertEqualObjects([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO].absoluteString, @"https://contoso1.com");
    XCTAssertEqualObjects([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority3.com"] instanceAware:YES].absoluteString, @"https://contoso3.com");
}

#pragma mark - Authority map caching

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresent_shouldSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:YES
                                          error:&error]);
    NSDictionary *expectedMap = @{ @"URLMap-" : @{ @"https://testAuthority1.com" : @"https://contoso1.com"},
                                   @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}
    };
    XCTAssertEqualObjects(accountMetadata.auhtorityMap, expectedMap);
}

- (void)testSetCachedURL_whenCacheURLAndRequestURLPresentWhenRecordAlreadyExists_shouldOverwriteAndSaveMapping
{
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:YES
                                          error:&error]);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority.com"]
                                  instanceAware:NO
                                          error:&error]);
    
    NSDictionary *expectedMap = @{ @"URLMap-" : @{ @"https://testAuthority.com" : @"https://contoso3.com"},
                                   @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}
    };
    XCTAssertEqualObjects(accountMetadata.auhtorityMap, expectedMap);
}

- (void)testSetCachedURL_whenSetCacheURL_shouldSetSignInStateSignedIn
{
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedIn);
    
    // Mark signed out
    [accountMetadata updateSignInState:MSIDAccountMetadataStateSignedOut];
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedOut);
    
    // Set URL again
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:YES
                                          error:&error]);
    
    // Should flip signed out state
    NSDictionary *expectedMap = @{ @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}
    };
    XCTAssertEqualObjects(accountMetadata.auhtorityMap, expectedMap);
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedIn);
}

- (void)testCachedURL_withCachedRequestURLNotMapped_shouldReturnNil
{
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://contoso.com"] instanceAware:NO]);
}

- (void)testCachedURL_whenSignedOut_shouldReturnNil
{
    NSDictionary *jsonDictionary = @{ @"client_id" : @"clientId",
                                      @"home_account_id" : @"homeAccountId",
                                      @"athority_map" : @{ @"URLMap-" : @{
                                                                   @"https://testAuthority1.com" : @"https://contoso1.com",
                                                                   @"https://testAuthority2.com" : @"https://contoso2.com"},
                                                           @"URLMap-instance_aware=YES" : @{
                                                                   @"https://testAuthority3.com" : @"https://contoso3.com"}
                                      },
                                      @"sign_in_state" : @"signed_out"
    };
    
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accountMetadata);
    
    //Not returning any url because it is in signed out state
    XCTAssertNil([accountMetadata cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO].absoluteString);
}

- (void)testAccountMetadataCopy_withOriginalObjectChanged_shouldNotChangeCopiedObject
{
    NSError *error = nil;
    MSIDAccountMetadata *item1 = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"home_account_id" clientId:@"clientId"];
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                        instanceAware:YES
                                error:&error]);
    
    MSIDAccountMetadata *item2 = [item1 copy];
    
    XCTAssertTrue([item1 setCachedURL:[NSURL URLWithString:@"https://contoso3.com"]
                        forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                        instanceAware:NO
                                error:&error]);
    
    NSURL *cacheURLForItem1 = [item1 cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO];
    XCTAssertNotNil(cacheURLForItem1);
    
    NSURL *cacheURLForItem2 = [item2 cachedURL:[NSURL URLWithString:@"https://testAuthority1.com"] instanceAware:NO];
    XCTAssertNotNil(cacheURLForItem2);
    
    XCTAssertNotEqualObjects(cacheURLForItem1, cacheURLForItem2);
}

- (void)testAccountMetadataIsEqual_whenSignedOutStateDifferent_shouldNotBeEqual
{
    NSDictionary *jsonDictionary1 = @{ @"client_id" : @"clientId",
                                       @"home_account_id" : @"homeAccountId",
                                       @"athority_map" : @{ @"URLMap-" : @{
                                                                    @"https://testAuthority1.com" : @"https://contoso1.com",
                                                                    @"https://testAuthority2.com" : @"https://contoso2.com"},
                                                            @"URLMap-instance_aware=YES" : @{
                                                                    @"https://testAuthority3.com" : @"https://contoso3.com"}
                                       },
                                       @"sign_in_state" : @"signed_in"
    };
    
    NSDictionary *jsonDictionary2 = @{ @"client_id" : @"clientId",
                                       @"home_account_id" : @"homeAccountId",
                                       @"athority_map" : @{ @"URLMap-" : @{
                                                                    @"https://testAuthority1.com" : @"https://contoso1.com",
                                                                    @"https://testAuthority2.com" : @"https://contoso2.com"},
                                                            @"URLMap-instance_aware=YES" : @{
                                                                    @"https://testAuthority3.com" : @"https://contoso3.com"}
                                       },
                                       @"sign_in_state" : @"unknown"
    };
    
    NSError *error = nil;
    MSIDAccountMetadata *item1 = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary1 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(item1);
    
    MSIDAccountMetadata *item2 = [[MSIDAccountMetadata alloc] initWithJSONDictionary:jsonDictionary2 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(item2);
    
    XCTAssertNotEqualObjects(item1, item2);
}

- (void)testUpdateSignInState_whenSetSignedOut_shouldWipeAuthorityMap
{
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:YES
                                          error:&error]);
    
    [accountMetadata updateSignInState:MSIDAccountMetadataStateSignedOut];
    
    NSDictionary *expectedMap = @{};
    XCTAssertEqualObjects(accountMetadata.auhtorityMap, expectedMap);
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateSignedOut);
}

- (void)testUpdateSignInState_whenSetNonSignedOut_shouldNotWipeAuthorityMap
{
    NSError *error = nil;
    MSIDAccountMetadata *accountMetadata = [[MSIDAccountMetadata alloc] initWithHomeAccountId:@"homeAccountId" clientId:@"clientId"];
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso1.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority1.com"]
                                  instanceAware:NO
                                          error:&error]);
    XCTAssertTrue([accountMetadata setCachedURL:[NSURL URLWithString:@"https://contoso2.com"]
                                  forRequestURL:[NSURL URLWithString:@"https://testAuthority2.com"]
                                  instanceAware:YES
                                          error:&error]);
    
    [accountMetadata updateSignInState:MSIDAccountMetadataStateUnknown];
    
    NSDictionary *expectedMap = @{ @"URLMap-" : @{ @"https://testAuthority1.com" : @"https://contoso1.com"},
                                   @"URLMap-instance_aware=YES" : @{ @"https://testAuthority2.com" : @"https://contoso2.com"}};
    XCTAssertEqualObjects(accountMetadata.auhtorityMap, expectedMap);
    XCTAssertEqual(accountMetadata.signInState, MSIDAccountMetadataStateUnknown);
}

@end
