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
#import "NSURL+MSIDAADUtils.h"

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
    XCTAssertEqualObjects(@{@"bar":@""}, ((NSURL*)[NSURL URLWithString:@"https://stuff.com#bar"]).msidFragmentParameters);
    XCTAssertEqualObjects(@{@"bar":@""}, ((NSURL*)[NSURL URLWithString:@"https://stuff.com?foo=bar#bar"]).msidFragmentParameters);
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
    NSDictionary *simple = @{@"foo1":@"bar1", @"foo2":@"bars s"};
    XCTAssertEqualObjects(simple, ([[NSURL URLWithString:@"urn:ietf:wg:oauth:2.0:oob?foo1=bar1&foo2=bars%20s"] msidQueryParameters]));
}

- (void)testAdQueryParamters_whenMixedQueryFragment
{
    //Mixed query and fragment configuration:
    NSDictionary *simple = @{@"foo1":@"bar1", @"foo2":@"bar2"};
    XCTAssertEqualObjects(simple, ([[NSURL URLWithString:@"https://stuff.com?foo1=bar1&foo2=bar2#foo3=bar3"] msidQueryParameters]));
}

- (void)testMsidHostWithPortIfNecessary_whenNoPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com");
}

- (void)testMsidHostWithPortIfNecessary_whenStandardPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com:443"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com");
}

- (void)testMsidHostWithPortIfNecessary_whenNonStandardPortSpecified
{
    NSURL *url = [NSURL URLWithString:@"https://somehost.com:652"];
    XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"somehost.com:652");
}

- (void)testmsidAADTenant_whenNoTenant_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertNil(tenant);
}

- (void)testmsidAADTenant_whenNilURL_shouldReturnNil
{
    NSURL *url = nil;
    NSString *tenant = [url msidAADTenant];
    XCTAssertNil(tenant);
}

- (void)testmsidAADTenant_whenAADV1Tenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/contoso.com"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertEqualObjects(tenant, @"contoso.com");
}

- (void)testmsidAADTenant_whenAADV1Tenant_andURLWithPath_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://contoso.com/contoso.com/authorize"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertEqualObjects(tenant, @"contoso.com");
}

- (void)testmsidAADTenant_whenAADV2Tenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/organizations"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertEqualObjects(tenant, @"organizations");
}

- (void)testmsidAADTenant_whenB2CTenant_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/contoso.onmicrosoft.com/B2C_1_signup_signin/"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertEqualObjects(tenant, @"contoso.onmicrosoft.com");
}

- (void)testmsidAADTenant_whenB2CAuthority_andEmptyTenant_shouldReturnNil
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/"];
    NSString *tenant = [url msidAADTenant];
    XCTAssertNil(tenant);
}

- (void)testmsidAADTenant_whenB2CTenant_andURLWithPath_shouldReturnTenant
{
    NSURL *url = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/contoso.onmicrosoft.com/B2C_1_signup_signin/v2.0/authorize"];
    NSString *tenant = [url msidAADTenant];
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

#pragma mark - Authority with cloud instance host name

- (void)testMsidAuthorityWithCloudInstanceHostname_whenPassNil_shouldReturnOriginal
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSString *name = nil;
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:name];
    XCTAssertEqualObjects(authority, authorityWithCloudName);
}

- (void)testMsidAuthorityWithCloudInstanceHostname_whenPassInEmptyString_shouldReturnOriginal
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"  "];
    XCTAssertEqualObjects(authority, authorityWithCloudName);
}

- (void)testMsidAuthorityWithCloudInstanceHostname_whenCommon_shouldSwap
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"login.microsoftonline.de"];
    XCTAssertEqualObjects(authorityWithCloudName.absoluteString, @"https://login.microsoftonline.de/common");
}

- (void)testMsidAuthorityWithCloudInstanceHostname_whenWithTenant_shouldSwap
{
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/b960c013-d381-403c-8d4d-939edac0d9ea"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"login.microsoftonline.de"];
    XCTAssertEqualObjects(authorityWithCloudName.absoluteString, @"https://login.microsoftonline.de/b960c013-d381-403c-8d4d-939edac0d9ea");
}
                        
- (void)testMsidAuthorityWithCloudInstanceHostname_whenLoginWindowsNet_shouldSwap
{
    NSURL *authority = [NSURL URLWithString:@"https://login.windows.net/common"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"login.microsoftonline.de"];
    XCTAssertEqualObjects(authorityWithCloudName.absoluteString, @"https://login.microsoftonline.de/common");
}
                        
