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
#import "MSIDADFSAuthority.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority+Internal.h"

@interface MSIDADFSAuthorityTests : XCTestCase

@end

@implementation MSIDADFSAuthorityTests

#pragma mark - Init

- (void)testInitADFSAuthority_withNilUrl_shouldReturnError
{
    NSURL *authorityUrl = nil;
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"'authority' is a required parameter and must not be nil or empty.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitADFSAuthority_withAADUrl_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/8eaef023-2b34-4da1-9baa-8bc8c9d6a490"];
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"It is not ADFS authority.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitADFSAuthority_withValidUrl_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com/adfs"];
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
}

- (void)testInitADFSAuthority_whenUrlSchemeIsNotHttps_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"http://contoso.com/adfs"];
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must use HTTPS.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitADFSAuthority_whenValidUrl_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://contoso.com/adfs" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"contoso.com");
    XCTAssertNil(error);
}

- (void)testInitADFSAuthority_whenValidUrlWithPort_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://contoso.com:8080/adfs" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"contoso.com:8080");
    XCTAssertNil(error);
}

#pragma mark - universalAuthorityURL

- (void)testUniversalAuthorityURL_whenADFSAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com/adfs"];
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - cacheUrlWithContext

- (void)testCacheUrlWithContext_whenADFSAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/adfs"];
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

#pragma mark - networkUrlWithContext

- (void)testNetworkUrlWithContext_whenADFSAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/adfs"];
    
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority networkUrlWithContext:nil]);
}

#pragma mark - legacyAccessTokenLookupAuthorities

- (void)testLegacyAccessTokenLookupAuthorities_whenADFSAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com:8080/adfs"];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    __auto_type aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqualObjects(@[authorityUrl], aliases);
}

#pragma mark - legacyRefreshTokenLookupAliases

- (void)testLegacyRefreshTokenLookupAliases_shouldReturnOriginalAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/adfs" adfsAuthority];
    NSArray *expectedAliases = @[authority.url];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - isKnownHost

- (void)testIsKnownHost_whenADFSAuhorityAndHostInListOfKnownHost_shouldReturnYes
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/adfs"];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.us/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.chinacloudapi.cn/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.partner.microsoftonline.cn/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.de/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login-us.microsoftonline.com/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.usgovcloudapi.net/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
}

- (void)testIsKnownHost_whenADFSAuhorityAndHostIsNotInListOfKnownHost_shouldReturnNo
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://some.net/adfs"];
    __auto_type authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://example.com/adfs"];
    authority = [[MSIDADFSAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
}

#pragma mark - isEqual

- (void)testisEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *lhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    lhs.metadata = metadata;
    
    __auto_type *rhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    rhs.metadata = metadata;
    
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenOpenIdConfigurationEndpointsAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    
    __auto_type *rhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com/qwe" msidUrl];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenMetadataAreNotEqual_shouldReturnFalse
{
    __auto_type *lhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    lhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    __auto_type *rhs = (MSIDADFSAuthority *)[@"https://login.microsoftonline.com/adfs" adfsAuthority];
    rhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

@end
