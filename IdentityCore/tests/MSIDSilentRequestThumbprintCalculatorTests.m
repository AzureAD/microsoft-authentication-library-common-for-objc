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
#import "MSIDSilentRequestThumbprintCalculator.h"
#import "MSIDOAuth2Constants.h"

@interface MSIDSilentRequestThumbprintCalculator (Test)

- (NSArray *)sortRequestParametersUsingFilteredSet:(NSSet *)filteringSet
                                   comparePolarity:(BOOL)comparePolarity;

- (NSString *)getRequestThumbprintImpl:(NSSet *)filteringSet
                       comparePolarity:(BOOL)comparePolarity;

- (NSUInteger)hash:(NSArray *)thumbprintRequestList;

@end


@interface MSIDSilentRequestThumbprintCalculatorTests : XCTestCase

@property (nonatomic) NSString *clientId;
@property (nonatomic) NSString *scope;
@property (nonatomic) NSString *refresh_token;
@property (nonatomic) NSString *redirect_uri;
@property (nonatomic) NSString *grant_type;

@property (nonatomic) NSDictionary *requestParameters;
@property (nonatomic) NSString *endpointUrl;
@property (nonatomic) NSString *realm;
@property (nonatomic) NSString *environment;
@property (nonatomic) NSString *homeAccountId;
@property (nonatomic) MSIDSilentRequestThumbprintCalculator *silentRequestThumbprintCalculator;
@property (nonatomic) NSSet *whiteListSet;
@property (nonatomic) NSSet *blackListSet;

@end

@implementation MSIDSilentRequestThumbprintCalculatorTests

- (void)setUp {
    //request params
    self.clientId = @"27922004-5251-4030-b22d-91ecd9a37ea4";
    self.scope = @"openid profile offline_access";
    self.refresh_token = @"0.ARwAkq1F9o3jGk21ENGwmnSoygQgkidRUjBAsi2R7NmjfqQcADo.AgABAAAAAAB2UyzwtQEKR7-rWbgdcBZIAQDs_wIA9P-pC2Jew17JPTq51nYIbMNBqYUqRXoKqMeuNo-JnIaqgCULiag74RahCkNed_oy_TEIxdkb_rrCvkzifvcwVkSdJOdQkW452s9ZC8cdEwtaGviimxLF3CpI9yoTdKUV3Vy7raNooYEli1B1LcSFYkltLQvgiaU-YRZ5hpRAaCyB6s6x3mJc7-LVHDdSVu4RNc_fgp16HumZNF-ZiHxRCHGfYZL3MQNi8c-FVmV6-qh-yb0GQqEYH3qoQbiOjwPWg92npuH7AMzZyudgOBvKf07e5Nzn0393Yp9fK4W9pfGMDscvV_shos8S296w-ckcOFdVepnCJtGUIqIX3UuHXyYBkAlMEifuO_PfcmRMgwuX8suEGnm1N0rFWhOjHjOSw6koy0KV45nL5Ln3ktx2z1Hey0bHxV2wWq42bAnn2L8xgB-8UvNifRQC2045Ws0QKmV2yIw1fkz9WHukHdxVCdLiz1ZYeGbxyh_khiJfCk3iFu7j1cHChd7ajrX3XPzZoLusDTWY6sbsijafV6G7cHAndD64G1XEcUZ2M2ZmrNi7-uOA6-dkKyQ-btbE47fvTKhY1UCQ6f3Qu6IFrAEeG6zeOcWzIVMWRHVdp5PPrnzOCyqiYAxkpW6X65KqI2Wa4Cyb2hFczQxbmDm_MKpLPQBDJm4kqNpa1h1BBkgpLCh_H-jwQGBaJoatGWhdKQNUIS7G17DvMV-6EGBb1YQmlFzUEaxFRbFCrOc2e_XtfNl8fAq5pQYDNuygDy8Yw2B9Gj3F3hlZTGMJ4UXPRliuNH0lAoXNy78wjNytPaR3TAEghimZvT-B08JTjz8WWuwpoXBHzhw_noida5dlL1GL4yHv77zwXh3ntqCjJJajX-prpADK8yyq9xscq8mTtzgdIVgbeDy_5sfvgygNnnAw5x0aPj_-lDNgZ";
    self.redirect_uri = @"x-msauth-outlook-prod://com.microsoft.Office.Outlook";
    self.grant_type = @"refresh_token";
    
    self.requestParameters = @{ @"client_id" : self.clientId,
                                @"scope" : self.scope,
                                @"refresh_token": self.refresh_token,
                                @"redirect_uri": self.redirect_uri,
                                @"grant_type": self.grant_type
                                };
    
    self.endpointUrl = @"https://login.microsoftonline.com/f645ad92-e38d-4d1a-b510-d1b09a74a8ca/oauth2/v2.0/token";
    self.realm = @"f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    self.environment = @"login.microsoftonline.com";
    self.homeAccountId = @"9f4880d8-80ba-4c40-97bc-f7a23c703084.f645ad92-e38d-4d1a-b510-d1b09a74a8ca";
    self.silentRequestThumbprintCalculator = [[MSIDSilentRequestThumbprintCalculator alloc] initWithParamaters:self.requestParameters
                                                                                                   endpointUrl:self.endpointUrl
                                                                                                         realm:self.realm
                                                                                                   environment:self.environment
                                                                                                 homeAccountId:self.homeAccountId];
    self.whiteListSet = [NSSet setWithArray:@[@"realm",
                                              @"environment",
                                              @"homeAccountId",
                                              MSID_OAUTH2_SCOPE]];
    
    self.blackListSet = [NSSet setWithArray:@[MSID_OAUTH2_CLIENT_ID,
                                              MSID_OAUTH2_GRANT_TYPE]];
    
}
    // Put setup code here. This method is called before the invocation of each test method in the class.

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSilentRequestThumbprintCalculator_whenFilteredSetEmpty_outputArrayShouldBeSortedByKeyAndContainAllInputRequestParams
{
    NSArray *sortedThumbprintList = [self.silentRequestThumbprintCalculator sortRequestParametersUsingFilteredSet:[NSSet new]
                                                                                                  comparePolarity:NO];
    
    XCTAssertNotNil(sortedThumbprintList);
    XCTAssertEqual(sortedThumbprintList.count,9);
    XCTAssertEqualObjects(sortedThumbprintList[0][0],@"client_id");
    XCTAssertEqualObjects(sortedThumbprintList[1][0],@"endpointUrl");
    XCTAssertEqualObjects(sortedThumbprintList[2][0],@"environment");
    XCTAssertEqualObjects(sortedThumbprintList[3][0],@"grant_type");
    XCTAssertEqualObjects(sortedThumbprintList[4][0],@"homeAccountId");
    XCTAssertEqualObjects(sortedThumbprintList[5][0],@"realm");
    XCTAssertEqualObjects(sortedThumbprintList[6][0],@"redirect_uri");
    XCTAssertEqualObjects(sortedThumbprintList[7][0],@"refresh_token");
    XCTAssertEqualObjects(sortedThumbprintList[8][0],@"scope");

}

