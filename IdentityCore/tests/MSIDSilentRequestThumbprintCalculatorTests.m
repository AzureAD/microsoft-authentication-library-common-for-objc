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


@interface MSIDSilentRequestThumbprintCalculator (Test)

- (NSArray *)sortRequestParametersUsingFilteredSet:(NSSet *)filteringSet
                                   comparePolarity:(BOOL)comparePolarity;

- (NSString *)getRequestThumbprintImpl:(NSSet *)filteringSet
                       comparePolarity:(BOOL)comparePolarity;

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


@end
