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

@interface MSIDAADAuthorityCacheMock : MSIDAadAuthorityCache

@property (nonatomic) NSInteger networkUrlForAuthorityInvokedCount;
@property (nonatomic) NSInteger cacheUrlForAuthorityInvokedCount;
@property (nonatomic) NSInteger cacheAliasesForAuthorityInvokedCount;

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

@end

@interface MSIDAADAuthorityTests : XCTestCase

@end

@implementation MSIDAADAuthorityTests

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

- (void)testCacheUrlWithContext_whenAADAuhority_shouldInvokeAADCache
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    authority.authorityCache = cacheMock;
    
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
    authority.authorityCache = cacheMock;
    
    __auto_type url = [authority networkUrlWithContext:nil];
    
    XCTAssertEqualObjects(authorityUrl, url);
    XCTAssertEqual(cacheMock.networkUrlForAuthorityInvokedCount, 1);
}

#pragma mark - cacheAliases

- (void)testCacheAliases_whenAADAuhority_shouldInvokeAADCache
{
    NSURL *authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com:8080/common"];
    __auto_type cacheMock = [MSIDAADAuthorityCacheMock new];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    authority.authorityCache = cacheMock;
    
    __auto_type aliases = [authority cacheAliases];
    
    XCTAssertEqual(cacheMock.cacheAliasesForAuthorityInvokedCount, 1);
    XCTAssertEqualObjects(@[authorityUrl], aliases);
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
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.de/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login-us.microsoftonline.com/common"];
    authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    XCTAssertTrue([authority isKnown]);
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.cloudgovapi.us/common"];
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

@end
