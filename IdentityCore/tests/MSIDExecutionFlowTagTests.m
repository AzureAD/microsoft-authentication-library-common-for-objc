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
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowPrepareNetworkRequestTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseFailedObjectTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseSucceededObjectTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowReceiveNetworkResponseTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowRetryOnNetworkFailureTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowParseNetworkResponseTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowOtherHttpNetworkStatusCodeTag)
    ];
    
    NSSet *uniqueTags = [NSSet setWithArray:tags];
    XCTAssertEqual(tags.count, uniqueTags.count, @"Duplicate tags found in MSIDExecutionFlowNetworkTagToString");
}

- (void)test_MSIDTokenRequestTagToString_allTagsAreUnique
{
    NSArray *tags = @[
        MSIDTokenRequestTagToString(MSIDTokenRequestAtExpirationElapsedTag)
    ];
    
    NSSet *uniqueTags = [NSSet setWithArray:tags];
    XCTAssertEqual(tags.count, uniqueTags.count, @"Duplicate tags found in MSIDTokenRequestTagToString");
}

- (void)test_allTagsAreGloballyUnique
{
    NSMutableArray *allTags = [NSMutableArray array];
    
    [allTags addObjectsFromArray:@[
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowPrepareNetworkRequestTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseFailedObjectTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseSucceededObjectTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowReceiveNetworkResponseTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowRetryOnNetworkFailureTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowParseNetworkResponseTag),
        MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowOtherHttpNetworkStatusCodeTag)
    ]];
    
    [allTags addObjectsFromArray:@[
        MSIDTokenRequestTagToString(MSIDTokenRequestAtExpirationElapsedTag)
    ]];
    
    NSSet *uniqueTags = [NSSet setWithArray:allTags];
    XCTAssertEqual(allTags.count, uniqueTags.count, @"Duplicate tags found across all tag functions");
}

- (void)test_MSIDExecutionFlowNetworkTagToString_returnsExpectedStrings
{
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowPrepareNetworkRequestTag), @"iq24n");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseFailedObjectTag), @"twoty");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowCacheResponseSucceededObjectTag), @"n3416");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowReceiveNetworkResponseTag), @"xfx8w");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowRetryOnNetworkFailureTag), @"rz95n");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowParseNetworkResponseTag), @"fxjo7");
    XCTAssertEqualObjects(MSIDExecutionFlowNetworkTagToString(MSIDExecutionFlowOtherHttpNetworkStatusCodeTag), @"5kbvm");
}

- (void)test_MSIDTokenRequestTagToString_returnsExpectedStrings
{
    XCTAssertEqualObjects(MSIDTokenRequestTagToString(MSIDTokenRequestAtExpirationElapsedTag), @"riwx7");
}

- (void)test_MSIDExecutionFlowNetworkTagToString_unknownEnum_returnsFallback
{
    NSString *result = MSIDExecutionFlowNetworkTagToString((MSIDExecutionFlowNetworkTag)9999);
    XCTAssertTrue([result containsString:@"MSIDExecutionFlowNetworkTag"]);
    XCTAssertTrue([result containsString:@"9999"]);
}

- (void)test_MSIDTokenRequestTagToString_unknownEnum_returnsFallback
{
    NSString *result = MSIDTokenRequestTagToString((MSIDTokenRequestTag)9999);
    XCTAssertTrue([result containsString:@"MSIDTokenRequestTag"]);
    XCTAssertTrue([result containsString:@"9999"]);
}

@end
