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
#import "MSIDBoundTokenProvider.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters+BrowserNativeMessageGetToken.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSPATokenAcquisitionResult.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADAuthority.h"
#import "MSIDError.h"

@interface MSIDSPATokenAcquirerMock : NSObject <MSIDSPATokenAcquiring>

@property (nonatomic) NSUInteger silentCallCount;
@property (nonatomic) NSUInteger interactiveCallCount;
@property (nonatomic, nullable) NSError *parametersError;
@property (nonatomic, nullable) MSIDSPATokenAcquisitionResult *silentOutcome;
@property (nonatomic, nullable) NSError *silentError;
@property (nonatomic, nullable) MSIDSPATokenAcquisitionResult *interactiveOutcome;
@property (nonatomic, nullable) NSError *interactiveError;

@end

@implementation MSIDSPATokenAcquirerMock

- (nullable MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                        context:(nullable id<MSIDRequestContext>)context
                                                                          error:(NSError *_Nullable __autoreleasing *_Nullable)error
{
    if (self.parametersError)
    {
        if (error) *error = self.parametersError;
        return nil;
    }

    return [MSIDInteractiveTokenRequestParameters msidParametersWithGetTokenRequest:request
                                                                       requestType:MSIDRequestBrokeredType
                                                     boundAppRefreshTokenRequested:YES
                                                             correlationIdOverride:context.correlationId
                                                                             error:error];
}

- (void)acquireSilentWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                            request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(nullable __unused id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    self.silentCallCount++;
    completionBlock(self.silentOutcome, self.silentError);
}

- (void)acquireInteractiveWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(nullable __unused id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    self.interactiveCallCount++;
    completionBlock(self.interactiveOutcome, self.interactiveError);
}

@end

@interface MSIDBoundTokenProviderTests : XCTestCase
@end

@implementation MSIDBoundTokenProviderTests

- (MSIDBrowserNativeMessageGetTokenRequest *)validRequest
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.clientId = @"00000000-0000-0000-0000-000000000001";
    request.redirectUri = @"brk-com.microsoft.test://auth";
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                    rawTenant:nil
                                                      context:nil
                                                        error:nil];
    request.scopes = @"user.read";
    request.state = @"test-state";
    request.prompt = MSIDPromptTypeDefault;
    request.canShowUI = YES;
    request.loginHint = @"user@contoso.com";
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:request.loginHint
                                                              homeAccountId:@"uid.utid"];
    return request;
}

- (MSIDSPATokenAcquisitionResult *)successfulOutcome
{
    MSIDAccessToken *accessToken = [MSIDAccessToken new];
    accessToken.accessToken = @"access-token";
    accessToken.tokenType = @"Bearer";
    accessToken.scopes = [NSOrderedSet orderedSetWithObject:@"user.read"];
    MSIDAccount *account = [MSIDAccount new];
    account.username = @"user@contoso.com";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:account.username
                                                                      homeAccountId:@"uid.utid"];
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.accessToken = accessToken;
    tokenResult.account = account;
    MSIDSPATokenAcquisitionResult *outcome = [MSIDSPATokenAcquisitionResult new];
    outcome.tokenResult = tokenResult;
    outcome.fallbackRequestAccountUpn = account.username;
    return outcome;
}

- (NSDictionary *)payloadFromResponse:(NSString *)response
{
    XCTAssertNotNil(response);
    NSData *data = [response dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNotNil(data);
    NSError *error = nil;
    id payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    XCTAssertNotNil(payload, @"Failed to parse response JSON: %@", error);
    XCTAssertTrue([payload isKindOfClass:NSDictionary.class]);
    return [payload isKindOfClass:NSDictionary.class] ? payload : nil;
}

- (void)testAcquireBoundToken_whenSilentSucceeds_shouldReturnBrowserResponse
{
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    acquirer.silentOutcome = [self successfulOutcome];
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    __block NSString *response = nil;
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(NSString *result, NSError *error) {
        response = result;
        responseError = error;
    }];
    NSDictionary *payload = [self payloadFromResponse:response];
    XCTAssertNil(responseError);
    XCTAssertEqual(acquirer.silentCallCount, 1);
    XCTAssertEqual(acquirer.interactiveCallCount, 0);
    XCTAssertEqualObjects(payload[@"access_token"], @"access-token");
    XCTAssertEqualObjects(payload[@"account"][@"userName"], @"user@contoso.com");
    XCTAssertEqualObjects(payload[@"state"], @"test-state");
}

