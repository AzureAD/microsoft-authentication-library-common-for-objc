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
#import "MSIDThrottlingCacheRecord.h"
#import "MSIDLRUCache.h"

@interface MSIDLRUCacheTest : XCTestCase

@property (nonatomic) MSIDLRUCache *lruCache;

@end

@implementation MSIDLRUCacheTest

- (void)setUp {
    self.lruCache = [MSIDLRUCache sharedInstance];
}

- (void)tearDown
{
    [self.lruCache removeAllObjects:nil];
}


- (void)testMSIDLRUCache_mostRecentlyQueriedElementShouldAppearAtTheFront
{
    NSError *subError = nil;
    for (int i = 0; i < 10; i++)
    {
        NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
        MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                     throttleType:cacheKey
                                                                                                 throttleDuration:100];
        [self.lruCache setObject:throttleCacheRecord
                          forKey:cacheKey
                            error:&subError];
        
    }
    
    for (int i = 9; i >= 5; i--)
    {
        NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
        [self.lruCache objectForKey:cacheKey
                              error:&subError];
        
    }

    //HEAD->3->5->4->2->1->TAIL;
    //HEAD<-3<-5<-4<-2<-1<-TAIL;
    NSArray<MSIDThrottlingCacheRecord *> *cachedElements = [self.lruCache enumerateAndReturnAllObjects];
    
    XCTAssertNil(subError);
    XCTAssertEqualObjects(cachedElements[0].throttleType,@"5");
    XCTAssertEqualObjects(cachedElements[1].throttleType,@"6");
    XCTAssertEqualObjects(cachedElements[2].throttleType,@"7");
    XCTAssertEqualObjects(cachedElements[3].throttleType,@"8");
    XCTAssertEqualObjects(cachedElements[4].throttleType,@"9");

}

- (void)testMSIDLRUCache_whenRemovingElementFromCache_cacheOrderShouldBeUpdatedAsExpected
{
    __block NSError *subError = nil;
    for (int i = 0; i < 10; i++)
    {
        NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
 
        MSIDThrottlingCacheRecord  *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                      throttleType:cacheKey
                                                                                                  throttleDuration:100];
        [self.lruCache setObject:throttleCacheRecord
                          forKey:cacheKey
                            error:&subError];
        
        
    }
    
    for (int i = 0; i < 10; i++)
    {
        if (i % 2)
        {
            NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
            [self.lruCache removeObjectForKey:cacheKey error:&subError];
        }
    }

    
    NSArray<MSIDThrottlingCacheRecord *> *cachedElements = [self.lruCache enumerateAndReturnAllObjects];
    
    XCTAssertNil(subError);
    XCTAssertEqualObjects(cachedElements[0].throttleType,@"8");
    XCTAssertEqualObjects(cachedElements[1].throttleType,@"6");
    XCTAssertEqualObjects(cachedElements[2].throttleType,@"4");
    XCTAssertEqualObjects(cachedElements[3].throttleType,@"2");
    XCTAssertEqualObjects(cachedElements[4].throttleType,@"0");
}

- (void)testMSIDLRUCache_whenCapacityExceeded_leastRecentlyUsedEntriesShouldBePurged
{
    __block NSError *subError = nil;
    for (int i = 0; i < 1500; i++)
    {
        NSString *cacheKey = [NSString stringWithFormat:@"%i", i];

        MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                     throttleType:cacheKey
                                                                                                     throttleDuration:100];
        [self.lruCache setObject:throttleCacheRecord
                          forKey:cacheKey
                            error:&subError];
        
        
    }
    

    //500-1499
    XCTAssertNil(subError);
    NSArray<MSIDThrottlingCacheRecord *> *cachedElements = [self.lruCache enumerateAndReturnAllObjects];
    
    for (int i = 0; i < 1000; i++)
    {
        NSString *expectedCacheKey = [NSString stringWithFormat:@"%i", 1499-i];
        XCTAssertEqualObjects(cachedElements[i].throttleType,expectedCacheKey);
    }
    
    XCTAssertEqual(self.lruCache.cacheEvictionCount,500);
    
}


