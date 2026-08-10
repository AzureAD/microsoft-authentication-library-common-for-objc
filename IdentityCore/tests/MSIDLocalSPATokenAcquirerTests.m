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
#import "MSIDLocalSPATokenAcquirer.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "MSIDError.h"

@interface MSIDLocalSPASilentRequestMock : MSIDDefaultSilentTokenRequest

@property (nonatomic, nullable) MSIDTokenResult *result;
@property (nonatomic, nullable) NSError *error;

@end

@implementation MSIDLocalSPASilentRequestMock

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    completionBlock(self.result, self.error);
}

@end

@interface MSIDLocalSPATokenAcquirerTests : XCTestCase

@property (nonatomic, nullable) MSIDLocalSPASilentRequestMock *silentRequest;

@end

@implementation MSIDLocalSPATokenAcquirerTests

- (MSIDBrowserNativeMessageGetTokenRequest *)request
{
    MSIDBrowserNativeMessageGetTokenRequest *request = [MSIDBrowserNativeMessageGetTokenRequest new];
    request.clientId = @"00000000-0000-0000-0000-000000000001";
    request.redirectUri = @"brk-com.microsoft.test://auth";
    request.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                    rawTenant:nil
                                                      context:nil
                                                        error:nil];
    request.scopes = @"user.read";
    request.loginHint = @"user@contoso.com";
    request.accountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:request.loginHint
                                                              homeAccountId:@"uid.utid"];
    return request;
}

- (MSIDLocalSPATokenAcquirer *)acquirerWithResult:(MSIDTokenResult *)result error:(NSError *)error
{
    return [[MSIDLocalSPATokenAcquirer alloc]
            initWithSilentTokenRequestProvider:^MSIDDefaultSilentTokenRequest *(__unused MSIDInteractiveTokenRequestParameters *parameters,
                                                                                __unused id<MSIDRequestContext> context) {
        self.silentRequest = [MSIDLocalSPASilentRequestMock new];
        self.silentRequest.result = result;
        self.silentRequest.error = error;
        return self.silentRequest;
    }];
}

- (MSIDInteractiveTokenRequestParameters *)parametersWithAcquirer:(MSIDLocalSPATokenAcquirer *)acquirer
{
    NSError *error = nil;
    MSIDInteractiveTokenRequestParameters *parameters =
    [acquirer requestParametersForRequest:[self request] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(parameters);
    return parameters;
}

- (void)testRequestParametersForRequest_whenLocalBackend_shouldRequestAppBoundToken
{
    MSIDLocalSPATokenAcquirer *acquirer = [MSIDLocalSPATokenAcquirer new];
    MSIDInteractiveTokenRequestParameters *parameters = [self parametersWithAcquirer:acquirer];

    XCTAssertEqual(parameters.requestType, MSIDRequestBrokeredType);
    XCTAssertTrue(parameters.isBoundAppRefreshTokenRequested);
    XCTAssertEqualObjects(parameters.accountIdentifier.homeAccountId, @"uid.utid");
}

- (void)testAcquireSilent_whenEngineReturnsResult_shouldRequireBoundRefreshToken
{
    MSIDTokenResult *result = [MSIDTokenResult new];
    result.account = [MSIDAccount new];
    result.account.username = @"cached@contoso.com";

    MSIDLocalSPATokenAcquirer *acquirer = [self acquirerWithResult:result error:nil];
    __block MSIDSPATokenAcquisitionResult *outcome = nil;
    __block NSError *acquisitionError = nil;

    [acquirer acquireSilentWithParameters:[self parametersWithAcquirer:acquirer]
                                  request:[self request]
                                  context:nil
                          completionBlock:^(MSIDSPATokenAcquisitionResult *resultOutcome, NSError *error) {
        outcome = resultOutcome;
        acquisitionError = error;
    }];

    XCTAssertNil(acquisitionError);
    XCTAssertEqual(outcome.tokenResult, result);
    XCTAssertEqualObjects(outcome.fallbackRequestAccountUpn, @"cached@contoso.com");
    XCTAssertTrue(self.silentRequest.requiresBoundRefreshToken);
}

- (void)testAcquireSilent_whenEngineFails_shouldReturnOriginalError
{
    NSError *engineError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerOauth,
                                           @"Server rejected the request.", nil, nil, nil, nil, nil, NO);
    MSIDLocalSPATokenAcquirer *acquirer = [self acquirerWithResult:nil error:engineError];
    __block NSError *acquisitionError = nil;

    [acquirer acquireSilentWithParameters:[self parametersWithAcquirer:acquirer]
                                  request:[self request]
                                  context:nil
                          completionBlock:^(__unused MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        acquisitionError = error;
    }];

    XCTAssertEqual(acquisitionError, engineError);
}

- (void)testAcquireSilent_whenBARTRedemptionFails_shouldRequireInteractionWithoutRegularRTFallback
{
    NSError *bartError = MSIDCreateError(MSIDErrorDomain, MSIDErrorBoundAppRefreshTokenRedemptionError,
                                         @"BART redemption failed.", nil, nil, nil, nil, nil, YES);
    MSIDLocalSPATokenAcquirer *acquirer = [self acquirerWithResult:nil error:bartError];
    __block NSError *acquisitionError = nil;

    [acquirer acquireSilentWithParameters:[self parametersWithAcquirer:acquirer]
                                  request:[self request]
                                  context:nil
                          completionBlock:^(__unused MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        acquisitionError = error;
    }];

    XCTAssertEqualObjects(acquisitionError.domain, MSIDErrorDomain);
    XCTAssertEqual(acquisitionError.code, MSIDErrorInteractionRequired);
    XCTAssertEqual(acquisitionError.userInfo[NSUnderlyingErrorKey], bartError);
}

- (void)testAcquireSilent_whenCacheUnavailable_shouldReturnInteractionRequired
{
    MSIDLocalSPATokenAcquirer *acquirer = [[MSIDLocalSPATokenAcquirer alloc]
        initWithSilentTokenRequestProvider:^MSIDDefaultSilentTokenRequest *(__unused MSIDInteractiveTokenRequestParameters *parameters,
                                                                            __unused id<MSIDRequestContext> context) {
        return nil;
    }];
    __block NSError *acquisitionError = nil;

    [acquirer acquireSilentWithParameters:[self parametersWithAcquirer:acquirer]
                                  request:[self request]
                                  context:nil
                          completionBlock:^(__unused MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        acquisitionError = error;
    }];

    XCTAssertEqualObjects(acquisitionError.domain, MSIDErrorDomain);
    XCTAssertEqual(acquisitionError.code, MSIDErrorInteractionRequired);
}

@end