- (void)testSilentRequestThumbprintCalculator_whenFilteredSetContainsParamsToInclude_ShouldOnlyIncludeThoseElementsInTheFinalArray
{
    NSArray *sortedThumbprintList = [self.silentRequestThumbprintCalculator sortRequestParametersUsingFilteredSet:self.whiteListSet
                                                                                                  comparePolarity:YES];
    
    XCTAssertNotNil(sortedThumbprintList);
    XCTAssertEqual(sortedThumbprintList.count,4);
    XCTAssertEqualObjects(sortedThumbprintList[0][0],@"environment");
    XCTAssertEqualObjects(sortedThumbprintList[1][0],@"homeAccountId");
    XCTAssertEqualObjects(sortedThumbprintList[2][0],@"realm");
    XCTAssertEqualObjects(sortedThumbprintList[3][0],@"scope");
}

- (void)testSilentRequestThumbprintCalculator_whenFilteredSetContainsParamsToExclude_ShouldExcludeThoseElementsFromTheFinalArray
{
    NSArray *sortedThumbprintList = [self.silentRequestThumbprintCalculator sortRequestParametersUsingFilteredSet:self.blackListSet
                                                                                                  comparePolarity:NO];
    
    XCTAssertNotNil(sortedThumbprintList);
    XCTAssertEqual(sortedThumbprintList.count,7);
    XCTAssertEqualObjects(sortedThumbprintList[0][0],@"endpointUrl");
    XCTAssertEqualObjects(sortedThumbprintList[1][0],@"environment");
    XCTAssertEqualObjects(sortedThumbprintList[2][0],@"homeAccountId");
    XCTAssertEqualObjects(sortedThumbprintList[3][0],@"realm");
    XCTAssertEqualObjects(sortedThumbprintList[4][0],@"redirect_uri");
    XCTAssertEqualObjects(sortedThumbprintList[5][0],@"refresh_token");
    XCTAssertEqualObjects(sortedThumbprintList[6][0],@"scope");
}

