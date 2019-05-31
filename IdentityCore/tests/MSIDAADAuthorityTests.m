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
#import "MSIDIntuneInMemoryCacheDataSource.h"
#import "MSIDIntuneEnrollmentIdsCache.h"

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
    [self setUpEnrollmentIdsCache:YES];
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

- (void)testInitAADAuthority_andRawTenant_whenTenantNotIdentifier_shouldReplaceTenantId
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com:8080/common" msidUrl];
    NSError *error = nil;

    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:@"new_tenantId" context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com:8080/new_tenantId" msidUrl]);
    XCTAssertNil(error);
}

- (void)testInitAADAuthority_andRawTenant_whenTenantIdentifier_shouldReplaceTenantId
{
    __auto_type authorityUrl = [@"https://login.microsoftonline.com:8080/contoso.com" msidUrl];
    NSError *error = nil;

    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl rawTenant:@"new_tenantId" context:nil error:&error];

    XCTAssertEqualObjects(authority.url, [@"https://login.microsoftonline.com:8080/new_tenantId" msidUrl]);
    XCTAssertNil(error);
}

#pragma mark - AAD authority

- (void)testAADAuthorityWithEnvironmentAndRawTenant_whenTenantIdProvided_shouldReturnAuthorityWithTenantId
{
    NSError *error = nil;
    MSIDAADAuthority *authority = [MSIDAADAuthority aadAuthorityWithEnvironment:@"login.microsoftonline.com"
                                                                      rawTenant:@"contoso.com"
                                                                        context:nil
                                                                          error:&error];
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqualObjects(authority.url, [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"]);
}

- (void)testAADAuthorityWithEnvironmentAndRawTenant_whenNoTenantIdProvided_shouldReturnAuthorityWithCommonTenant
{
    NSError *error = nil;
    MSIDAADAuthority *authority = [MSIDAADAuthority aadAuthorityWithEnvironment:@"login.microsoftonline.com"
                                                                      rawTenant:nil
                                                                        context:nil
                                                                          error:&error];
    XCTAssertNotNil(authority);
    XCTAssertNil(error);
    XCTAssertEqualObjects(authority.url, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
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

#pragma mark - enrollmentIdForHomeAccountId

- (void)testEnrollmentIdForHomeAccountId_whenValidHomeAccountId_shouldReturnEnrollmentId
{
    [self setUpEnrollmentIdsCache:NO];
    
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    NSError *error = nil;
    
    XCTAssertEqual([authority enrollmentIdForHomeAccountId:@"1e4dd613-dave-4527-b50a-97aca38b57ba" legacyUserId:nil context:nil error:&error], @"64d0557f-dave-4193-b630-8491ffd3b180");
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenNilHomeAccountIdAndValidUserId_shouldReturnEnrollmentId
{
    [self setUpEnrollmentIdsCache:NO];
    
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    NSError *error = nil;
    
    XCTAssertEqual([authority enrollmentIdForHomeAccountId:nil legacyUserId:@"dave@contoso.com" context:nil error:&error], @"64d0557f-dave-4193-b630-8491ffd3b180");
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenUnenrolledHomeAccountIdAndUserId_shouldReturnFirstEnrollmentId
{
    [self setUpEnrollmentIdsCache:NO];
    
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    NSError *error = nil;
    
    XCTAssertEqual([authority enrollmentIdForHomeAccountId:@"homeAccountId" legacyUserId:@"user@contoso.com" context:nil error:&error], @"adf79e3f-mike-454d-9f0f-2299e76dbfd5");
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenNilHomeAccountIdAndUserId_shouldReturnFirstEnrollmentId
{
    [self setUpEnrollmentIdsCache:NO];
    
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    MSIDAADAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    NSError* error = nil;
    
    XCTAssertEqual([authority enrollmentIdForHomeAccountId:nil legacyUserId:nil context:nil error:&error], @"adf79e3f-mike-454d-9f0f-2299e76dbfd5");
    XCTAssertNil(error);
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
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/contoso.com"]];
    
    NSArray *aliases = [authority legacyAccessTokenLookupAuthorities];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testDefaultCacheEnvironmentAliases_whenAuthorityProvided_shouldReturnAllEnvironments
{
    [self setupAADAuthorityCache];

    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
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
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
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
    
    __auto_type authority = [@"https://login.microsoftonline.com/organizations" aadAuthority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyCacheRefreshTokenLookupAliases_whenAuthorityIsCommon_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    NSArray *expectedAliases = @[[NSURL URLWithString:@"https://login.windows.net/common"],
                                 [NSURL URLWithString:@"https://login.microsoftonline.com/common"],
                                 [NSURL URLWithString:@"https://login.microsoft.com/common"]];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

- (void)testLegacyCacheRefreshTokenLookupAliases_whenAuthorityIsTenanted_shouldReturnAliases
{
    [self setupAADAuthorityCache];
    
    __auto_type authority = [@"https://login.microsoftonline.com/contoso.com" aadAuthority];
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
    
    __auto_type authority = [@"https://login.microsoftonline.com/consumers" aadAuthority];
    NSArray *expectedAliases = @[];
    
    NSArray *aliases = [authority legacyRefreshTokenLookupAliases];
    
    XCTAssertEqualObjects(aliases, expectedAliases);
}

#pragma mark - NSCopying

- (void)testCopy_whenAllPropertiesAreSet_shouldReturnEqualCopy
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    authority.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    authority.metadata = [MSIDOpenIdProviderMetadata new];
    MSIDAADAuthority *authorityCopy = [authority copy];
    
    XCTAssertEqualObjects(authority, authorityCopy);
}

#pragma mark - isEqual

- (void)testisEqual_whenAllPropertiesAreEqual_shouldReturnTrue
{
    __auto_type metadata = [MSIDOpenIdProviderMetadata new];
    
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    lhs.metadata = metadata;
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    rhs.metadata = metadata;

    XCTAssertEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenOpenIdConfigurationEndpointsAreNotEqual_shouldReturnFalse
{
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
    lhs.openIdConfigurationEndpoint = [@"https://example.com" msidUrl];
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
    rhs.openIdConfigurationEndpoint = [@"https://example.com/qwe" msidUrl];
    
    XCTAssertNotEqualObjects(lhs, rhs);
}

- (void)testIsEqual_whenMetadataAreNotEqual_shouldReturnFalse
{
    MSIDAADAuthority *lhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
    lhs.metadata = [MSIDOpenIdProviderMetadata new];
    
    MSIDAADAuthority *rhs = (MSIDAADAuthority *)[@"https://login.microsoftonline.com/common" aadAuthority];
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

- (void)setUpEnrollmentIdsCache:(BOOL)isEmpty
{
    NSDictionary *emptyDict = @{};
    
    NSDictionary *dict = @{MSID_INTUNE_ENROLLMENT_ID_KEY: @{@"enrollment_ids": @[@{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                                                                     @"home_account_id" : @"60406d5d-mike-41e1-aa70-e97501076a22",
                                                                                     @"user_id" : @"mike@contoso.com",
                                                                                     @"enrollment_id" : @"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                                                                     },
                                                                                 @{
                                                                                     @"tid" : @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                                                                     @"oid" : @"6eec576f-dave-416a-9c4a-536b178a194a",
                                                                                     @"home_account_id" : @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                                                                                     @"user_id" : @"dave@contoso.com",
                                                                                     @"enrollment_id" : @"64d0557f-dave-4193-b630-8491ffd3b180"
                                                                                     }
                                                                                 ]}};
    
    MSIDCache *msidCache = [[MSIDCache alloc] initWithDictionary:isEmpty ? emptyDict : dict];
    MSIDIntuneInMemoryCacheDataSource *memoryCache = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:msidCache];
    MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:memoryCache];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:enrollmentIdsCache];
}

@end
