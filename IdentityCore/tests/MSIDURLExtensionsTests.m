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

@interface NSURLExtensionsTests : XCTestCase

@end

@implementation NSURLExtensionsTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

//tests the fragment extraction. Does not test any other URL logic,
//which should have been handled by the NSURL class
- (void)testFragmentParameters
{
    //Missing or invalid fragment:
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com"]).msidFragmentParameters);
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar"]).msidFragmentParameters);
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com#bar=foo#"]).msidFragmentParameters);
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#bar=foo#foo=bar"]).msidFragmentParameters);
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#bar=foo#foo=bar#"]).msidFragmentParameters);
    XCTAssertNil(((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#        "]).msidFragmentParameters);
    
    //Valid fragment, but missing/invalid configuration:
    NSDictionary* empty = [NSDictionary new];
    XCTAssertEqualObjects(empty, ((NSURL*)[NSURL URLWithString:@"https://stuff.com#bar"]).msidFragmentParameters);
    XCTAssertEqualObjects(empty, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#bar"]).msidFragmentParameters);
    XCTAssertEqualObjects(empty, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#bar=foo=bar"]).msidFragmentParameters);
    
    //At least some of the configuration are valid:
    NSDictionary* simple = @{@"foo1":@"bar1", @"foo2":@"bar2"};
    XCTAssertEqualObjects(simple, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#foo1=bar1&foo2=bar2"]).msidFragmentParameters);
    XCTAssertEqualObjects(simple, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#foo1=bar1&foo2=bar2&foo2=bar2"]).msidFragmentParameters);
    XCTAssertEqualObjects(simple, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#foo1=bar1&foo2=bar2&&&"]).msidFragmentParameters);
    XCTAssertEqualObjects(simple, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#foo1=bar1&foo2=bar2&foo3=bar3=foo3"]).msidFragmentParameters);
}

- (void)testAdQueryParameters_whenNoQPS
{
    //Negative:
    XCTAssertNil([[NSURL URLWithString:@"https://stuff.com"] msidQueryParameters]);
}

- (void)testAdQueryParameters_whenSimpleQPs
{
    //Positive:
    NSDictionary *simple = @{@"foo1":@"bar1", @"foo2":@"bar2"};
    XCTAssertEqualObjects(simple, ([[NSURL URLWithString:@"https://stuff.com?foo1=bar1&foo2=bar2"] msidQueryParameters]));
}

- (void)testAdQueryParameters_whenURINotURL
{
    // Valid redirect url
    NSDictionary *simple = @{@"foo1":@"bar1", @"foo2":@"bar2"};
    XCTAssertEqualObjects(simple, ([[NSURL URLWithString:@"urn:ietf:wg:oauth:2.0:oob?foo1=bar1&foo2=bar2"] msidQueryParameters]));
}

- (void)testAdQueryParamters_whenMixedQueryFragment
{
    //Mixed query and fragment configuration:
    NSDictionary *simple = @{@"foo1":@"bar1", @"foo2":@"bar2"};
    XCTAssertEqualObjects(simple, ([[NSURL URLWithString:@"https://stuff.com?foo1=bar1&foo2=bar2#foo3=bar3"] msidQueryParameters]));
}

- (void)testAdQueryParameters_whenContainsPercentEncoding
{
    NSDictionary *withEncoded = @{@"foo1" : @"bar1", @"foo2" : @"bar2", @"foo3=bar3" : @"foo4&bar4=bar5"};
    XCTAssertEqualObjects(withEncoded, ([[NSURL URLWithString:@"https://contoso.com?foo1=bar1&foo2=bar2&foo3%3Dbar3=foo4%26bar4%3Dbar5"] msidQueryParameters]));
}

- (void)testmsidHostWithPortIfNecessary_whenNoPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com");
}

- (void)testmsidHostWithPortIfNecessary_whenStandardPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com:443"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com");
}

- (void)testmsidHostWithPortIfNecessary_whenNonStandardPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com:652"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com:652");
}

- (void)testMsidTenant_whenNoTenant_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSString *tenant = [url msidTenant];
    XCTAssertNil(tenant);
}

- (void)testMsidTenant_whenNilURL_shouldReturnNil
{
    NSURL *url = nil;
    NSString *tenant = [url msidTenant];
    XCTAssertNil(tenant);
}

- (void)testMsidTenant_whenAADV1Tenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/contoso.com"];
    NSString *tenant = [url msidTenant];
    XCTAssertEqualObjects(tenant, @"contoso.com");
}

- (void)testMsidTenant_whenAADV1Tenant_andURLWithPath_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/contoso.com/authorize"];
    NSString *tenant = [url msidTenant];
    XCTAssertEqualObjects(tenant, @"contoso.com");
}

- (void)testMsidTenant_whenAADV2Tenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/organizations"];
    NSString *tenant = [url msidTenant];
    XCTAssertEqualObjects(tenant, @"organizations");
}

