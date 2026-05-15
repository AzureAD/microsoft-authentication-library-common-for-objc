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

#if !MSID_EXCLUDE_WEBKIT

#import <XCTest/XCTest.h>
#import "MSIDWebviewNavigationDelegateHelper.h"
#import "MSIDWebviewConstants.h"
#import "MSIDError.h"
#import "MSIDTestContext.h"

// Expose private methods and properties for testing
@interface MSIDWebviewNavigationDelegateHelper (Testing)

// Expose private methods and properties for testing.
@property (nonatomic) NSDictionary *lastResponseHeaders;

- (BOOL)isValidHandoffURL:(NSURL *)url error:(NSError *__autoreleasing *)error;
- (BOOL)isURLInAllowedDomains:(NSURL *)url;
- (NSDictionary<NSString *, id> *)normalizeHeaders:(NSDictionary *)headers;
- (NSString *)callbackURLScheme;
- (BOOL)shouldUseEphemeralSession;
- (nullable NSDictionary<NSString *, NSString *> *)extractAdditionalHeadersToForward;
- (NSDictionary<NSString *, NSString *> *)buildAdditionalHeadersFromList:(NSString *)attachHeadersList;

@end

@interface MSIDWebviewNavigationDelegateHelperTests : XCTestCase

@property (nonatomic) MSIDWebviewNavigationDelegateHelper *helper;
@property (nonatomic) MSIDTestContext *context;

@end

@implementation MSIDWebviewNavigationDelegateHelperTests

- (void)setUp
{
    [super setUp];
    self.context = [MSIDTestContext new];
    self.helper = [[MSIDWebviewNavigationDelegateHelper alloc] initWithContext:self.context];
}

- (void)tearDown
{
    self.helper = nil;
    self.context = nil;
    [super tearDown];
}

#pragma mark - isValidHandoffURL tests

- (void)testIsValidHandoffURL_whenURLIsNil_shouldReturnNO
{
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNoScheme_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"//login.microsoftonline.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsHTTP_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"http://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLHasNonAllowedDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.example.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidASWebAuthenticationURL);
}

- (void)testIsValidHandoffURL_whenURLIsValidHTTPSAndAllowedDomain_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testIsValidHandoffURL_whenURLSchemeIsUppercase_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"HTTPS://portal.manage.microsoft.com/path"];
    NSError *error = nil;
    BOOL result = [self.helper isValidHandoffURL:url error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#pragma mark - isURLInAllowedDomains tests

- (void)testIsURLInAllowedDomains_whenURLIsNil_shouldReturnNO
{
    XCTAssertFalse([self.helper isURLInAllowedDomains:nil]);
}

- (void)testIsURLInAllowedDomains_whenHostIsNil_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowed_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com/path"];
    XCTAssertTrue([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsNotAllowed_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://attacker.example.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenDomainIsAllowedDogfood_shouldReturnYES
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage-dogfood.microsoft.com/path"];
    XCTAssertTrue([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAllowedDomainIsSubdomainOfAttackerDomain_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://portal.manage.microsoft.com.attacker.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}

- (void)testIsURLInAllowedDomains_whenAttackerControlledSubdomainUsesAllowedDomainSuffix_shouldReturnNO
{
    NSURL *url = [NSURL URLWithString:@"https://evil.portal.manage.microsoft.com/path"];
    XCTAssertFalse([self.helper isURLInAllowedDomains:url]);
}


#pragma mark - normalizeHeaders tests

- (void)testNormalizeHeaders_whenMixedCaseKeys_shouldLowercaseAllKeys
{
    NSDictionary *input = @{@"Content-Type": @"application/json",
                            @"X-MS-ASWEBAUTH-HANDOFF-URL": @"https://example.com"};
    NSDictionary *result = [self.helper normalizeHeaders:input];
    
    XCTAssertEqualObjects(result[@"content-type"], @"application/json");
    XCTAssertEqualObjects(result[@"x-ms-aswebauth-handoff-url"], @"https://example.com");
    XCTAssertNil(result[@"Content-Type"]);
}

- (void)testNormalizeHeaders_whenEmptyDictionary_shouldReturnEmptyDictionary
{
    NSDictionary *result = [self.helper normalizeHeaders:@{}];
    XCTAssertEqual(result.count, 0U);
}

#pragma mark - callbackURLScheme tests

- (void)testCallbackURLScheme_whenHeaderAbsent_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsNonString_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @42};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsEmptyString_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @""};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderIsWhitespaceOnly_shouldReturnDefaultMsauth
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"   "};
    XCTAssertEqualObjects([self.helper callbackURLScheme], MSID_SCHEME_MSAUTH);
}

- (void)testCallbackURLScheme_whenHeaderHasValidScheme_shouldReturnTrimmedScheme
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"myapp"};
    XCTAssertEqualObjects([self.helper callbackURLScheme], @"myapp");
}

