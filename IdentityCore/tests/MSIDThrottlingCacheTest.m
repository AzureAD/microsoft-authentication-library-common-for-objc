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


@interface MSIDThrottlingCacheService (Test)

- (MSIDThrottlingCacheNode *)getHeadNode; //query first element without disturbing order

- (MSIDThrottlingCacheNode *)getTailNode; //query last element without disturbing order

- (void)threadSafetyTest;

@end

@interface MSIDThrottlingCacheTest : XCTestCase

@property (nonatomic) MSIDThrottlingCacheService *throttlingCacheService;

@end

@implementation MSIDThrottlingCacheTest

- (void)setUp {
    self.throttlingCacheService = [MSIDThrottlingCacheService sharedInstance:5];
}

- (void)tearDown
{
    [self.throttlingCacheService removeRequestFromCache:@"1"
                                                  error:nil];
    [self.throttlingCacheService removeRequestFromCache:@"2"
                                                  error:nil];
    [self.throttlingCacheService removeRequestFromCache:@"3"
                                                  error:nil];
    [self.throttlingCacheService removeRequestFromCache:@"4"
                                                  error:nil];
    [self.throttlingCacheService removeRequestFromCache:@"5"
                                                  error:nil];
    
}

- (void)testThrottlingCacheService_afterInsertingCacheRecords_headAndTailShouldReturnExpectedValues
{
    NSError *subError = nil;
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    
    MSIDThrottlingCacheNode *headNode = [self.throttlingCacheService getHeadNode];
    MSIDThrottlingCacheNode *tailNode = [self.throttlingCacheService getTailNode];
    
    XCTAssertNil(subError);
    XCTAssertEqualObjects(headNode.requestThumbprintKey,@"3");
    XCTAssertEqualObjects(headNode.nextRequestThumbprintKey,@"2");
    XCTAssertEqualObjects(tailNode.requestThumbprintKey,@"1");
    XCTAssertEqualObjects(tailNode.prevRequestThumbprintKey,@"2");
    
    
}

- (void)testThrottlingCacheService_mostRecentlyQueriedElementShouldAppearAtTheFront
{
    NSError *subError = nil;
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    //HEAD->5->4->3->2->1->TAIL
    //HEAD<-5<-4<-3<-2<-1<-TAIL
    MSIDThrottlingCacheNode *headNode = [self.throttlingCacheService getHeadNode];
    MSIDThrottlingCacheNode *tailNode = [self.throttlingCacheService getTailNode];
    XCTAssertEqualObjects(headNode.requestThumbprintKey,@"5");
    XCTAssertEqualObjects(tailNode.requestThumbprintKey,@"1");
    
    [self.throttlingCacheService getResponseFromCache:@"3"
                                                error:&subError];
    //HEAD->3->5->4->2->1->TAIL;
    //HEAD<-3<-5<-4<-2<-1<-TAIL;
    NSArray *cachedElements = [self.throttlingCacheService enumerateAndReturnAllObjects];
    
    XCTAssertNil(subError);
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[0]).requestThumbprintKey,@"3");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[1]).requestThumbprintKey,@"5");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[2]).requestThumbprintKey,@"4");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[3]).requestThumbprintKey,@"2");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[4]).requestThumbprintKey,@"1");
    

}

- (void)testThrottlingCacheService_whenRemovingElementFromCache_cacheOrderShouldBeUpdatedAsExpected
{
    NSError *subError = nil;
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService removeRequestFromCache:@"2"
                                                  error:&subError];
    
    [self.throttlingCacheService removeRequestFromCache:@"4"
                                                  error:&subError];
    
    NSArray *cachedElements = [self.throttlingCacheService enumerateAndReturnAllObjects];
    
    XCTAssertNil(subError);
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[0]).requestThumbprintKey,@"5");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[1]).requestThumbprintKey,@"3");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[2]).requestThumbprintKey,@"1");
        
}

