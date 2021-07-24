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
#import "MSIDThrottlingModelNonRecoverableServerError.h"
#import "NSDate+MSIDExtensions.h"
#import "NSError+MSIDExtensions.h"
#import "MSIDTestSwizzle.h"
#import "MSIDThrottlingMetaDataCache.h"

@interface MSIDThrottlingModelNonRecoverableServerErrorTest : XCTestCase

@end

@implementation MSIDThrottlingModelNonRecoverableServerErrorTest

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
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    // error code is MSIDErrorInteractionRequired
    error = [self createErrorWithDomain:YES errorCode:MSIDErrorInteractionRequired OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    //MSAL error type
    // error code is -50002
    error = [self createErrorWithDomain:NO errorCode:-50002 OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
}

- (void)test_IfTheErrorIsNotUIRequired_ThenIsApplicableForThrottleShouldBeNo
{
    NSError *error = [self createErrorWithDomain:YES errorCode:MSIDErrorInternal OAuthErrorString:nil];
    XCTAssertFalse([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    error = [self createErrorWithDomain:NO errorCode:MSIDErrorInternal OAuthErrorString:nil];
    XCTAssertFalse([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    error = [self createErrorWithDomain:NO errorCode:MSIDErrorInternal OAuthErrorString:@"oauth2_error"];
    XCTAssertFalse([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);

}

- (void)test_IfTheErrorIsIntuneAppProtectionPoliciesRequires_ThenIsApplicableForThrottleShouldBeYes
{
    // error code is MSIDErrorServerProtectionPoliciesRequired
    NSError *error = [self createErrorWithDomain:YES errorCode:MSIDErrorServerProtectionPoliciesRequired OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    //MSAL error type
    // error code is -50004 (MSALErrorServerProtectionPoliciesRequired)
    error = [self createErrorWithDomain:NO errorCode:-50004 OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
}

- (void)test_IfTheErrorIsServerDeclinedScopes_ThenIsApplicableForThrottleShouldBeYes
{
    // error code is MSIDErrorServerDeclinedScopes
    NSError *error = [self createErrorWithDomain:YES errorCode:MSIDErrorServerDeclinedScopes OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
    
    //MSAL error type
    // error code is -50003 (MSALErrorServerDeclinedScopes)
    error = [self createErrorWithDomain:NO errorCode:-50003 OAuthErrorString:nil];
    XCTAssertTrue([MSIDThrottlingModelNonRecoverableServerError isApplicableForTheThrottleModel:error]);
}

- (void)test_IfTheCacheIsNotExpired_AndNoLastRefreshTime_ThenshouldThrottleRequestShouldBeYes
{
    MSIDThrottlingModelNonRecoverableServerError *model = [MSIDThrottlingModelNonRecoverableServerError new];
    MSIDTestSwizzle *swizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelNonRecoverableServerError class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:swizzle];

    MSIDTestSwizzle *metadataSwizzle = [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                                                              class:[MSIDThrottlingMetaDataCache class]
                                                              block:(id)^(void)
     {
        return nil;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:metadataSwizzle];

    XCTAssertTrue([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsNotExpired_AndLastRefreshTimeIsTooOld_ThenshouldThrottleRequestShouldBeYes
{
    MSIDThrottlingModelNonRecoverableServerError *model = [MSIDThrottlingModelNonRecoverableServerError new];
    MSIDTestSwizzle *cacheSwizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelNonRecoverableServerError class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:cacheSwizzle];
    
    MSIDTestSwizzle *lastrefreshSwizzle = [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = [NSDate dateWithTimeIntervalSinceNow:-3];
        return lastRefreshTime;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:lastrefreshSwizzle];

    XCTAssertTrue([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsExpired_ThenShouldThrottleRequestShouldBeNo
{
    MSIDThrottlingModelNonRecoverableServerError *model = [MSIDThrottlingModelNonRecoverableServerError new];
    MSIDTestSwizzle *cacheSwizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelNonRecoverableServerError class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:-3];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:cacheSwizzle];

    MSIDTestSwizzle *lastrefreshSwizzle = [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = nil;
        return lastRefreshTime;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:lastrefreshSwizzle];

    XCTAssertFalse([model shouldThrottleRequest]);
}

- (void)test_IfTheCacheIsNotExpired_AndLastRefreshTimeIsNew_ThenshouldThrottleRequestShouldBeNo
{
    MSIDThrottlingModelNonRecoverableServerError *model = [MSIDThrottlingModelNonRecoverableServerError new];
    MSIDTestSwizzle *cacheSwizzle = [MSIDTestSwizzle instanceMethod:@selector(cacheRecord)
                              class:[MSIDThrottlingModelNonRecoverableServerError class]
                              block:(id)^(void)
     {
        
        MSIDThrottlingCacheRecord *record = [[MSIDThrottlingCacheRecord alloc] initWithErrorResponse:[NSError new]
                                                                                        throttleType:MSIDThrottlingType429
                                                                                    throttleDuration:3];
        return record;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:cacheSwizzle];

    MSIDTestSwizzle *lastrefreshSwizzle = [MSIDTestSwizzle classMethod:@selector(getLastRefreshTimeWithDatasource:context:error:)
                           class:[MSIDThrottlingMetaDataCache class]
                           block:(id)^(void)
     {
        
        NSDate *lastRefreshTime = [NSDate dateWithTimeIntervalSinceNow:3];
        return lastRefreshTime;
    }];
    [[self.swizzleStacks objectForKey:self.name] addObject:lastrefreshSwizzle];

    XCTAssertFalse([model shouldThrottleRequest]);
}

@end
