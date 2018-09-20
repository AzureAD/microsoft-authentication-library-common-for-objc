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
#import "MSIDAADAuthority.h"
#import "MSIDAADTenant.h"
#import "MSIDAadAuthorityCache.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDAuthority+Internal.h"
#import "MSIDOpenIdProviderMetadata.h"

@interface MSIDAADAuthorityCacheMock : MSIDAadAuthorityCache

@property (nonatomic) NSInteger networkUrlForAuthorityInvokedCount;
@property (nonatomic) NSInteger cacheUrlForAuthorityInvokedCount;
@property (nonatomic) NSInteger cacheAliasesForAuthorityInvokedCount;
@property (nonatomic) NSInteger cacheAliasesForEnvironmentInvokedCount;

@end

@implementation MSIDAADAuthorityCacheMock

- (NSURL *)networkUrlForAuthority:(MSIDAADAuthority *)authority
                          context:(id<MSIDRequestContext>)context
{
    self.networkUrlForAuthorityInvokedCount++;
    
    return [super networkUrlForAuthority:authority context:context];
}

- (NSURL *)cacheUrlForAuthority:(MSIDAADAuthority *)authority
                        context:(id<MSIDRequestContext>)context
{
    self.cacheUrlForAuthorityInvokedCount++;
    
    return [super cacheUrlForAuthority:authority context:context];
}

- (NSArray<NSURL *> *)cacheAliasesForAuthority:(MSIDAADAuthority *)authority
{
    self.cacheAliasesForAuthorityInvokedCount++;
    
    return [super cacheAliasesForAuthority:authority];
}

- (NSArray<NSString *> *)cacheAliasesForEnvironment:(NSString *)environment
{
    self.cacheAliasesForEnvironmentInvokedCount++;

    return [super cacheAliasesForEnvironment:environment];
}

@end

@interface MSIDAADAuthorityTests : XCTestCase

@end

@implementation MSIDAADAuthorityTests

- (void)tearDown
{
    [super tearDown];
    
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
}

#pragma mark - init

- (void)testInitAADAuthority_withValidUrlWhenTenantIsUUID_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/8eaef023-2b34-4da1-9baa-8bc8c9d6a490"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqual(authority.tenant.type, MSIDAADTenantTypeIdentifier);
    XCTAssertEqualObjects(authority.tenant.rawTenant, @"8eaef023-2b34-4da1-9baa-8bc8c9d6a490");
}

- (void)testInitAADAuthority_withValidUrlWhenTenantIsDomain_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/contoso.onmicrosoft.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqual(authority.tenant.type, MSIDAADTenantTypeIdentifier);
    XCTAssertEqualObjects(authority.tenant.rawTenant, @"contoso.onmicrosoft.com");
}

- (void)testInitAADAuthority_withValidUrlWhenTenantIsCommon_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqual(authority.tenant.type, MSIDAADTenantTypeCommon);
    XCTAssertEqualObjects(authority.tenant.rawTenant, @"common");
}

- (void)testInitAADAuthority_withValidUrlWhenTenantIsConsumers_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/consumers"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqual(authority.tenant.type, MSIDAADTenantTypeConsumers);
    XCTAssertEqualObjects(authority.tenant.rawTenant, @"consumers");
}

- (void)testInitAADAuthority_withValidUrlWhenTenantIsOrganizations_shouldReturnNilError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/organizations"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqual(authority.tenant.type, MSIDAADTenantTypeOrganizations);
    XCTAssertEqualObjects(authority.tenant.rawTenant, @"organizations");
}

- (void)testInitAADAuthority_whenUrlWithoutTenant_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"authority must have AAD tenant.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitAADAuthority_withADFSUrl_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com/adfs"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Trying to initialize AAD authority with ADFS authority url.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitAADAuthority_withB2CUrl_shouldReturnError
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://contoso.com/tfp/tenant/policy"];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Trying to initialize AAD authority with B2C authority url.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitAADAuthority_withNilUrl_shouldReturnError
{
    NSURL *authorityUrl = nil;
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertNil(authority);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"'authority' is a required parameter and must not be nil or empty.", error.userInfo[MSIDErrorDescriptionKey]);
}

- (void)testInitAADAuthority_whenAADAuthorityWithTenant_shouldReturnNormalizedAuthorityUrl
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/common/qwe" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com/common" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitAADAuthority_whenAADAuthorityWithTenantAndSlash_shouldReturnNormalizedAuthority
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/common/" msidUrl];
    NSError *error;

    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com/common" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitAADAuthority_whenValidUrl_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com/common" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"login.microsoftonline.com");
    XCTAssertNil(error);
}

- (void)testInitAADAuthority_whenValidUrlWithPort_shouldParseEnvironment
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com:8080/common" msidUrl];
    NSError *error;
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:&error];
    
    XCTAssertEqualObjects(authority.environment, @"login.microsoftonline.com:8080");
    XCTAssertNil(error);
}

#pragma mark - universalAuthorityURL

- (void)testUniversalAuthorityURL_whenTenantedAADAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/contoso.com"];
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

- (void)testUniversalAuthorityURL_whenCommonAADAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

- (void)testUniversalAuthorityURL_whenConsumersAADAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/consumers"];
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects(authorityUrl, [authority universalAuthorityURL]);
}

- (void)testUniversalAuthorityURL_whenOrganizationsAADAuhority_shouldReturnOriginalAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/organizations"];
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    XCTAssertEqualObjects([NSURL URLWithString:@"https://login.microsoftonline.com/common"], [authority universalAuthorityURL]);
}