- (void)testMsidAuthorityWithCloudInstanceHostname_whenLoginSts_shouldSwap
{
    NSURL *authority = [NSURL URLWithString:@"https://sts.microsoft.com/common"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"login.microsoftonline.de"];
    XCTAssertEqualObjects(authorityWithCloudName.absoluteString, @"https://login.microsoftonline.de/common");
}
                        
- (void)testMsidAuthorityWithCloudInstanceHostname_whenNoHost_shouldReturnSame
{
    NSURL *authority = [NSURL URLWithString:@"https://"];
    NSURL *authorityWithCloudName = [authority msidAADAuthorityWithCloudInstanceHostname:@"login.microsoftonline.de"];
    XCTAssertEqualObjects(authorityWithCloudName.absoluteString, @"https://");
}

#pragma mark - msidURLWithQueryParameters

- (void)testMsidURLWithQueryParameters_whenNilParameters_shouldReturnURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:nil];

    XCTAssertEqualObjects(resultURL, inputURL);
}

- (void)testMsidURLWithQueryParameters_whenEmptyParameters_shouldReturnURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:@{}];

    XCTAssertEqualObjects(resultURL, inputURL);
}

- (void)testMsidURLWithQueryParameters_whenEmptyQuery_NonEmptyParameters_shouldReturnURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:@{@"key1":@"value1", @"key2": @"value2"}];

    NSURL *expectedResultURL = [NSURL URLWithString:@"https://somehost.com:652?key1=value1&key2=value2"];

    XCTAssertEqualObjects(resultURL, expectedResultURL);
}

- (void)testMsidURLWithQueryParameters_whenNonEmptyQuery_NonEmptyParameters_shouldReturnCombinedURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652?existing1=value2"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:@{@"key1":@"value1", @"key2": @"value2"}];

    NSURL *expectedResultURL = [NSURL URLWithString:@"https://somehost.com:652?existing1=value2&key1=value1&key2=value2"];

    XCTAssertEqualObjects(resultURL, expectedResultURL);
}

- (void)testMsidURLWithQueryParameters_whenEmptyQuery_ExistingParameters_shouldReturnOriginalQuery
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652?key1=value_original"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:@{@"key1":@"value1", @"key2": @"value2"}];

    NSURL *expectedResultURL = [NSURL URLWithString:@"https://somehost.com:652?key1=value_original&key2=value2"];

    XCTAssertEqualObjects(resultURL, expectedResultURL);
}

- (void)testMsidURLWithQueryParameters_whenNonEmptyQuery_NonEmptyParametersWithSpecialCharacters_shouldReturnCombinedURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://somehost.com:652?existing1=value2"];

    NSURL *resultURL = [inputURL msidURLWithQueryParameters:@{@"spec ial,":@"value1", @"key2": @"value2"}];

    NSURL *expectedResultURL = [NSURL URLWithString:@"https://somehost.com:652?existing1=value2&spec%20ial%2C=value1&key2=value2"];

    XCTAssertEqualObjects(resultURL, expectedResultURL);
}

- (void)testMsidPIINullifiedURL_whenNoQueryParameters_shouldReturnURL
{
    NSURL *inputURL = [NSURL URLWithString:@"https://login.microsoftonline.com/path/path2/path3"];
    NSURL *resultURL = [inputURL msidPIINullifiedURL];
    XCTAssertEqualObjects(inputURL, resultURL);
}

- (void)testMsidPIINullifiedURL_whenQueryParametersWithValue_shouldReturnURLWithNullifiedQueryParams
{
    NSURL *inputURL = [NSURL URLWithString:@"https://login.microsoftonline.com/path/path2/path3?query1=value1&query2=value2"];
    NSURL *expectedResultURL = [NSURL URLWithString:@"https://login.microsoftonline.com/path/path2/path3?query1=(not-null)&query2=(not-null)"];
    NSURL *resultURL = [inputURL msidPIINullifiedURL];
    XCTAssertEqualObjects(expectedResultURL, resultURL);
}

- (void)testMsidPIINullifiedURL_whenQueryParametersWithoutValue_shouldReturnURLWithNillifiedQueryParams
{
    NSURL *inputURL = [NSURL URLWithString:@"https://login.microsoftonline.com/path/path2/path3?query1=&query2="];
    NSURL *expectedResultURL = [NSURL URLWithString:@"https://login.microsoftonline.com/path/path2/path3?query1=(null)&query2=(null)"];
    NSURL *resultURL = [inputURL msidPIINullifiedURL];
    XCTAssertEqualObjects(expectedResultURL, resultURL);
}

@end