- (void)testSilentRequestThumbprintCalculator_whenInvalidInputProvided_hashFunctionShouldReturnZero
{
    NSMutableArray *inputRequestArr = [NSMutableArray new];
    NSArray *dummyThumbprintObject = [NSArray arrayWithObjects:@"environment", @"login.ucla.edu", @"login.microsoftonline.com",nil];
    
    //empty input
    NSUInteger val = [self.silentRequestThumbprintCalculator hash:inputRequestArr];
    XCTAssertEqual(val,0);
    
    //input contains invalid sub-array; expect all subarrays to be size of 2 and containing NSString type objects in them
    [inputRequestArr addObject:dummyThumbprintObject];
    val = [self.silentRequestThumbprintCalculator hash:inputRequestArr];
    XCTAssertEqual(val,0);
}

- (void)testSilentRequestThumbprintCalculator_whenTheSameRequestParametersProvidedMultipleTimes_hashFunctionShouldReturnSameConsistentHash
{
    NSString *thumbprintOne = [self.silentRequestThumbprintCalculator getRequestThumbprintImpl:[NSSet new]
                                                                               comparePolarity:NO];
    NSString *thumbprintTwo = [self.silentRequestThumbprintCalculator getRequestThumbprintImpl:[NSSet new]
                                                                               comparePolarity:NO];
    NSString *thumbprintThree = [self.silentRequestThumbprintCalculator getRequestThumbprintImpl:[NSSet new]
                                                                                 comparePolarity:NO];
    NSString *thumbprintFour = [self.silentRequestThumbprintCalculator getRequestThumbprintImpl:[NSSet new]
                                                                                comparePolarity:NO];
    NSString *thumbprintFive = [self.silentRequestThumbprintCalculator getRequestThumbprintImpl:[NSSet new]
                                                                                comparePolarity:NO];
    XCTAssertNotNil(thumbprintOne);
    XCTAssertEqualObjects(thumbprintOne,thumbprintTwo);
    XCTAssertEqualObjects(thumbprintOne,thumbprintThree);
    XCTAssertEqualObjects(thumbprintOne,thumbprintFour);
    XCTAssertEqualObjects(thumbprintOne,thumbprintFive);
}


- (void)testSilentRequestThumbprintCalculator_whenFixedRequestParamSetIsUsed_thumbprintCalculatorsShouldReturnExpectedValues
{
    NSString *strictRequestThumbprint = [self.silentRequestThumbprintCalculator getStrictRequestThumbprint];
    NSString *fullRequestThumbprint = [self.silentRequestThumbprintCalculator getFullRequestThumbprint];
    XCTAssertEqualObjects(strictRequestThumbprint,@"5072015491213839942");
    XCTAssertEqualObjects(fullRequestThumbprint,@"10251421432256759120");
}

- (void)testSilentRequestThumbprintCalculator_whenMultipleRequestsAreIncoming_thumbprintCalculatorShouldProvideStableFullRequestThumbprintsWithMinimalCollision
{
    NSMutableDictionary* virtualBucket = [NSMutableDictionary new];
    __block int collisionCnt = 0;
    
    for (int i = 0; i < 10000; i++)
    {
        MSIDSilentRequestThumbprintCalculator *randomThumbprintCalculator = [self generateRandomThumbprintCalculatorInstance:YES
                                                                                                       setRandomRefreshToken:YES
                                                                                                        setRandomRedirectUrl:YES
                                                                                                        setRandomEndpointUrl:YES
                                                                                                              setRandomRealm:YES
                                                                                                        setRandomEnvironment:YES
                                                                                                      setRandomHomeAccountId:YES];
        NSString *randomThumbprintKey = [randomThumbprintCalculator getFullRequestThumbprint];
        if ([virtualBucket objectForKey:randomThumbprintKey])
        {
            int val = [virtualBucket[randomThumbprintKey] intValue];
            virtualBucket[randomThumbprintKey] = @(val + 1);
        }
        else
        {
            virtualBucket[randomThumbprintKey] = @1;
        }
    }
    
    [virtualBucket enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        if ([obj intValue] > 1)
        {
            collisionCnt++;
        }
    }];
    XCTAssertNotNil(virtualBucket);
    XCTAssertLessThanOrEqual(collisionCnt,0);
}

