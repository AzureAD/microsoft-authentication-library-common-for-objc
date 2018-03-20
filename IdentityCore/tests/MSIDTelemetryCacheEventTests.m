//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAccessToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDRefreshToken.h"

@interface MSIDTelemetryCacheEventTests : XCTestCase

@end

@implementation MSIDTelemetryCacheEventTests

- (void)testSetToken_withNilToken_shouldNotSetAnyFields
{
    MSIDTelemetryCacheEvent *cacheEvent = [[MSIDTelemetryCacheEvent alloc] initWithName:@"test" context:nil];
    [cacheEvent setToken:nil];
    
    NSDictionary *properties = [cacheEvent getProperties];
    XCTAssertEqual([[properties allKeys] count], 4);
}

- (void)testSetToken_withAccessToken_shouldSaveTokenTypeAndSPEInfo
{
    MSIDAccessToken *accessToken = [MSIDAccessToken new];
    NSDictionary *serverInfo = @{@"spe_info" : @"I"};
    [accessToken setValue:serverInfo forKey:@"additionaServerlInfo"];
    
    MSIDTelemetryCacheEvent *cacheEvent = [[MSIDTelemetryCacheEvent alloc] initWithName:@"test" context:nil];
    [cacheEvent setToken:accessToken];
    
    NSDictionary *properties = [cacheEvent getProperties];
    XCTAssertEqual([[properties allKeys] count], 6);
    XCTAssertEqualObjects(properties[@"Microsoft.Test.spe_info"], @"I");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_type"], @"access_token");
}

- (void)testSetToken_withLegacySingleResourceToken_shouldSaveTokenTypeSPEInfoAndRTStatus
{
    MSIDLegacySingleResourceToken *token = [MSIDLegacySingleResourceToken new];
    NSDictionary *serverInfo = @{@"spe_info" : @"I"};
    [token setValue:serverInfo forKey:@"additionaServerlInfo"];
    
    MSIDTelemetryCacheEvent *cacheEvent = [[MSIDTelemetryCacheEvent alloc] initWithName:@"test" context:nil];
    [cacheEvent setToken:token];
    
    NSDictionary *properties = [cacheEvent getProperties];
    XCTAssertEqual([[properties allKeys] count], 7);
    XCTAssertEqualObjects(properties[@"Microsoft.Test.spe_info"], @"I");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_type"], @"ADFS_access_token_refresh_token");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.is_rt"], @"yes");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_rt_status"], @"tried");
}

- (void)testSetToken_withMRRTToken_shouldSaveTokenTypeSPEInfoAndMRRTStatus
{
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    NSDictionary *serverInfo = @{@"spe_info" : @"I"};
    [token setValue:serverInfo forKey:@"additionaServerlInfo"];
    [token setValue:@"client" forKey:@"clientId"];
    [token setValue:@"1" forKey:@"familyId"];
    
    MSIDTelemetryCacheEvent *cacheEvent = [[MSIDTelemetryCacheEvent alloc] initWithName:@"test" context:nil];
    [cacheEvent setToken:token];
    
    NSDictionary *properties = [cacheEvent getProperties];
    XCTAssertEqual([[properties allKeys] count], 7);
    XCTAssertEqualObjects(properties[@"Microsoft.Test.spe_info"], @"I");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_type"], @"refresh_token");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.is_mrrt"], @"yes");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_mrrt_status"], @"tried");
}

- (void)testSetToken_withFRTToken_shouldSaveTokenTypeSPEInfoAndFRTStatus
{
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    NSDictionary *serverInfo = @{@"spe_info" : @"I"};
    [token setValue:serverInfo forKey:@"additionaServerlInfo"];
    [token setValue:@"foci-1" forKey:@"clientId"];
    [token setValue:@"1" forKey:@"familyId"];
    
    MSIDTelemetryCacheEvent *cacheEvent = [[MSIDTelemetryCacheEvent alloc] initWithName:@"test" context:nil];
    [cacheEvent setToken:token];
    
    NSDictionary *properties = [cacheEvent getProperties];
    XCTAssertEqual([[properties allKeys] count], 7);
    XCTAssertEqualObjects(properties[@"Microsoft.Test.spe_info"], @"I");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_type"], @"refresh_token");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.is_frt"], @"yes");
    XCTAssertEqualObjects(properties[@"Microsoft.Test.token_frt_status"], @"tried");
}

@end