#pragma mark - cacheUrlWithContext

- (void)testCacheUrlWithContext_whenCommonAADAuhority_shouldInvokeAADCacheWithCommonAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type url = [authority cacheUrlWithContext:nil];
    
    XCTAssertEqualObjects(authorityUrl, url);
    XCTAssertEqual(cacheMock.cacheUrlForAuthorityInvokedCount, 1);
}

- (void)testCacheUrlWithContext_whenOrganizationsAADAuhority_shouldInvokeAADCacheWithCommonAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/organizations"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type url = [authority cacheUrlWithContext:nil];
    
    XCTAssertEqualObjects(@"https://login.microsoftonline.com:8080/common", url.absoluteString);
    XCTAssertEqual(cacheMock.cacheUrlForAuthorityInvokedCount, 1);
}

- (void)testCacheUrlWithContext_whenConsumersAADAuhority_shouldInvokeAADCacheWithConsumersAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/consumers"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type url = [authority cacheUrlWithContext:nil];
    
    XCTAssertEqualObjects(authorityUrl, url);
    XCTAssertEqual(cacheMock.cacheUrlForAuthorityInvokedCount, 1);
}

- (void)testCacheUrlWithContext_whenTenantedAADAuhority_shouldInvokeAADCacheWithTenantedAuthority
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/contoso.com"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type url = [authority cacheUrlWithContext:nil];
    
    XCTAssertEqualObjects(authorityUrl, url);
    XCTAssertEqual(cacheMock.cacheUrlForAuthorityInvokedCount, 1);
}

#pragma mark - networkUrlWithContext

- (void)testNetworkUrlWithContext_whenAADAuhority_shouldInvokeAADCache
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type url = [authority networkUrlWithContext:nil];
    
    XCTAssertEqualObjects(authorityUrl, url);
    XCTAssertEqual(cacheMock.networkUrlForAuthorityInvokedCount, 1);
}

#pragma mark - legacyAccessTokenLookupAuthorities

- (void)testLegacyAccessTokenLookupAuthorities_whenAADAuhority_shouldInvokeAADCache
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];
    
    __auto_type aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqual(cacheMock.cacheAliasesForAuthorityInvokedCount, 1);
    XCTAssertEqualObjects(@[authorityUrl], aliases);
}

#pragma mark - defaultCacheEnvironmentAliases

- (void)testDefaultCacheEnvironmentAliases_whenAADAuthority_shouldInvokeAADCache
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    [authority setValue:cacheMock forKey:@"authorityCache"];

    __auto_type aliases = [authority defaultCacheEnvironmentAliases];

    XCTAssertEqual(cacheMock.cacheAliasesForEnvironmentInvokedCount, 1);
    XCTAssertEqualObjects(@[@"login.microsoftonline.com:8080"], aliases);
}

#pragma mark - isKnownHost

- (void)testIsKnownHost_whenAADAuhorityAndHostInListOfKnownHost_shouldReturnYes
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.us/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.chinacloudapi.cn/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.partner.microsoftonline.cn/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.de/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login-us.microsoftonline.com/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.usgovcloudapi.net/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
}

- (void)testIsKnownHost_whenAADAuhorityAndHostIsNotInListOfKnownHost_shouldReturnNo
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://some.net/common"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://example.com/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertFalse([authority isKnown]);
}

#pragma mark - legacyAccessTokenLookupAuthorities

- (void)testLegacyAccessTokenLookupAuthorities_whenAuthorityProvided_shouldReturnAllAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" authority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"]];
    
    NSArray *aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testDefaultCacheEnvironmentAliases_whenAuthorityProvided_shouldReturnAllEnvironments
{
    [self setupAADAuthorityCache];

    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" authority];
    NSArray *expectedAliases = @[@"login.windows.net",
                                 @"login.microsoftonline.com",
                                 @"login.microsoft.com"];

    NSArray *aliases = [authority defaultCacheEnvironmentAliases];

    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - legacyRefreshTokenLookupAliases

- (void)testLegacyRefreshTokenLookupAliases_whenAuthorityIsNotConsumers_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" authority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyRefreshTokenLookupAliases_whenAuthorityIsOrganizations_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/organizations" authority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyCacheRefreshTokenLookupAliases_whenAuthorityIsCommon_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/common" authority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyCacheRefreshTokenLookupAliases_whenAuthorityIsTenanted_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" authority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyRefreshTokenLookupAliases_whenAuthorityIsConsumers_shouldReturnEmptyAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/consumers" authority];
    NSArray *expectedAliases = @[];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - NSCopying

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" authority];
    authority.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    authority.metadata = [MSIDOpenIdProviderMetadata new];
    MSIDAADAuthority *authorityCopy = [authority copy];
    
    XCTAssertEqualObjects(authority, authorityCopy);
}

#pragma mark - isEqual

- (void)testisEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    lhs.metadata = metadata;
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    rhs.metadata = metadata;

    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenOpenIdConfigurationEndpointsAreNotEqual_shouldReturnFalse
{
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com/qwe" msidUrl];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenMetadataAreNotEqual_shouldReturnFalse
{
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    lhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" authority];
    rhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

#pragma mark - Private

- (void)setupAADAuthorityCache
{
    __auto_type cache = [MSIDAadAuthorityCache sharedInstance];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoft.com"];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
}

@end