- (void)testCallbackURLScheme_whenHeaderHasPaddedScheme_shouldReturnTrimmedScheme
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY: @"  myapp  "};
    XCTAssertEqualObjects([self.helper callbackURLScheme], @"myapp");
}

#pragma mark - shouldUseEphemeralSession tests

- (void)testShouldUseEphemeralSession_whenHeaderAbsent_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsNonString_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @42};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalse_shouldReturnNO
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"false"};
    XCTAssertFalse([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsFalseUppercase_shouldReturnNO
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"FALSE"};
    XCTAssertFalse([self.helper shouldUseEphemeralSession]);
}

- (void)testShouldUseEphemeralSession_whenHeaderIsTrue_shouldReturnYES
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY: @"true"};
    XCTAssertTrue([self.helper shouldUseEphemeralSession]);
}

#pragma mark - extractAdditionalHeadersToForward tests

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersAbsent_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsFalse_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"false"};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersIsNonString_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @42};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueButAttachHeadersMissing_shouldReturnNil
{
    self.helper.lastResponseHeaders = @{MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true"};
    XCTAssertNil([self.helper extractAdditionalHeadersToForward]);
}

- (void)testExtractAdditionalHeadersToForward_whenIncludeHeadersTrueAndHeaderPresent_shouldReturnHeaders
{
    NSString *customHeader = [NSString stringWithFormat:@"%@custom", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{
        MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY: @"true",
        MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY: customHeader,
        customHeader: @"value123"
    };
    
    NSDictionary *result = [self.helper extractAdditionalHeadersToForward];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[customHeader], @"value123");
}

#pragma mark - buildAdditionalHeadersFromList tests

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithAllowedPrefix_shouldInclude
{
    NSString *headerName = [NSString stringWithFormat:@"%@token", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{headerName: @"tokenvalue"};
    
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:headerName];
    XCTAssertEqualObjects(result[headerName], @"tokenvalue");
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderWithoutAllowedPrefix_shouldExclude
{
    self.helper.lastResponseHeaders = @{@"authorization": @"Bearer token"};
    
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:@"authorization"];
    XCTAssertEqual(result.count, 0U);
}

- (void)testBuildAdditionalHeadersFromList_whenMultipleHeaders_shouldReturnOnlyPresentAndPrefixed
{
    NSString *validHeader = [NSString stringWithFormat:@"%@valid", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    NSString *missingHeader = [NSString stringWithFormat:@"%@missing", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{validHeader: @"val"};
    
    NSString *list = [NSString stringWithFormat:@"%@,%@,authorization", validHeader, missingHeader];
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:list];
    
    XCTAssertEqualObjects(result[validHeader], @"val");
    XCTAssertNil(result[missingHeader]);
    XCTAssertNil(result[@"authorization"]);
    XCTAssertEqual(result.count, 1U);
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderNameHasSpaces_shouldTrimAndLookup
{
    NSString *headerName = [NSString stringWithFormat:@"%@spaced", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX];
    self.helper.lastResponseHeaders = @{headerName: @"spacedval"};
    
    NSString *list = [NSString stringWithFormat:@"  %@  ", headerName];
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:list];
    
    XCTAssertEqualObjects(result[headerName], @"spacedval");
    XCTAssertEqual(result.count, 1U);
}

- (void)testBuildAdditionalHeadersFromList_whenHeaderKeyIsMixedCase_shouldNormalizeAndFind
{
    // This end-to-end test verifies that the key-casing contract between normalizeHeaders:
    // and buildAdditionalHeadersFromList: is upheld: normalizeHeaders: lowercases all keys,
    // so the lookup in buildAdditionalHeadersFromList: (which uses lowercaseTrimmed) must
    // still find values stored with any original casing.
    NSString *upperCaseHeader = [[NSString stringWithFormat:@"%@token", MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX] uppercaseString];
    NSString *lowerCaseHeader = [upperCaseHeader lowercaseString];
    
    // Simulate what processResponseHeaders: does: normalize the raw server headers first
    NSDictionary *rawHeaders = @{upperCaseHeader: @"tok123"};
    NSDictionary *normalised = [self.helper normalizeHeaders:rawHeaders];
    self.helper.lastResponseHeaders = normalised;
    
    // attach-headers names are delivered in their original (uppercase) casing from the server
    NSDictionary *result = [self.helper buildAdditionalHeadersFromList:upperCaseHeader];
    
    // The value should be found regardless of the key casing in attach-headers
    XCTAssertEqualObjects(result[upperCaseHeader], @"tok123");
    XCTAssertEqual(result.count, 1U);
    
    // The normalised dictionary should have stored the value under the lowercased key
    XCTAssertEqualObjects(normalised[lowerCaseHeader], @"tok123");
    XCTAssertNil(normalised[upperCaseHeader]);
}

@end

#endif
