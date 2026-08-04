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

#import "MSIDSPATokenProvider.h"
#import "MSIDSPATokenAcquiring.h"
#import "MSIDLocalSPATokenAcquirer.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDBrowserNativeMessageGetTokenRoutingPolicy.h"
#import "MSIDDIContainer.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "MSIDTokenResponse.h"
#import "MSIDBrowserNativeMessageGetTokenResponse.h"

NSString *const MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX = @"[MSIDSPATokenProvider]";

@interface MSIDSPATokenProvider ()

@property (nonatomic) id<MSIDSPATokenAcquiring> acquirer;

@end

@implementation MSIDSPATokenProvider

- (instancetype)init
{
    return [self initWithAcquirer:[MSIDLocalSPATokenAcquirer new]];
}

- (instancetype)initWithAcquirer:(id<MSIDSPATokenAcquiring>)acquirer
{
    self = [super init];
    if (self)
    {
        _acquirer = acquirer;
    }
    return self;
}

// acquire Token With Result takes a BNM GetToken Request, Ctx and a completion block for
// oneAuth. The completion block is required to deliver the result back to oneAuth.
- (void)acquireTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                        context:(nullable id<MSIDRequestContext>)context
                completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ completionBlock is nil; cannot deliver result.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
        return;
    }

    // TODO: improve validation to match that of BNM for mac os
    if (![self validateRequest:request context:context completionBlock:completionBlock])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ BrowserNativeMessaging Get Token Request is not valid, returning early.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"%@ Servicing GetToken request in-process (no SSO extension). clientId: %@",
                      MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX, request.clientId);

    // Build the shared request parameters via the backend (local vs broker specific shaping).
    NSError *parametersError = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [self.acquirer requestParametersForRequest:request
                                                                                          context:context
                                                                                            error:&parametersError];
    if (!parameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to build request parameters: %@", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(parametersError));
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                         @"Failed to build SPA token request parameters.",
                                         nil, nil, parametersError, context.correlationId, nil, NO);
        completionBlock(nil, error);
        return;
    }

    // Backend pre-route decision (broker-only concerns; a no-op for the local backend).
    MSIDSPAPreRouteDecision *decision = [self.acquirer preRouteDecisionForParameters:parameters
                                                                            request:request
                                                                            context:context];
    if (decision.earlyError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Backend short-circuited routing: %@", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(decision.earlyError));
        completionBlock(nil, decision.earlyError);
        return;
    }

    MSIDAccountIdentifier *accountIdentifier = decision.resolvedAccountIdentifier ?: parameters.accountIdentifier;

    MSIDBrowserNativeMessageGetTokenRoutingPolicy *routingPolicy =
    [[MSIDDIContainer sharedInstance] resolveClass:[MSIDBrowserNativeMessageGetTokenRoutingPolicy class]];
    MSIDBrowserNativeMessageGetTokenRoute route =
    [routingPolicy routeWithForceInteractive:decision.forceInteractive
                                  promptType:parameters.promptType
                                   canShowUI:request.canShowUI
                           accountIdentifier:accountIdentifier
                       requiresHomeAccountId:NO];
    if (route != MSIDBrowserNativeMessageGetTokenRouteSilent)
    {
        [self completeWithInteractionRequiredOrFallbackForParameters:parameters
                                                            request:request
                                                            context:context
                                                        description:@"SPA token request requires user interaction."
                                           interactionRequiredError:nil
                                                    completionBlock:completionBlock];
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Routing GetToken request to silent path.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
    [self acquireTokenSilentlyWithParameters:parameters request:request context:context completionBlock:completionBlock];
}

#pragma mark - Private

- (NSError *)interactionRequiredErrorWithDescription:(NSString *)description
                                             context:(nullable id<MSIDRequestContext>)context
{
    return MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, description,
                           nil, nil, nil, context.correlationId, nil, YES);
}

- (void)completeWithInteractionRequiredOrFallbackForParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                       request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                       context:(nullable id<MSIDRequestContext>)context
                                                   description:(NSString *)description
                                      interactionRequiredError:(nullable NSError *)interactionRequiredError
                                               completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock
{
    // canShowUI is not a part of the BNM GetToken contract. see here: https://identitydivision.visualstudio.com/DevEx/_git/AuthLibrariesApiReview?path=%2FMSALJS%2FNativeBrokerExtension%2Fbroker_contract.md&_a=preview
    // the value for canShowUI must be added by OneAuth before calling MSIDSPATokenProvider acquireTokenWithRequest:context:completionBlock
    MSIDBrowserNativeMessageGetTokenRoutingPolicy *routingPolicy =
    [[MSIDDIContainer sharedInstance] resolveClass:[MSIDBrowserNativeMessageGetTokenRoutingPolicy class]];
    MSIDBrowserNativeMessageGetTokenRoute route =
    [routingPolicy routeWithForceInteractive:YES
                                  promptType:parameters.promptType
                                   canShowUI:request.canShowUI
                           accountIdentifier:parameters.accountIdentifier
                       requiresHomeAccountId:NO];
    if (route == MSIDBrowserNativeMessageGetTokenRouteInteractive)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ User interaction is required and UI is allowed; routing to interactive path.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
        __typeof(self) strongSelf = self;
        [self.acquirer acquireInteractiveWithParameters:parameters
                                               request:request
                                               context:context
                                       completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
            [strongSelf completeWithOutcome:outcome error:error request:request context:context completionBlock:completionBlock];
        }];
        return;
    }

    NSError *error = interactionRequiredError ?: [self interactionRequiredErrorWithDescription:description context:context];
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"%@ Returning interaction-required error because UI is not allowed. Reason: %@ Error: %@",
                      MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX,
                      description,
                      MSID_PII_LOG_MASKABLE(error));
    completionBlock(nil, error);
}

