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
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRefreshToken.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshableToken.h"
#import "MSIDTestIdentifiers.h"
#import "NSString+MSIDTestUtil.h"

@interface MSIDDefaultSilentTokenRequest (BoundRefreshTokenTests)

- (MSIDRefreshToken *)familyRefreshTokenWithError:(NSError *__autoreleasing *)error;
- (MSIDBaseToken<MSIDRefreshableToken> *)appRefreshTokenWithError:(NSError *__autoreleasing *)error;
- (void)tryRefreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)refreshToken
              tokenType:(NSInteger)tokenType
        completionBlock:(MSIDRequestCompletionBlock)completionBlock;

@end

@interface MSIDReceiptMismatchSilentTokenRequest : MSIDDefaultSilentTokenRequest

@property (nonatomic) NSError *receiptError;
@property (nonatomic) NSUInteger redemptionCount;
@property (nonatomic) NSUInteger familyTokenLookupCount;

@end

@implementation MSIDReceiptMismatchSilentTokenRequest

- (MSIDRefreshToken *)familyRefreshTokenWithError:(__unused NSError *__autoreleasing *)error
{
    self.familyTokenLookupCount++;
    MSIDRefreshToken *token = [MSIDRefreshToken new];
    token.refreshToken = @"family-token";
    return token;
}

- (void)redeemAccessTokenWith:(__unused MSIDBaseToken<MSIDRefreshableToken> *)refreshToken
              completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    self.redemptionCount++;
    completionBlock(nil, self.receiptError);
}

@end

@interface MSIDBoundRefreshTokenCacheAccessorMock : MSIDDefaultTokenCacheAccessor

@property (nonatomic) MSIDRefreshToken *refreshToken;
@property (nonatomic) NSUInteger refreshTokenLookupCount;

@end

@implementation MSIDBoundRefreshTokenCacheAccessorMock

- (MSIDRefreshToken *)getRefreshTokenWithAccount:(__unused MSIDAccountIdentifier *)account
                                        familyId:(__unused NSString *)familyId
                                   configuration:(__unused MSIDConfiguration *)configuration
                                         context:(__unused id<MSIDRequestContext>)context
                                           error:(__unused NSError *__autoreleasing *)error
{
    self.refreshTokenLookupCount++;
    return self.refreshToken;
}

@end

@interface MSIDDefaultSilentTokenRequestBoundRefreshTokenTests : XCTestCase

@end

@implementation MSIDDefaultSilentTokenRequestBoundRefreshTokenTests

- (void)testReceiptMismatchDoesNotRetryOrBecomeInteractionOrBartError
{
    MSIDRefreshToken *regular = [MSIDRefreshToken new];
    regular.refreshToken = @"app-token";
    MSIDBoundRefreshToken *bound = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:regular boundDeviceId:@"device-id"];
    for (MSIDRefreshToken *token in @[regular, bound])
    {
        MSIDReceiptMismatchSilentTokenRequest *request = [MSIDReceiptMismatchSilentTokenRequest new];
        request.receiptError = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorAgeAssuranceTargetMismatch,
                                               @"Receipt mismatch.", @"age_assurance_target_mismatch",
                                               nil, nil, nil, nil, NO);
        __block BOOL completed = NO;
        // App refresh-token path: a generic OAuth error would otherwise try FRT or become interaction-required.
        [request tryRefreshToken:token tokenType:0 completionBlock:^(MSIDTokenResult *result, NSError *error)
         {
            completed = YES;
            XCTAssertNil(result);
            XCTAssertEqualObjects(error, request.receiptError);
         }];
        XCTAssertTrue(completed);
        XCTAssertEqual(request.redemptionCount, 1u);
        XCTAssertEqual(request.familyTokenLookupCount, 0u);
        XCTAssertFalse(request.shouldSkipBoundAppRefreshTokenUsage);
    }
}

- (MSIDBoundRefreshTokenCacheAccessorMock *)tokenCacheWithRefreshToken:(MSIDRefreshToken *)refreshToken
{
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache =
    [[MSIDBoundRefreshTokenCacheAccessorMock alloc] initWithDataSource:[MSIDTestCacheDataSource new]
                                                   otherCacheAccessors:nil];
    tokenCache.refreshToken = refreshToken;
    return tokenCache;
}

- (MSIDDefaultSilentTokenRequest *)silentRequestWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
{
    MSIDRequestParameters *parameters = [MSIDRequestParameters new];
    parameters.authority = [DEFAULT_TEST_AUTHORITY_GUID aadAuthority];
    parameters.clientId = @"client-id";
    parameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                          homeAccountId:DEFAULT_TEST_HOME_ACCOUNT_ID];

    MSIDAccountMetadataCacheAccessor *metadataCache =
    [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new]];

    return [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                               forceRefresh:NO
                                                               oauthFactory:[MSIDAADV2Oauth2Factory new]
                                                     tokenResponseValidator:[MSIDTokenResponseValidator new]
                                                                 tokenCache:tokenCache
                                                       accountMetadataCache:metadataCache];
}

- (void)testRequiresBoundRefreshToken_whenNotSet_shouldAllowRegularRefreshToken
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];

    XCTAssertFalse(silentRequest.requiresBoundRefreshToken);
    XCTAssertEqual([silentRequest appRefreshTokenWithError:nil], refreshToken);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenRegularRefreshTokenFound_shouldRejectToken
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertNil([silentRequest appRefreshTokenWithError:nil]);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenBoundRefreshTokenFound_shouldReturnToken
{
    MSIDRefreshToken *regularRefreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshToken *refreshToken = [[MSIDBoundRefreshToken alloc] initWithRefreshToken:regularRefreshToken
                                                                               boundDeviceId:@"device-id"];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertEqual([silentRequest appRefreshTokenWithError:nil], refreshToken);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 1u);
}

- (void)testRequiresBoundRefreshToken_whenFamilyRefreshTokenRequested_shouldSkipLookup
{
    MSIDRefreshToken *refreshToken = [MSIDRefreshToken new];
    MSIDBoundRefreshTokenCacheAccessorMock *tokenCache = [self tokenCacheWithRefreshToken:refreshToken];
    MSIDDefaultSilentTokenRequest *silentRequest = [self silentRequestWithTokenCache:tokenCache];
    silentRequest.requiresBoundRefreshToken = YES;

    XCTAssertNil([silentRequest familyRefreshTokenWithError:nil]);
    XCTAssertEqual(tokenCache.refreshTokenLookupCount, 0u);
}

@end
