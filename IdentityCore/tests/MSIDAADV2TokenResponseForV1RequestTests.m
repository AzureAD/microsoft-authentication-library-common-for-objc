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
#import "MSIDAADV2TokenResponseForV1Request.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAADV1IdTokenClaims.h"

@interface MSIDAADV2TokenResponseForV1RequestTests : XCTestCase

@end

@implementation MSIDAADV2TokenResponseForV1RequestTests

- (void)testInitWithJson_whenRawIdTokenIsPresent_shouldCreateIdTokenClaims
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:@"test" upn:@"upn" oid:nil tenantId:@"tenant"];
    
    NSDictionary *jsonInput = @{@"access_token": @"at",
    @"token_type": @"Bearer",
    @"expires_in": @"3600",
    @"id_token": idToken,
    @"refresh_token": @"rt"};
    
    NSError *error = nil;
    __auto_type response = [[MSIDAADV2TokenResponseForV1Request alloc] initWithJSONDictionary:jsonInput error:&error];
    
    XCTAssertNotNil(response.idTokenObj);
    XCTAssertNil(error);
    XCTAssertEqualObjects(response.idTokenObj.class , MSIDAADV1IdTokenClaims.class);
}

@end
