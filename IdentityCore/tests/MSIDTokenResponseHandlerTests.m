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
#import "MSIDTokenResponseHandler.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDTokenResponse.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDTestIdentifiers.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDCache.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountMetadataCacheAccessor.h"

#pragma mark - Mock Token Response Validator

@interface MSIDMockTokenResponseValidator : MSIDTokenResponseValidator

@property (nonatomic) MSIDTokenResult *mockResult;

@end

@implementation MSIDMockTokenResponseValidator

- (nullable MSIDTokenResult *)validateAndSaveTokenResponse:(nonnull MSIDTokenResponse *)tokenResponse
                                              oauthFactory:(nonnull MSIDOauth2Factory *)factory
                                                tokenCache:(nonnull id<MSIDCacheAccessor>)tokenCache
                                      accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)metadataCache
                                         requestParameters:(nonnull MSIDRequestParameters *)parameters
                                          saveSSOStateOnly:(BOOL)saveSSOStateOnly
                                                     error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return self.mockResult;
}

@end

#pragma mark - Tests

@interface MSIDTokenResponseHandlerTests : XCTestCase

@property (nonatomic) MSIDTokenResponseHandler *handler;
@property (nonatomic) MSIDMockTokenResponseValidator *mockValidator;

@end

@implementation MSIDTokenResponseHandlerTests

- (void)setUp
{
    [super setUp];
    self.handler = [MSIDTokenResponseHandler new];
    self.mockValidator = [MSIDMockTokenResponseValidator new];
    self.mockValidator.mockResult = [self createMockTokenResult];
}

- (MSIDTokenResult *)createMockTokenResult
{
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDTestParametersProvider testInteractiveParameters];

    NSDictionary *testResponse = [MSIDTestURLResponse tokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                               responseRT:DEFAULT_TEST_REFRESH_TOKEN
                                                               responseID:nil
                                                            responseScope:nil
                                                       responseClientInfo:nil
                                                                expiresIn:nil
                                                                     foci:nil
                                                             extExpiresIn:nil];

    MSIDAADV2Oauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponse *response = [factory tokenResponseFromJSON:testResponse context:nil error:nil];
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:parameters.msidConfiguration];
    MSIDAccount *account = [factory accountFromResponse:response configuration:parameters.msidConfiguration];

    return [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                           refreshToken:nil
                                                idToken:response.idToken
                                                account:account
                                              authority:parameters.authority
                                          correlationId:[NSUUID new]
                                          tokenResponse:response];
}

@end

