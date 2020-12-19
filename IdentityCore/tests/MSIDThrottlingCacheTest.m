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
#import "MSIDThrottlingCacheService.h"
#import "MSIDThrottlingCacheRecord.h"
#import "MSIDThrottlingCacheNode.h"

@interface MSIDThrottlingCacheTest : XCTestCase

@property (nonatomic) MSIDThrottlingCacheService *throttlingCacheService;

@end

@implementation MSIDThrottlingCacheTest

- (void)setUp {
    self.throttlingCacheService = [[MSIDThrottlingCacheService alloc] initThrottlingCacheService:5];
}

- (void)tearDown
{
    [self.throttlingCacheService removeRequestFromCache:@"1"];
    [self.throttlingCacheService removeRequestFromCache:@"2"];
    [self.throttlingCacheService removeRequestFromCache:@"3"];
    [self.throttlingCacheService removeRequestFromCache:@"4"];
    [self.throttlingCacheService removeRequestFromCache:@"5"];
    
}

- (void)testThrottlingCacheService_afterInsertingCacheRecords_headAndTailShouldReturnExpectedValues
{
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    
    MSIDThrottlingCacheNode *headNode = [self.throttlingCacheService getHeadNode];
    MSIDThrottlingCacheNode *tailNode = [self.throttlingCacheService getTailNode];
    
    XCTAssertEqualObjects(headNode.requestThumbprintKey,@"3");
    XCTAssertEqualObjects(headNode.nextRequestThumbprintKey,@"2");
    XCTAssertEqualObjects(tailNode.requestThumbprintKey,@"1");
    XCTAssertEqualObjects(tailNode.prevRequestThumbprintKey,@"2");
    
    
}

- (void)testThrottlingCacheService_mostRecentlyQueriedElementShouldAppearAtTheFront
{
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    //HEAD->5->4->3->2->1->TAIL
    //HEAD<-5<-4<-3<-2<-1<-TAIL
    MSIDThrottlingCacheNode *headNode = [self.throttlingCacheService getHeadNode];
    MSIDThrottlingCacheNode *tailNode = [self.throttlingCacheService getTailNode];
    XCTAssertEqualObjects(headNode.requestThumbprintKey,@"5");
    XCTAssertEqualObjects(tailNode.requestThumbprintKey,@"1");
    
    [self.throttlingCacheService getResponseFromCache:@"3"];
    //HEAD->3->5->4->2->1->TAIL;
    //HEAD<-3<-5<-4<-2<-1<-TAIL;
    NSArray *cachedElements = [self.throttlingCacheService enumerateAndReturnAllCachedObjects];
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[0]).requestThumbprintKey,@"3");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[1]).requestThumbprintKey,@"5");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[2]).requestThumbprintKey,@"4");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[3]).requestThumbprintKey,@"2");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[4]).requestThumbprintKey,@"1");
    

}

- (void)testThrottlingCacheService_whenReemovingElementFromCache_cacheOrderShouldBeUpdatedAsExpected
{
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20];
    
    [self.throttlingCacheService removeRequestFromCache:@"2"];
    [self.throttlingCacheService removeRequestFromCache:@"4"];
    
    NSArray *cachedElements = [self.throttlingCacheService enumerateAndReturnAllCachedObjects];
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[0]).requestThumbprintKey,@"5");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[1]).requestThumbprintKey,@"3");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[2]).requestThumbprintKey,@"1");
        
}




@end
