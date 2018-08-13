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
#import "MSIDAuthority.h"

@interface MSIDAuthorityTests : XCTestCase

@end

@implementation MSIDAuthorityTests

#pragma mark - isADFSInstance

- (void)testIsADFSInstance_withNilEndpoint_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstance:nil];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstance_withEmptyEndpoint_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstance:@""];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstance_withInvalidAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstance:@"https://login.microsoftonline.com"];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstance_withValidAADAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstance:@"https://login.microsoftonline.com/contoso.com"];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstance_withADFSAuthority_shouldReturnYES
{
    BOOL result = [MSIDAuthority isADFSInstance:@"https://contoso.com/adfs"];
    
    XCTAssertTrue(result);
}

#pragma mark - isADFSInstanceURL

- (void)testIsADFSInstanceURL_withNilAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstanceURL:nil];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstanceURL_withInvalidAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstanceURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstanceURL_withValidAADAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isADFSInstanceURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"]];
    
    XCTAssertFalse(result);
}

- (void)testIsADFSInstanceURL_withADFSAuthority_shouldReturnYES
{
    BOOL result = [MSIDAuthority isADFSInstanceURL:[NSURL URLWithString:@"https://contoso.com/adfs"]];
    
    XCTAssertTrue(result);
}

#pragma mark - isConsumerInstanceURL

- (void)testIsConsumerInstanceURL_withNilAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isConsumerInstanceURL:nil];
    
    XCTAssertFalse(result);
}

- (void)testIsConsumerInstanceURL_withInvalidAuthority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isConsumerInstanceURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]];
    
    XCTAssertFalse(result);
}

- (void)testIsConsumerInstanceURL_withAADV1Authority_shouldReturnNO
{
    BOOL result = [MSIDAuthority isConsumerInstanceURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"]];
    
    XCTAssertFalse(result);
}

- (void)testIsConsumerInstanceURL_withConsumerAuthority_shouldReturnYES
{
    BOOL result = [MSIDAuthority isConsumerInstanceURL:[NSURL URLWithString:@"https://login.microsoftonline.com/consumers"]];
    
    XCTAssertTrue(result);
}

#pragma mark - universalAuthorityURL

- (void)testUniversalAuthorityURL_withNilAuthority_shouldReturnNil
{
    NSURL *result = [MSIDAuthority universalAuthorityURL:nil];
    
    XCTAssertNil(result);
}

- (void)testUniversalAuthorityURL_withInvalidAuthority_shouldReturnOriginalAuthority
{
    NSURL *input = [NSURL URLWithString:@"https://login.microsoftonline.com"];
    
    NSURL *result = [MSIDAuthority universalAuthorityURL:input];
    
    XCTAssertEqualObjects(result, input);
}

- (void)testUniversalAuthorityURL_withAADV1TenantedAuthority_shouldReturnOriginalAuthority
{
    NSURL *input = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    
    NSURL *result = [MSIDAuthority universalAuthorityURL:input];
    
    XCTAssertEqualObjects(result, input);
}

- (void)testUniversalAuthorityURL_withAADV1CommonAuthority_shouldReturnOriginalAuthority
{
    NSURL *input = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    
    NSURL *result = [MSIDAuthority universalAuthorityURL:input];
    
    XCTAssertEqualObjects(result, input);
}

- (void)testUniversalAuthorityURL_withConsumerAuthority_shouldReturnOriginalAuthority
{
    NSURL *input = [NSURL URLWithString:@"https://login.microsoftonline.com/consumers"];
    
    NSURL *result = [MSIDAuthority universalAuthorityURL:input];
    
    XCTAssertEqualObjects(result, input);
}

- (void)testUniversalAuthorityURL_withOrganizationsAuthority_shouldReturnCommonAuthority
{
    NSURL *input = [NSURL URLWithString:@"https://login.microsoftonline.com/organizations"];
    
    NSURL *result = [MSIDAuthority universalAuthorityURL:input];
    
    XCTAssertEqualObjects(result, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
}

- (void)testCacheURLAuthority_whenNilTenant_shouldReturnURL
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] tenantId:nil];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
}

- (void)testCacheURLAuthority_whenCommon_shouldReturnURL
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] tenantId:@"tenant"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/tenant"]);
}

- (void)testCacheURLAuthority_whenCommonWithPort_shouldReturnURLWithPort
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com:8080/common"] tenantId:@"tenant"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant"]);
}

- (void)testCacheURLAuthority_whenConsumersWithPort_shouldReturnURLWithPort
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com:8080/consumers"] tenantId:@"tenant"];

    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant"]);
}

- (void)testCacheURLAuthority_whenTenantSpecified_shouldReturnURL
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/tenant2"] tenantId:@"tenant1"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/tenant2"]);
}

- (void)testCacheURLAuthority_whenTenantSpecifiedWithPort_shouldReturnURLWithPort
{
    NSURL *url = [MSIDAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant2"] tenantId:@"tenant1"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant2"]);
}

- (void)testIsKnownHost_whenTrustedAuthority_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.windows.net"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityUS_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.microsoftonline.us"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityChina_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.chinacloudapi.cn"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityGermany_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.microsoftonline.de"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityWorldWide_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.microsoftonline.com"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityUSGovernment_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login-us.microsoftonline.com"]]);
}

- (void)testIsKnownHost_whenTrustedAuthorityCloudGovApi_shuldReturnTrue
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://login.cloudgovapi.us"]]);
}

- (void)testIsKnownHost_whenUnknownHost_shouldReturnFalse
{
    XCTAssertFalse([MSIDAuthority isKnownHost:[NSURL URLWithString:@"https://www.noknownhost.com"]]);
}

- (void)testIsKnownHost_whenNilHost_shouldReturnFalse
{
    XCTAssertFalse([MSIDAuthority isKnownHost:nil]);
}

@end
