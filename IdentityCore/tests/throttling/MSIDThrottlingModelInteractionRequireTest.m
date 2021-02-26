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
#import "MSIDThrottlingModelInteractionRequire.h"
#import "NSDate+MSIDExtensions.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDTestSwizzle.h"
#import "MSIDThrottlingMetaDataCache.h"

@interface MSIDThrottlingModelInteractionRequireTest : XCTestCase

@end

@implementation MSIDThrottlingModelInteractionRequireTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (NSError *)createErrorWithDomain:(BOOL)isMSIDError
                         errorCode:(NSInteger)errCode
                  OAuthErrorString:(NSString *)oauthErrorString
{
    return MSIDCreateError(isMSIDError ? MSIDErrorDomain : @"ErrorDomain", errCode, @"error test", oauthErrorString, @"subError", nil, nil, nil, NO);
}

- (void)test_IfTheErrorIsUIRequiredType_ThenIsApplicableForThrottleShouldBeYes
{
    //MSID error type
    //error is OAuth2 error
    NSError *error = [self createErrorWithDomain:YES errorCode:MSIDErrorInternal OAuthErrorString:@"oauth2_error"];
    XCTAssertTrue([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);
    
    // error code is MSIDErrorInteractionRequired
    error = [self createErrorWithDomain:YES errorCode:MSIDErrorInteractionRequired OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);
    
    //MSAL error type
    // error code is -50002
    error = [self createErrorWithDomain:NO errorCode:-50002 OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);
}

- (void)test_IfTheErrorIsNotUIRequired_ThenIsApplicableForThrottleShouldBeNo
{
    NSError *error = [self createErrorWithDomain:YES errorCode:MSIDErrorInternal OAuthErrorString:nil];
    XCTAssertFalse([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);
    
    error = [self createErrorWithDomain:NO errorCode:MSIDErrorInternal OAuthErrorString:nil];
    XCTAssertFalse([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);
    
    error = [self createErrorWithDomain:NO errorCode:MSIDErrorInternal OAuthErrorString:@"oauth2_error"];
    XCTAssertFalse([MSIDThrottlingModelInteractionRequire isApplicableForTheThrottleModel:error]);

}

- (void)test_IfTheCacheIsNotExpired_AndNoLastRefreshTime_ThenshouldThrottleRequestShouldBeYes
{
    MSIDThrottlingModelInteractionRequire *model = [MSIDThrottlingModelInteractionRequire new];
    [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelInteractionRequire class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        return nil;
    }];

    XCTAssertTrue([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsNotExpired_AndLastRefreshTimeIsTooOld_ThenshouldThrottleRequestShouldBeYes
{
    MSIDThrottlingModelInteractionRequire *model = [MSIDThrottlingModelInteractionRequire new];
    [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelInteractionRequire class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = [NSDate dateWithTimeIntervalSinceNow:-3];
        return lastRefreshTime;
    }];

    XCTAssertTrue([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsExpired_ThenShouldThrottleRequestShouldBeNo
{
    MSIDThrottlingModelInteractionRequire *model = [MSIDThrottlingModelInteractionRequire new];
    [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelInteractionRequire class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:-3];
        return record;
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = nil;
        return lastRefreshTime;
    }];
    
    XCTAssertFalse([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsNotExpired_AndLastRefreshTimeIsNew_ThenshouldThrottleRequestShouldBeNo
{
    MSIDThrottlingModelInteractionRequire *model = [MSIDThrottlingModelInteractionRequire new];
    [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelInteractionRequire class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = [NSDate dateWithTimeIntervalSinceNow:3];
        return lastRefreshTime;
    }];
    
    XCTAssertFalse([model shouldThrottleRequest]);
}

@end
