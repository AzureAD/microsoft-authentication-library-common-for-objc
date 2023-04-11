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
#import "MSIDAuthority.h"
#import "MSIDCIAMAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"

@interface MSIDCIAMAuthorityTests : XCTestCase

@end

@implementation MSIDCIAMAuthorityTests

#pragma mark - init

- (void)testInitCIAMAuthority_whenUrlSchemeIsNotHttps_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"http://tenant.ciamlogin.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must use HTTPS.", error.userInfo[MSIDErrorDescriptionKey]);
}

@end
