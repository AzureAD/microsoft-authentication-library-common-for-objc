//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDCredentialCacheItem.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDBaseToken.h"
#import "MSIDAccessToken.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDTestConfiguration.h"
#import "MSIDAccount.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDIdToken.h"

@interface MSIDTokenFilteringHelperTests : XCTestCase

@end

@implementation MSIDTokenFilteringHelperTests

#pragma mark - Generic

- (void)testFilterTokenCacheItems_whenReturnFirstYesAndFilterAll_shouldReturnOneItem
{
    MSIDCredentialCacheItem *testItem = [MSIDCredentialCacheItem new];
    testItem.environment = @"login.microsoftonline.com";
    testItem.realm = @"contoso.com";
    testItem.clientId = DEFAULT_TEST_CLIENT_ID;
    testItem.secret = @"id";
    testItem.credentialType = MSIDIDTokenType;
    
    NSArray *input = @[testItem, testItem];
    
    NSArray *result = [MSIDTokenFilteringHelper filterTokenCacheItems:input
                                                            tokenType:MSIDIDTokenType
                                                          returnFirst:YES
                                                             filterBy:^BOOL(MSIDCredentialCacheItem *tokenCacheItem) {
                                                                 return YES;
                                                             }];
    
    XCTAssertEqual([result count], 1);
    
    MSIDIdToken *expectedToken = [MSIDIdToken new];
    expectedToken.environment = @"login.microsoftonline.com";
    expectedToken.realm = @"contoso.com";
    expectedToken.clientId = DEFAULT_TEST_CLIENT_ID;
    expectedToken.rawIdToken = @"id";
    
    XCTAssertEqualObjects(result[0], expectedToken);
}

- (void)testFilterTokenCacheItems_whenReturnFirstNoAndFilterAll_shouldReturnTwoItems
{
    MSIDCredentialCacheItem *testItem = [MSIDCredentialCacheItem new];
    testItem.environment = @"login.microsoftonline.com";
    testItem.realm = @"contoso.com";
    testItem.clientId = DEFAULT_TEST_CLIENT_ID;
    testItem.secret = @"id";
    testItem.credentialType = MSIDIDTokenType;
    
    NSArray *input = @[testItem, testItem];
    
    NSArray *result = [MSIDTokenFilteringHelper filterTokenCacheItems:input
                                                            tokenType:MSIDIDTokenType
                                                          returnFirst:NO
                                                             filterBy:^BOOL(MSIDCredentialCacheItem *tokenCacheItem) {
                                                                 return YES;
                                                             }];
    
    XCTAssertEqual([result count], 2);
    
    MSIDIdToken *expectedToken = [MSIDIdToken new];
    expectedToken.environment = @"login.microsoftonline.com";
    expectedToken.realm = @"contoso.com";
    expectedToken.clientId = DEFAULT_TEST_CLIENT_ID;
    expectedToken.rawIdToken = @"id";

    XCTAssertEqualObjects(result[0], expectedToken);
    XCTAssertEqualObjects(result[1], expectedToken);
}

- (void)testFilterTokenCacheItems_whenReturnFirstYesAndFilterNone_shouldReturnEmptyResult
{
    NSArray *input = @[[MSIDCredentialCacheItem new], [MSIDCredentialCacheItem new]];
    
    NSArray *result = [MSIDTokenFilteringHelper filterTokenCacheItems:input
                                                            tokenType:MSIDCredentialTypeOther
                                                          returnFirst:YES
                                                             filterBy:^BOOL(MSIDCredentialCacheItem *tokenCacheItem) {
                                                                 return NO;
                                                             }];
    
    XCTAssertEqual([result count], 0);
}

- (void)testFilterTokenCacheItems_whenReturnFirstNoFilterNone_shouldReturnEmptyResult
{
    NSArray *input = @[[MSIDCredentialCacheItem new], [MSIDCredentialCacheItem new]];
    
    NSArray *result = [MSIDTokenFilteringHelper filterTokenCacheItems:input
                                                            tokenType:MSIDCredentialTypeOther
                                                          returnFirst:NO
                                                             filterBy:^BOOL(MSIDCredentialCacheItem *tokenCacheItem) {
                                                                 return NO;
                                                             }];
    
    XCTAssertEqual([result count], 0);
}

@end