- (void)testMsidTenant_whenB2CTenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/contoso.onmicrosoft.com/B2C_1_signup_signin/"];
    NSString *tenant = [url msidTenant];
    XCTAssertEqualObjects(tenant, @"contoso.onmicrosoft.com");
}

- (void)testMsidTenant_whenB2CAuthority_andEmptyTenant_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/"];
    NSString *tenant = [url msidTenant];
    XCTAssertNil(tenant);
}

- (void)testMsidTenant_whenB2CTenant_andURLWithPath_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/contoso.onmicrosoft.com/B2C_1_signup_signin/v2.0/authorize"];
    NSString *tenant = [url msidTenant];
    XCTAssertEqualObjects(tenant, @"contoso.onmicrosoft.com");
}

#pragma mark - Equivalent authority

- (void)testMsidIsEquivalentAuthority_whenSameAuthority_shouldReturnTrue
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    XCTAssertTrue([authority msidIsEquivalentAuthority:authority]);
}

- (void)testMsidIsEquivalentAuthority_whenEquivalentAuthority_shouldReturnTrue
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com?test=test"];
    XCTAssertTrue([authority1 msidIsEquivalentAuthority:authority2]);
}

- (void)testMsidIsEquivalentAuthority_whenEquivalentAuthorityButSchemeDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"http://login.microsoftonline.com:88/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthority:authority2]);
}

- (void)testMsidIsEquivalentAuthority_whenEquivalentAuthorityButHostDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.windows.net/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthority:authority2]);
}

- (void)testMsidIsEquivalentAuthority_whenEquivalentAuthorityButPortDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:89/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthority:authority2]);
}

- (void)testMsidIsEquivalentAuthority_whenEquivalentAuthorityButPathDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso2.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthority:authority2]);
}

#pragma mark - Equivalent authority host

- (void)testMsidIsEquivalentAuthorityHost_whenSameAuthority_shouldReturnTrue
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    XCTAssertTrue([authority msidIsEquivalentAuthorityHost:authority]);
}

- (void)testMsidIsEquivalentAuthorityHost_whenEquivalentAuthority_shouldReturnTrue
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com?test=test"];
    XCTAssertTrue([authority1 msidIsEquivalentAuthorityHost:authority2]);
}

- (void)testMsidIsEquivalentAuthorityHost_whenEquivalentAuthorityButSchemeDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"http://login.microsoftonline.com:88/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthorityHost:authority2]);
}

- (void)testMsidIsEquivalentAuthorityHost_whenEquivalentAuthorityButHostDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.windows.net/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthorityHost:authority2]);
}

- (void)testMsidIsEquivalentAuthorityHost_whenEquivalentAuthorityButPortDifferent_shouldReturnFalse
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:89/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com?test=test"];
    XCTAssertFalse([authority1 msidIsEquivalentAuthorityHost:authority2]);
}

- (void)testMsidIsEquivalentAuthorityHost_whenEquivalentAuthorityButPathDifferent_shouldReturnTrue
{
    NSURL *authority1 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso.com"];
    NSURL *authority2 = [NSURL URLWithString:@"https://login.microsoftonline.com:88/contoso2.com?test=test"];
    XCTAssertTrue([authority1 msidIsEquivalentAuthorityHost:authority2]);
}

@end