- (void)testThrottlingCacheService_InvokingRemoveAllExpiredObjects_shouldRemoveAllExpiredObjectsFromCache
{
    NSError *subError = nil;
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:3
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:3
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"dummy"
                                  throttleDuration:4
                                             error:&subError];
    

    
    sleep(5);
    
    [self.throttlingCacheService removeAllExpiredObjects:&subError];
    
    
    NSArray *cachedElements = [self.throttlingCacheService enumerateAndReturnAllObjects];
    XCTAssertNil(subError);
    XCTAssertEqual(cachedElements.count,2);
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[0]).requestThumbprintKey,@"3");
    XCTAssertEqualObjects(((MSIDThrottlingCacheNode *)cachedElements[1]).requestThumbprintKey,@"2");
        
}

- (void)testThrottlingCacheService_uponHeavyCacheReadAttempts_cacheShouldReturnExpectedResultsReliably
{
    NSError *subError = nil;
    [self.throttlingCacheService addRequestToCache:@"1"
                                     errorResponse:nil
                                      throttleType:@"matthew"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"2"
                                     errorResponse:nil
                                      throttleType:@"mark"
                                  throttleDuration:20
                                             error:&subError];
    
    
    [self.throttlingCacheService addRequestToCache:@"3"
                                     errorResponse:nil
                                      throttleType:@"luke"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"4"
                                     errorResponse:nil
                                      throttleType:@"john"
                                  throttleDuration:20
                                             error:&subError];
    
    [self.throttlingCacheService addRequestToCache:@"5"
                                     errorResponse:nil
                                      throttleType:@"thomas"
                                  throttleDuration:20
                                             error:&subError];
    
    //head->5->4->3->2->1->tail
    //head<-5<-4<-3<-2<-1<-tail
    
    NSArray *thumbprintKeys = [NSArray arrayWithObjects:@"1", @"2", @"3",@"4",@"5", nil];
    NSArray *thumbprintVals = [NSArray arrayWithObjects:@"matthew", @"mark", @"luke", @"john", @"thomas", nil];
    
    
    //getResponseFromCache uses dispatch_sync. using dispatch_async will lead to thread starvation & race condition well before loop reaches the end.
    for (int i = 0; i < 1000; i++)
    {
        MSIDThrottlingCacheRecord *record = [self.throttlingCacheService getResponseFromCache:thumbprintKeys[i % 5]
                                                                                        error:&subError];
        XCTAssertNil(subError);
        XCTAssertEqualObjects(record.throttleType,thumbprintVals[i % 5]);
        
    }
    
    
}

- (void)testThrottlingCacheService_whenMultipleOperationsPerformed_cacheShouldReturnExpectedResultsReliably
{
    
    __block NSError *subError = nil;

    
    NSArray *thumbprintVals = [NSArray arrayWithObjects:@"matthew", @"mark", @"luke", @"john", @"thomas", nil];

    for (int i = 0; i < 500; i++)
    {
        NSString *thumbprintKey = [NSString stringWithFormat:@"%i", i];
        NSString *tailKey = [NSString stringWithFormat:@"%i", (i >= 4) ? i-4 : 0];
        [self.throttlingCacheService addRequestToCache:thumbprintKey
                                         errorResponse:nil
                                          throttleType:thumbprintVals[i % 5]
                                      throttleDuration:100
                                                 error:&subError];
        
        MSIDThrottlingCacheRecord *record = [self.throttlingCacheService getResponseFromCache:thumbprintKey
                                                                                        error:&subError];
        
        XCTAssertNil(subError);
        XCTAssertEqualObjects(record.throttleType, thumbprintVals[i % 5]);
        XCTAssertEqualObjects([[self.throttlingCacheService getHeadNode] requestThumbprintKey],thumbprintKey);
        XCTAssertEqualObjects([[self.throttlingCacheService getTailNode] requestThumbprintKey],tailKey);
        
    }

    for (int i = 0; i < 500; i++)
    {
        NSString *thumbprintKey = [NSString stringWithFormat:@"%i", i];
        [self.throttlingCacheService removeRequestFromCache:thumbprintKey
                                                      error:&subError];
        
        if (i < 495)
        {
            XCTAssertNotNil(subError);
        }
        
        else
        {
            XCTAssertNil(subError);
        }

    }

    
}

@end
