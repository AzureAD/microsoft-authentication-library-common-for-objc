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
#import "MSIDB2CAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDB2CAuthority.h"

@interface MSIDB2CAuthorityTests : XCTestCase

@end

@implementation MSIDB2CAuthorityTests

#pragma mark - init

- (void)testInitB2CAuthority_whenUrlSchemeIsNotHttps_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"http://login.microsoftonline.com/tfp/tenant/policy"];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must use HTTPS.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitB2CAuthority_withValidUrl_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/tfp/tenant/policy"];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitB2CAuthority_whenB2CAuthorityInvalid_shouldReturnError
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/tfp/tenant" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"B2C authority should have at least 3 segments in the path (i.e. https://<host>/tfp/<tenant>/<policy>/...)");
}

- (void)testInitB2CAuthority_whenB2CAuthorityValid_shouldReturnNormalizedAuthority
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/tfp/tenant/policy/qwe" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com/tfp/tenant/policy" msidUrl]);
    XCTAssertNil(error);
}

- (void)testNormalizeAuthority_whenB2CAuthorityValidAndSlash_shouldReturnNormalizedAuthority
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/tfp/tenant/policy/" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com/tfp/tenant/policy" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitADFSAuthority_whenValidUrl_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/tfp/tenant/policy" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"login.microsoftonline.com");
    XCTAssertNil(error);
}

- (void)testInitADFSAuthority_whenValidUrlWithPort_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com:8080/tfp/tenant/policy" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"login.microsoftonline.com:8080");
    XCTAssertNil(error);
}

- (void)testInitB2CAuthority_andRawTenant_shouldReplaceTenantId
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com:8080/tfp/tenant/policy" msidUrl];
    NSError *error = nil;

    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl validateFormat:YES rawTenant:@"new_tenantId" context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com:8080/tfp/new_tenantId/policy" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitB2CAuthority_validateFormatOff_shouldReturnSameURLWithoutQueryAndFragments
{
    __auto_type authorityUrl = [@"scheme://www.somehost.com:8080/nontfpstring/shortpath?k=a#k=b" msidUrl];
    NSError *error = nil;
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl validateFormat:NO context:nil error:&error];
    
    XCTAssertEqualObjects(authority.url, [@"scheme://www.somehost.com:8080/nontfpstring/shortpath" msidUrl]);
    XCTAssertNil(error);
}

#pragma mark - universalAuthorityURL

- (void)testUniversalAuthorityURL_whenB2CAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/tfp/tenant/policy"];
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - cacheUrlWithContext

- (void)testCacheUrlWithContext_whenB2CAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/tfp/tenant/policy"];
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - networkUrlWithContext

- (void)testNetworkUrlWithContext_whenB2CAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/tfp/tenant/policy"];
    
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority networkUrlWithContext:nil]);
}

#pragma mark - legacyAccessTokenLookupAuthorities

- (void)testLegacyAccessTokenLookupAuthorities_whenB2CAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/tfp/tenant/policy"];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    __auto_type aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqualObjects(@[authorityUrl], aliases);
}

#pragma mark - legacyRefreshTokenLookupAliases

- (void)testLegacyRefreshTokenLookupAliases_shouldReturnOriginalAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/tenant/policy" b2cAuthority];
    NSArray *expectedAliases = @[authority.url];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - isKnownHost

- (void)testIsKnownHost_whenB2CAuhorityAndHostInListOfKnownHost_shouldReturnYes
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/tfp/tenant/policy"];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.us/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.chinacloudapi.cn/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.partner.microsoftonline.cn/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.de/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login-us.microsoftonline.com/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.usgovcloudapi.net/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
}

- (void)testIsKnownHost_whenB2CAuhorityAndHostIsNotInListOfKnownHost_shouldReturnNo
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://some.net/tfp/tenant/policy"];
    __auto_type authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://example.com/tfp/tenant/policy"];
    authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
}

#pragma mark - isEqual

- (void)testisEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *lhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    lhs.metadata = metadata;
    
    __auto_type *rhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    rhs.metadata = metadata;
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenOpenIdConfigurationEndpointsAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    
    __auto_type *rhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com/qwe" msidUrl];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenMetadataAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    lhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *rhs = (MSIDB2CAuthority *)[@"https://some.net/tfp/tenant/policy" b2cAuthority];
    rhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testCopyWithZone_whenFormatNotValidated_shouldCopy
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoft.com/nonstandard/b2c"];
    MSIDB2CAuthority *authority = [[MSIDB2CAuthority alloc] initWithURL:authorityUrl validateFormat:NO context:nil error:nil];
    
    MSIDB2CAuthority *copiedAuthority = [authority copy];
    
    XCTAssertNotNil(copiedAuthority);
    XCTAssertEqualObjects(copiedAuthority.url, authorityUrl);
    XCTAssertEqualObjects(copiedAuthority.metadata, authority.metadata);
    XCTAssertEqualObjects(copiedAuthority.openIdConfigurationEndpoint, authority.openIdConfigurationEndpoint);
}

@end
