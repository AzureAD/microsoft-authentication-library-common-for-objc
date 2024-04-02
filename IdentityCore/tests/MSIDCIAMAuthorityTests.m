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
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"http://msidlab1.ciamlogin.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must use HTTPS.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitCustomCIAMAuthority_whenUrlSchemeIsNotHttps_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"http://tenantname.ciamextensibility.com/tenantID"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl validateFormat:NO context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must use HTTPS.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitCIAMAuthority_withValidUrl_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCustomCIAMAuthority_withValidUrl_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://tenantname.ciamextensibility.com/tenantID"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl validateFormat:NO context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_withValidUrlAndSlash_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCustomCIAMAuthority_withValidUrlAndSlash_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://tenantname.ciamextensibility.com/tenantID/"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl validateFormat:NO context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_withValidUrlAndTenant_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_withValidUrlAndGUID_shouldReturnNilError
{
    //Instead of GUID, there may also be the following URLS:
    //https://tenant.ciamlogin.com/tenantId
    //https://tenant.ciamlogin.com/domainName
    
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/GUID"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenCIAMAuthorityInvalid_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://ciamlogin.com/"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Non-custom CIAM authority should have at least 3 segments in the path (i.e. https://<tenant>.ciamlogin.com...)", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitCIAMAuthority_withValidUrlNonCIAMAuthority_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/tfp/tenant"];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"It is not CIAM authority.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitCIAMAuthority_whenCIAMAuthorityValidNoSlash_shouldReturnNormalizedAuthority
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenCIAMAuthorityValidAndSlash_shouldReturnNormalizedAuthority
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com/" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenCIAMAuthorityValidAlreadyNormalized_shouldReturnNoExtraNormalization
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenCIAMAuthorityValidWithGUID_shouldReturnNoExtraNormalization
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com/GUID" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://msidlab1.ciamlogin.com/GUID" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenValidUrl_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"msidlab1.ciamlogin.com");
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_whenValidUrlAndTenant_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"msidlab1.ciamlogin.com");
    XCTAssertNil(error);
}

- (void)testInitCIAMAuthority_andRawTenant_shouldReplaceTenantId
{
    __auto_type authorityUrl = [@"https://msidlab1.ciamlogin.com" msidUrl];
    NSError *error = nil;

    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl validateFormat:YES rawTenant:@"new_tenantId" context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://msidlab1.ciamlogin.com/new_tenantId" msidUrl]);
    XCTAssertNil(error);
}

#pragma mark - universalAuthorityURL

- (void)testUniversalAuthorityURL_whenCIAMAuthority_shouldReturnOriginalNormalizedAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com"];
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - cacheUrlWithContext

- (void)testCacheUrlWithContext_whenCIAMAuthority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com"];
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - networkUrlWithContext

- (void)testNetworkUrlWithContext_whenCIAMAuthority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com"];
    
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority networkUrlWithContext:nil]);
}

#pragma mark - legacyAccessTokenLookupAuthorities

- (void)testLegacyAccessTokenLookupAuthorities_whenCIAMAuthority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.ciamlogin.com/msidlab1.onmicrosoft.com"];
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    __auto_type aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqualObjects(@[authorityUrl], aliases);
}

#pragma mark - legacyRefreshTokenLookupAliases

- (void)testLegacyRefreshTokenLookupAliases_shouldReturnOriginalAuthority
{
    __auto_type authority = [@"https://msidlab1.ciamlogin.com" ciamAuthority];
    NSArray *expectedAliases = @[authority.url];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - isKnownHost

- (void)testIsKnownHost_whenCIAMAuthorityAndHostIsNotInListOfKnownHost_shouldReturnNo
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://msidlab1.something.com"];
    __auto_type authority = [[MSIDCIAMAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
}

#pragma mark - isEqual

- (void)testisEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *lhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    lhs.metadata = metadata;
    
    __auto_type *rhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    rhs.metadata = metadata;
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenOpenIdConfigurationEndpointsAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    
    __auto_type *rhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com/qwe" msidUrl];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenMetadataAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    lhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *rhs = (MSIDCIAMAuthority *)[@"https://msidlab1.ciamlogin.com" ciamAuthority];
    rhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

@end
