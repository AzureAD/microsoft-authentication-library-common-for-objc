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
#import "MSIDAADV2TokenResponse.h"
#import "MSIDRequestParameters.h"

@interface MSIDAADV2TokenResponseTests : XCTestCase

@end

@implementation MSIDAADV2TokenResponseTests

- (void)testTargetWithAdditionFromRequest_whenMultipleScopesInRequest_shouldNotAddDefaultScope
{
    NSString *scopeInRequest = @"user.write abc://abc/.default";
    NSString *scopeInResposne = @"user.read";
    
    // construct request parameters
    MSIDRequestParameters *reqParams = [MSIDRequestParameters new];
    [reqParams setTarget:scopeInRequest];
    
    // construct response
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"scope": scopeInResposne
                                };
    NSError *error = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);

    // scope should be the same as it is in response
    XCTAssertEqualObjects([response targetWithAdditionFromRequest:reqParams], scopeInResposne);
}

- (void)testTargetWithAdditionFromRequest_whenNoDefaultScopeInRequest_shouldNotAddDefaultScope
{
    NSString *scopeInRequest = @"user.write";
    NSString *scopeInResposne = @"user.read";
    
    // construct request parameters
    MSIDRequestParameters *reqParams = [MSIDRequestParameters new];
    [reqParams setTarget:scopeInRequest];
    
    // construct response
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"scope": scopeInResposne
                                };
    NSError *error = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    // scope should be the same as it is in response
    XCTAssertEqualObjects([response targetWithAdditionFromRequest:reqParams], scopeInResposne);
}

- (void)testTargetWithAdditionFromRequest_whenOnlyDefaultScopeInRequest_shouldAddDefaultScope
{
    NSString *scopeInRequest = @"abc://abc/.default";
    NSString *scopeInResposne = @"user.read";
    
    // construct request parameters
    MSIDRequestParameters *reqParams = [MSIDRequestParameters new];
    [reqParams setTarget:scopeInRequest];
    
    // construct response
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"scope": scopeInResposne
                                };
    NSError *error = nil;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    // both scopes in request and response should be included
    NSOrderedSet<NSString *> *scopeWithAddition = [[response targetWithAdditionFromRequest:reqParams] scopeSet];
    XCTAssertEqual(scopeWithAddition.count, 2);
    XCTAssertTrue([scopeInRequest.scopeSet isSubsetOfOrderedSet:scopeWithAddition]);
    XCTAssertTrue([scopeInResposne.scopeSet isSubsetOfOrderedSet:scopeWithAddition]);
}

@end
