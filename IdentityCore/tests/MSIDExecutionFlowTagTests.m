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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

#import <XCTest/XCTest.h>
#import "MSIDExecutionFlowConstants.h"

@interface MSIDExecutionFlowConstantsTests : XCTestCase

@end

@implementation MSIDExecutionFlowConstantsTests

- (void)test_MSIDExecutionFlowNetworkTagToString_allTagsAreUnique
{
    NSArray *tags = @[
        MSIDStringFromExecutionFlowNetworkTag(MSIDPrepareNetworkRequestTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseFailedObjectTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseSucceededObjectTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDReceiveNetworkResponseTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDRetryOnNetworkFailureTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDParseNetworkResponseTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDOtherHttpNetworkStatusCodeTag)
    ];
    
    NSSet *uniqueTags = [NSSet setWithArray:tags];
    XCTAssertEqual(tags.count, uniqueTags.count, @"Duplicate tags found in MSIDStringFromExecutionFlowNetworkTag");
}

- (void)test_MSIDTokenRequestTagToString_allTagsAreUnique
{
    NSArray *tags = @[
        MSIDStringFromTokenRequestTag(MSIDAtExpirationElapsedTag)
    ];
    
    NSSet *uniqueTags = [NSSet setWithArray:tags];
    XCTAssertEqual(tags.count, uniqueTags.count, @"Duplicate tags found in MSIDStringFromTokenRequestTag");
}

- (void)test_allTagsAreGloballyUnique
{
    NSMutableArray *allTags = [NSMutableArray array];
    
    [allTags addObjectsFromArray:@[
        MSIDStringFromExecutionFlowNetworkTag(MSIDPrepareNetworkRequestTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseFailedObjectTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseSucceededObjectTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDReceiveNetworkResponseTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDRetryOnNetworkFailureTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDParseNetworkResponseTag),
        MSIDStringFromExecutionFlowNetworkTag(MSIDOtherHttpNetworkStatusCodeTag)
    ]];
    
    [allTags addObjectsFromArray:@[
        MSIDStringFromTokenRequestTag(MSIDAtExpirationElapsedTag)
    ]];
    
    NSSet *uniqueTags = [NSSet setWithArray:allTags];
    XCTAssertEqual(allTags.count, uniqueTags.count, @"Duplicate tags found across all tag functions");
}

- (void)test_MSIDExecutionFlowNetworkTagToString_returnsExpectedStrings
{
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDPrepareNetworkRequestTag), @"iq24n");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseFailedObjectTag), @"twoty");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDCacheResponseSucceededObjectTag), @"n3416");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDReceiveNetworkResponseTag), @"xfx8w");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDRetryOnNetworkFailureTag), @"rz95n");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDParseNetworkResponseTag), @"fxjo7");
    XCTAssertEqualObjects(MSIDStringFromExecutionFlowNetworkTag(MSIDOtherHttpNetworkStatusCodeTag), @"5kbvm");
}

- (void)test_MSIDTokenRequestTagToString_returnsExpectedStrings
{
    XCTAssertEqualObjects(MSIDStringFromTokenRequestTag(MSIDAtExpirationElapsedTag), @"xilux");
}

- (void)test_MSIDExecutionFlowNetworkTagToString_unknownEnum_returnsFallback
{
    NSString *result = MSIDStringFromExecutionFlowNetworkTag((MSIDExecutionFlowNetworkTag)9999);
    XCTAssertTrue([result containsString:@"MSIDExecutionFlowNetworkTag"]);
    XCTAssertTrue([result containsString:@"9999"]);
}

- (void)test_MSIDTokenRequestTagToString_unknownEnum_returnsFallback
{
    NSString *result = MSIDStringFromTokenRequestTag((MSIDTokenRequestTag)9999);
    XCTAssertTrue([result containsString:@"MSIDTokenRequestTag"]);
    XCTAssertTrue([result containsString:@"9999"]);
}

@end
