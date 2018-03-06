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
#import "MSIDAADV1TokenResponse.h"

@interface MSIDAADV1TokenResponseTests : XCTestCase

@end

@implementation MSIDAADV1TokenResponseTests

- (void)testIsMultiResource_whenResourceAndRTPresent_shouldReturnYes
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                @"resource": @"resource"
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertTrue(result);
}

- (void)testIsMultiResource_whenResourceMissingAndRTPresent_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"refresh_token": @"rt",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

- (void)testIsMultiResource_whenResourcePresentAndRTMissing_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                @"resource": @"resource",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

- (void)testIsMultiResource_whenResourceMissingAndRTMissing_shouldReturnNO
{
    NSDictionary *jsonInput = @{@"access_token": @"at",
                                @"token_type": @"Bearer",
                                @"expires_in": @"xyz",
                                @"expires_on": @"xyz",
                                };
    
    NSError *error = nil;
    MSIDAADV1TokenResponse *response = [[MSIDAADV1TokenResponse alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    BOOL result = [response isMultiResource];
    XCTAssertFalse(result);
}

@end
