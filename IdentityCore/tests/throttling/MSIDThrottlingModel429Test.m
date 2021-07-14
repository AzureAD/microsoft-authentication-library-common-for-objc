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
#import "MSIDThrottlingModel429.h"
#import "NSError+MSIDThrottlingExtension.h"
#import "MSIDTestSwizzle.h"

@interface MSIDThrottlingModel429Test : XCTestCase

@end

@implementation MSIDThrottlingModel429Test

- (NSMutableDictionary<NSString *, NSMutableArray<MSIDTestSwizzle *> *> *)swizzleStacks
{
    static dispatch_once_t once;
    static NSMutableDictionary<NSString *, NSMutableArray<MSIDTestSwizzle *> *> *swizzleStacks = nil;
    
    dispatch_once(&once, ^{
        swizzleStacks = [NSMutableDictionary new];
    });
    
    return swizzleStacks;
}

- (void)setUp
{
    [self.swizzleStacks setValue:[NSMutableArray new] forKey:self.name];
}

- (void)tearDown
{
    [MSIDTestSwizzle resetWithSwizzleArray:[self.swizzleStacks objectForKey:self.name]];
}

- (NSError *)createErrorWithResCode:(NSString *)rescode
                        retryHeaderValue:(NSString *)retryValue
{
    NSDictionary *userInfo = @{MSIDHTTPResponseCodeKey : rescode,
                               MSIDHTTPHeadersKey: @{
                                       @"Retry-After": retryValue
                               }
    };
    return MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"429 error test", @"oAuthError", @"subError", nil, nil, userInfo, NO);;
}

- (void)test_IfTheErrorIs429Type_ThenIsApplicableForThrottleShouldBeYes
{
    NSError *error = [self createErrorWithResCode:@"429" retryHeaderValue:@""];
    XCTAssertTrue([MSIDThrottlingModel429 isApplicableForTheThrottleModel:error]);
    
    error = [self createErrorWithResCode:@"500" retryHeaderValue:@""];
    XCTAssertTrue([MSIDThrottlingModel429 isApplicableForTheThrottleModel:error]);

    error = [self createErrorWithResCode:@"200" retryHeaderValue:@"30"];
    XCTAssertTrue([MSIDThrottlingModel429 isApplicableForTheThrottleModel:error]);

}

- (void)test_IfTheErrorIsNot429_ThenIsApplicableForThrottleShouldBeNo
{
    NSError *error = nil;
    XCTAssertFalse([MSIDThrottlingModel429 isApplicableForTheThrottleModel:error]);
    
    error =  [self createErrorWithResCode:@"200" retryHeaderValue:@""];;
    XCTAssertFalse([MSIDThrottlingModel429 isApplicableForTheThrottleModel:error]);
}


- (void)test_IfTheCacheIsNotExpired_ThenshouldThrottleRequestShouldBeYes
{
    MSIDThrottlingModel429 *model = [MSIDThrottlingModel429 new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                                                         class:[MSIDThrottlingModel429 class]
                                                         block:(id)^(void)
    {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];
    XCTAssertTrue([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsExpired_ThenshouldThrottleRequestShouldBeNo
{
    MSIDThrottlingModel429 *model = [MSIDThrottlingModel429 new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModel429 class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:-1];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];
    XCTAssertFalse([model shouldThrottleRequest]);
}

- (void)test_IfNoRetryHeader_ThenCreateDBCacheRecordWithDefaultThrottlingTime
{
    MSIDThrottlingModel429 *model = [MSIDThrottlingModel429 new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(errorResponse)
                              class:[MSIDThrottlingModel429 class]
                              block:(id)^(void)
     {
        NSError *error = [self createErrorWithResCode:@"429" retryHeaderValue:@""];
        return error;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];
    NSDate *now = [NSDate new];
    MSIDThrottlingCacheRecord *cacheRecord = [model createDBCacheRecord];
    // The is a small delta in expiration time, so the acceptable range will be < 1 second
    XCTAssertTrue(ABS([cacheRecord.expirationTime timeIntervalSinceDate:now] - MSID_THROTTLING_DEFAULT_429) < 1);
}

- (void)test_IfRetryHeaderInErrorResponse_AndValueIsGreaterThanThrottlingLimit_ThenCreateDBCacheRecordWithThrottlingLimit
{
    MSIDThrottlingModel429 *model = [MSIDThrottlingModel429 new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(errorResponse)
                              class:[MSIDThrottlingModel429 class]
                              block:(id)^(void)
     {
        NSError *error = [self createErrorWithResCode:@"429" retryHeaderValue:@"10000"];
        return error;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];
    
    NSDate *now = [NSDate new];
    MSIDThrottlingCacheRecord *cacheRecord = [model createDBCacheRecord];
    XCTAssertTrue(ABS([cacheRecord.expirationTime timeIntervalSinceDate:now] - MSID_THROTTLING_MAX_RETRY_AFTER) < 1);

}

- (void)test_IfRetryHeaderInErrorResponse_AndValueIsSmallerThanThrottlingLimit_ThenCreateDBCacheRecordWithRetryHeaderValue
{
    MSIDThrottlingModel429 *model = [MSIDThrottlingModel429 new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(errorResponse)
                              class:[MSIDThrottlingModel429 class]
                              block:(id)^(void)
     {
        NSError *error = [self createErrorWithResCode:@"429" retryHeaderValue:@"50"];
        return error;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];

    NSDate *now = [NSDate new];
    MSIDThrottlingCacheRecord *cacheRecord = [model createDBCacheRecord];
    XCTAssertTrue(ABS([cacheRecord.expirationTime timeIntervalSinceDate:now] - 50) < 1);
}

@end