- (void)testSilentRequestThumbprintCalculator_whenMultipleRequestsAreIncoming_thumbprintCalculatorShouldProvideStableStrictRequestThumbprintsWithMinimalCollision
{
    NSMutableDictionary* virtualBucket = [NSMutableDictionary new];
    __block int collisionCnt = 0;
    
    for (int i = 0; i < 20000; i++)
    {
        MSIDSilentRequestThumbprintCalculator *randomThumbprintCalculator = [self generateRandomThumbprintCalculatorInstance:YES
                                                                                                       setRandomRefreshToken:NO
                                                                                                        setRandomRedirectUrl:NO
                                                                                                        setRandomEndpointUrl:NO
                                                                                                              setRandomRealm:NO
                                                                                                        setRandomEnvironment:NO
                                                                                                      setRandomHomeAccountId:YES];
        NSString *randomThumbprintKey = [randomThumbprintCalculator getStrictRequestThumbprint];
        if ([virtualBucket objectForKey:randomThumbprintKey])
        {
            int val = [virtualBucket[randomThumbprintKey] intValue];
            virtualBucket[randomThumbprintKey] = @(val + 1);
        }
        else
        {
            virtualBucket[randomThumbprintKey] = @1;
        }
    }
    
    [virtualBucket enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        if ([obj intValue] > 1)
        {
            collisionCnt++;
        }
    }];
    XCTAssertNotNil(virtualBucket);
    XCTAssertLessThanOrEqual(collisionCnt,0);
}

- (MSIDSilentRequestThumbprintCalculator *)generateRandomThumbprintCalculatorInstance:(BOOL)setRandomScope
                                                                setRandomRefreshToken:(BOOL)setRandomRT
                                                                 setRandomRedirectUrl:(BOOL)setRandomRedirectUrl
                                                                 setRandomEndpointUrl:(BOOL)setRandomEndpointUrl
                                                                       setRandomRealm:(BOOL)setRandomRealm
                                                                 setRandomEnvironment:(BOOL)setRandomEnvironment
                                                               setRandomHomeAccountId:(BOOL)setRandomHomeAccountId
{
    NSString *randomScope = (setRandomScope == YES) ? [self generateRandomStringWithLen:(int)[self.scope length]] : self.scope;
    NSString *randomRefreshToken = (setRandomRT == YES) ? [self generateRandomStringWithLen:(int)[self.refresh_token length]] : self.refresh_token;
    NSString *randomRedirectUrl = (setRandomRedirectUrl == YES) ? [self generateRandomStringWithLen:(int)[self.redirect_uri length]] : self.redirect_uri;
    
    NSDictionary *requestParams = @{ @"client_id" : self.clientId, //unused in the thumbprint calculation
                                     @"scope" : randomScope,
                                     @"refresh_token": randomRefreshToken,
                                     @"redirect_uri": randomRedirectUrl,
                                     @"grant_type": self.grant_type //unused in the thumbprint calculation
                                    };

    NSString *randomEndpointUrl = (setRandomEndpointUrl == YES) ? [self generateRandomStringWithLen:(int)[self.endpointUrl length]] : self.endpointUrl;
    NSString *randomRealm = (setRandomRealm == YES) ? [self generateRandomStringWithLen:(int)[self.realm length]] : self.realm;
    NSString *randomEnvironment = (setRandomEnvironment == YES) ? [self generateRandomStringWithLen:(int)[self.environment length]] : self.environment;
    NSString *randomHomeAccountId = (setRandomHomeAccountId) ? [self generateRandomStringWithLen:(int)[self.homeAccountId length]] : self.homeAccountId;
    MSIDSilentRequestThumbprintCalculator *silentRequestThumbprintCalculator = [[MSIDSilentRequestThumbprintCalculator alloc] initWithParamaters:requestParams
                                                                                                                                     endpointUrl:randomEndpointUrl
                                                                                                                                           realm:randomRealm
                                                                                                                                     environment:randomEnvironment
                                                                                                                                   homeAccountId:randomHomeAccountId];
    return silentRequestThumbprintCalculator;
}

- (NSString *)generateRandomStringWithLen:(int)len
{
    NSString *validLetters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-/:. ";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];

    for (int i=0; i< len; i++)
    {
        [randomString appendFormat:@"%C", [validLetters characterAtIndex:arc4random_uniform((int)[validLetters length])]];
    }

    return randomString;
}


@end