- (void)testAcquireBoundToken_whenPromptRequiresUI_shouldUseInteractiveBackend
{
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    acquirer.interactiveOutcome = [self successfulOutcome];
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeSelectAccount;
    __block NSString *response = nil;
    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(NSString *result, __unused NSError *error) {
        response = result;
    }];
    XCTAssertEqual(acquirer.silentCallCount, 0);
    XCTAssertEqual(acquirer.interactiveCallCount, 1);
    XCTAssertEqualObjects([self payloadFromResponse:response][@"access_token"], @"access-token");
}

- (void)testAcquireBoundToken_whenSilentRequiresInteraction_shouldFallbackOnce
{
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    acquirer.silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                           @"Interaction required.", nil, nil, nil, nil, nil, YES);
    acquirer.interactiveOutcome = [self successfulOutcome];
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    __block NSString *response = nil;
    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(NSString *result, __unused NSError *error) {
        response = result;
    }];
    XCTAssertEqual(acquirer.silentCallCount, 1);
    XCTAssertEqual(acquirer.interactiveCallCount, 1);
    XCTAssertNotNil(response);
}

- (void)testAcquireBoundToken_whenUIIsBlocked_shouldReturnInteractionRequired
{
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.prompt = MSIDPromptTypeSelectAccount;
    request.canShowUI = NO;
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(acquirer.silentCallCount, 0);
    XCTAssertEqual(acquirer.interactiveCallCount, 0);
    XCTAssertEqual(responseError.code, MSIDErrorInteractionRequired);
}

- (void)testAcquireBoundToken_whenSilentFailsHard_shouldReturnOriginalError
{
    NSError *silentError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerOauth,
                                           @"Server error.", nil, nil, nil, nil, nil, NO);
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    acquirer.silentError = silentError;
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(responseError, silentError);
    XCTAssertEqual(acquirer.interactiveCallCount, 0);
}

- (void)testAcquireBoundToken_whenParameterMappingFails_shouldReturnDeveloperError
{
    MSIDSPATokenAcquirerMock *acquirer = [MSIDSPATokenAcquirerMock new];
    acquirer.parametersError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter,
                                               @"Mapping failed.", nil, nil, nil, nil, nil, NO);
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:acquirer];
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:[self validRequest]
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(responseError.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertEqual(responseError.userInfo[NSUnderlyingErrorKey], acquirer.parametersError);
}

- (void)testAcquireBoundToken_whenRequestIsNil_shouldReturnInvalidInternalParameter
{
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:[MSIDSPATokenAcquirerMock new]];
    MSIDBrowserNativeMessageGetTokenRequest *nilRequest = nil;
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:nilRequest
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(responseError.code, MSIDErrorInvalidInternalParameter);
}

- (void)testAcquireBoundToken_whenClientIdIsMissing_shouldReturnInvalidDeveloperParameter
{
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:[MSIDSPATokenAcquirerMock new]];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.clientId = @"";
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(responseError.code, MSIDErrorInvalidDeveloperParameter);
}

- (void)testAcquireBoundToken_whenRedirectUriIsMissing_shouldReturnInvalidDeveloperParameter
{
    MSIDBoundTokenProvider *provider = [[MSIDBoundTokenProvider alloc] initWithAcquirer:[MSIDSPATokenAcquirerMock new]];
    MSIDBrowserNativeMessageGetTokenRequest *request = [self validRequest];
    request.redirectUri = @"";
    __block NSError *responseError = nil;
    [provider acquireBoundTokenWithRequest:request
                                   context:nil
                           completionBlock:^(__unused NSString *result, NSError *error) {
        responseError = error;
    }];
    XCTAssertEqual(responseError.code, MSIDErrorInvalidDeveloperParameter);
}

@end
