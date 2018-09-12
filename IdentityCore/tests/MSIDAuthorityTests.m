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
#import "NSString+MSIDTestUtil.h"

@interface MSIDAuthorityTests : XCTestCase

@end

@implementation MSIDAuthorityTests

#pragma mark - isADFSInstance

- (void)testIsADFSInstance_withNilEndpoint_shouldReturnNO
{
    NSURL *authority = nil;
    
    BOOL result = [MSIDAuthority isADFSInstance:authority.absoluteString];
    
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
    NSURL *authority = nil;
    
    BOOL result = [MSIDAuthority isADFSInstanceURL:authority];
    
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
    NSURL *authority = nil;
    
    BOOL result = [MSIDAuthority isConsumerInstanceURL:authority];
    
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

#pragma mark - isKnownHost

- (void)testIsKnownHost_whenHostInListOfKnownHost_shouldReturnYes
{
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.microsoftonline.com" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.microsoftonline.us" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.chinacloudapi.cn" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.microsoftonline.de" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.microsoftonline.com" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login-us.microsoftonline.com" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.usgovcloudapi.net" msidUrl]]);
    XCTAssertTrue([MSIDAuthority isKnownHost:[@"https://login.partner.microsoftonline.cn" msidUrl]]);
}

- (void)testIsKnownHost_whenHostIsNotInListOfKnownHost_shouldReturnNo
{
    XCTAssertFalse([MSIDAuthority isKnownHost:[@"https://some.net" msidUrl]]);
    XCTAssertFalse([MSIDAuthority isKnownHost:[@"https://example.com" msidUrl]]);
}

#pragma mark - normalizeAuthority

- (void)testNormalizeAuthority_whenAuthorityIsNil_shouldReturnError
{
    NSError *error;
    NSURL *authority = nil;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertNil(updatedAuthority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"'authority' is a required parameter and must not be nil or empty.");
}

- (void)testNormalizeAuthority_whenAuthorityIsWindows_shouldReturnNormalizedAuthority
{
    __auto_type authority = [@"https://login.windows.net/common/qwe" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(updatedAuthority, [@"https://login.windows.net/common" msidUrl]);
    XCTAssertNil(error);
}

- (void)testNormalizeAuthority_whenAuthoritySchemeIsNotHttps_shouldReturnError
{
    __auto_type authority = [@"http://login.microsoftonline.com" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertNil(updatedAuthority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"authority must use HTTPS.");
}

- (void)testNormalizeAuthority_whenAADAuthorityWithoutTenant_shouldReturnError
{
    __auto_type authority = [@"https://login.microsoftonline.com" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertNil(updatedAuthority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"authority must have at least 2 path components.");
}

- (void)testNormalizeAuthority_whenAADAuthorityWithTenant_shouldReturnNormalizedAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(updatedAuthority, [@"https://login.microsoftonline.com/common" msidUrl]);
    XCTAssertNil(error);
}

- (void)testNormalizeAuthority_whenAADAuthorityWithTenantAndSlash_shouldReturnNormalizedAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/common/" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(updatedAuthority, [@"https://login.microsoftonline.com/common" msidUrl]);
    XCTAssertNil(error);
}

- (void)testNormalizeAuthority_whenB2CAuthorityInvalid_shouldReturnError
{
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/tenant" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertNil(updatedAuthority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"B2C authority should have at least 3 segments in the path (i.e. https://<host>/tfp/<tenant>/<policy>/...)");
}

- (void)testNormalizeAuthority_whenB2CAuthorityValid_shouldReturnNormalizedAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/tenant/policy/qwe" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(updatedAuthority, [@"https://login.microsoftonline.com/tfp/tenant/policy" msidUrl]);
    XCTAssertNil(error);
}

- (void)testNormalizeAuthority_whenB2CAuthorityValidAndSlash_shouldReturnNormalizedAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/tenant/policy/" msidUrl];
    NSError *error;
    
    __auto_type updatedAuthority = [MSIDAuthority normalizeAuthority:authority context:nil error:&error];
    
    XCTAssertEqualObjects(updatedAuthority, [@"https://login.microsoftonline.com/tfp/tenant/policy" msidUrl]);
    XCTAssertNil(error);
}

@end