- (void)testMSIDLRUCache_whenMultipleOperationsPerformed_cacheShouldReturnExpectedResultsReliably
{
    
    __block NSError *subError = nil;

    for (int i = 0; i < 500; i++)
    {
        NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
        MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                     throttleType:cacheKey
                                                                                                 throttleDuration:100];
        
        [self.lruCache setObject:throttleCacheRecord
                          forKey:cacheKey
                            error:&subError];
        
        XCTAssertNil(subError);
    }

    for (int i = 0; i < 100; i++)
    {
        [self.lruCache removeObjectForKey:[NSString stringWithFormat:@"%i", 499-i]
                                    error:&subError];
        
        [self.lruCache objectForKey:[NSString stringWithFormat:@"%i", 200+i]
                              error:&subError];
        
        [self.lruCache removeObjectForKey:[NSString stringWithFormat:@"%i", i]
                                    error:&subError];
        
    }
    
    XCTAssertEqual(self.lruCache.numCacheRecords,300); //100-399
    XCTAssertEqual(self.lruCache.cacheUpdateCount,100);
    
    NSArray<MSIDThrottlingCacheRecord *> *cachedElements = [self.lruCache enumerateAndReturnAllObjects];
    
    for (int i = 0; i < 100; i++)
    {
        NSString *currentKey;
        if (i < 100)
        {
            currentKey = [NSString stringWithFormat:@"%i", (299-i)];
        }
        
        else
        {
            currentKey = [NSString stringWithFormat:@"%i", (499-i)];
        }
        XCTAssertEqualObjects(cachedElements[i].throttleType, currentKey);
    }
    
}


- (void)testMSIDLRUCache_whenCallingAPIsUseThrottlingCacheWithinGCDBlocks_throttlingCacheShouldPerformOperationsWithThreadSafety
{
  
    dispatch_queue_t parentQ1 = dispatch_queue_create([@"parentQ1" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t parentQ2 = dispatch_queue_create([@"parentQ2" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);

    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"Calling API1"];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"Calling API2"];
    XCTestExpectation *expectation3 = [[XCTestExpectation alloc] initWithDescription:@"Calling API3"];
    XCTestExpectation *expectation4 = [[XCTestExpectation alloc] initWithDescription:@"Calling API4"];

    NSArray<XCTestExpectation *> *expectationsAdd = @[expectation1, expectation2];
    NSArray<XCTestExpectation *> *expectationsRemove = @[expectation3, expectation4];

    MSIDLRUCache *customLRUCache = [[MSIDLRUCache alloc] initWithCacheSize:100];
    __block NSError *subError = nil;

    
   // __block MSIDThrottlingCacheRecord *throttleCacheRecord;

    dispatch_async(parentQ1, ^{
        for (int i = 0; i < 50; i++)
        {
            NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
            MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                         throttleType:cacheKey
                                                                                                     throttleDuration:100];
            
            [customLRUCache setObject:throttleCacheRecord
                               forKey:cacheKey
                                error:&subError];
        }
        [expectation1 fulfill];
    });
        


    dispatch_async(parentQ2, ^{
        for (int i = 50; i < 100; i++)
        {
            NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
            MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                         throttleType:cacheKey
                                                                                                     throttleDuration:100];
            
            [customLRUCache setObject:throttleCacheRecord
                               forKey:cacheKey
                                error:&subError];
        }
        [expectation2 fulfill];
    });
    

    [self waitForExpectations:expectationsAdd timeout:20];
    XCTAssertEqual(customLRUCache.numCacheRecords,100);


    dispatch_async(parentQ1, ^{
        for (int i = 0; i < 50; i++)
        {
            NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
            NSString *cacheKeyFromOtherQueue = [NSString stringWithFormat:@"%i", (i + 50)];
            if (i % 2)
            {

                [customLRUCache removeObjectForKey:cacheKey
                                             error:&subError];
                XCTAssertNil(subError);

                MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                             throttleType:cacheKeyFromOtherQueue
                                                                                                         throttleDuration:100];

                [customLRUCache setObject:throttleCacheRecord
                                   forKey:cacheKey
                                    error:&subError];
            
                XCTAssertNil(subError);
            }
        }
        [expectation3 fulfill];
    });

    dispatch_async(parentQ2, ^{
        for (int i = 50; i < 100; i++)
        {
            NSString *cacheKey = [NSString stringWithFormat:@"%i", i];
            NSString *cacheKeyFromOtherQueue = [NSString stringWithFormat:@"%i", (i - 50)];
            if (i % 2)
            {
                [customLRUCache removeObjectForKey:cacheKey
                                             error:&subError];
                XCTAssertNil(subError);
                MSIDThrottlingCacheRecord *throttleCacheRecord = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:nil
                                                                                                             throttleType:cacheKeyFromOtherQueue
                                                                                                         throttleDuration:100];

                [customLRUCache setObject:throttleCacheRecord
                                   forKey:cacheKey
                                    error:&subError];
                XCTAssertNil(subError);
            }
        }

        [expectation4 fulfill];
    });

    [expectation4 fulfill];
    [self waitForExpectations:expectationsRemove timeout:20];
    

    XCTAssertEqual(customLRUCache.numCacheRecords,100-customLRUCache.cacheUpdateCount);
}

@end