- (BOOL)validateRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                context:(nullable id<MSIDRequestContext>)context
        completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock
{
    if (!request)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter,
                                         @"A GetToken request is required.", nil, nil, nil,
                                         context.correlationId, nil, NO);
        completionBlock(nil, error);
        return NO;
    }

    if ([NSString msidIsStringNilOrBlank:request.clientId] ||
        [NSString msidIsStringNilOrBlank:request.redirectUri])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                         @"clientId and redirectUri are required to acquire a SPA token.",
                                         nil, nil, nil, context.correlationId, nil, NO);
        completionBlock(nil, error);
        return NO;
    }

    return YES;
}

#pragma mark - Silent path

// Delegates the actual silent acquisition to the backend, then applies the shared orchestration:
// on success shapes the response, on interaction-required runs the interactive fallback (bounded by
// canShowUI), and otherwise propagates a wrapped error.
- (void)acquireTokenSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   context:(nullable id<MSIDRequestContext>)context
                           completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock
{
    __typeof(self) strongSelf = self;
    [self.acquirer acquireSilentWithParameters:parameters
                                      request:request
                                      context:context
                              completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        if (outcome)
        {
            NSError *shapeError = nil;
            NSString *payload = [strongSelf responsePayloadFromOutcome:outcome request:request error:&shapeError];
            if (payload)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Silent GetToken request completed.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
                completionBlock(payload, nil);
            }
            else
            {
                completionBlock(nil, shapeError);
            }
            return;
        }

        if ([error.domain isEqualToString:MSIDErrorDomain] && error.code == MSIDErrorInteractionRequired)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Silent path requires user interaction.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
            [strongSelf completeWithInteractionRequiredOrFallbackForParameters:parameters
                                                                       request:request
                                                                       context:context
                                                                   description:@"Silent SPA token request requires user interaction."
                                                      interactionRequiredError:error
                                                               completionBlock:completionBlock];
            return;
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Silent GetToken request failed: %@", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(error));
        NSInteger errorCode = error ? error.code : MSIDErrorInternal;
        NSError *providerError = MSIDCreateError(MSIDErrorDomain, errorCode,
                                                 @"Silent SPA token request failed.",
                                                 nil, nil, error, context.correlationId, nil, NO);
        completionBlock(nil, providerError);
    }];
}

// Shared completion for an acquisition outcome: shapes the response on success, otherwise propagates
// the backend error.
- (void)completeWithOutcome:(nullable MSIDSPATokenAcquisitionResult *)outcome
                      error:(nullable NSError *)error
                    request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                    context:(nullable id<MSIDRequestContext>)context
            completionBlock:(MSIDSPATokenProviderCompletionBlock)completionBlock
{
    if (outcome)
    {
        NSError *shapeError = nil;
        NSString *payload = [self responsePayloadFromOutcome:outcome request:request error:&shapeError];
        if (payload)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Interactive GetToken request completed.", MSID_SPA_TOKEN_PROVIDER_LOG_PREFIX);
            completionBlock(payload, nil);
        }
        else
        {
            completionBlock(nil, shapeError);
        }
        return;
    }

    completionBlock(nil, error);
}

#pragma mark - Response shaping

// Serializes an acquisition outcome into the browser-native-message GetToken response payload (JSON string).
- (NSString *)responsePayloadFromOutcome:(MSIDSPATokenAcquisitionResult *)outcome
                                 request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   error:(NSError *__autoreleasing *)error
{
    NSDictionary *responseDictionary = [self responseDictionaryFromOutcome:outcome request:request];
    NSUUID *correlationId = outcome.tokenResult.correlationId;
    return [self serializedResponseFromDictionary:responseDictionary correlationId:correlationId error:error];
}

// Serializes a response dictionary to a JSON string, guarding against a nil or non-JSON payload.
- (NSString *)serializedResponseFromDictionary:(NSDictionary *)responseDictionary
                                 correlationId:(nullable NSUUID *)correlationId
                                         error:(NSError *__autoreleasing *)error
{
    if (!responseDictionary)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"Failed to build GetToken response payload.",
                                     nil, nil, nil, correlationId, nil, NO);
        }
        return nil;
    }

    if (![NSJSONSerialization isValidJSONObject:responseDictionary])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"GetToken response payload is not a valid JSON object.",
                                     nil, nil, nil, correlationId, nil, NO);
        }
        return nil;
    }

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:&serializationError];
    if (!data)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"Failed to serialize GetToken response payload.",
                                     nil, nil, serializationError, correlationId, nil, NO);
        }
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// Delegates GetToken response shaping to MSIDBrowserNativeMessageGetTokenResponse from the outcome's
// single canonical MSIDTokenResult, so the response contract lives in one place and depends on a
// single response type. The token result handles both the redeemed (tokenResponse present) and
// access-token cache-hit cases; a broker backend maps its MSIDBrokerOperationTokenResponse into a
// MSIDTokenResult (via the MSIDTokenResult+MSIDBrokerOperationTokenResponse category) before this.
- (NSDictionary *)responseDictionaryFromOutcome:(MSIDSPATokenAcquisitionResult *)outcome
                                        request:(MSIDBrowserNativeMessageGetTokenRequest *)request
{
    MSIDBrowserNativeMessageGetTokenResponse *getTokenResponse =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:outcome.tokenResult
                                                                   state:request.state
                                               fallbackRequestAccountUpn:(outcome.fallbackRequestAccountUpn ?: request.loginHint)];

    return [getTokenResponse jsonDictionary];
}

@end
