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

#import "MSIDBoundTokenProvider.h"
#import "MSIDLocalSPATokenAcquirer.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDBrowserNativeMessageGetTokenRoutingPolicy.h"
#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSPATokenAcquisitionResult.h"
#import "MSIDDIContainer.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "NSString+MSIDExtensions.h"

NSString *const MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX = @"[MSIDBoundTokenProvider]";

@interface MSIDBoundTokenProvider ()
@property (nonatomic) id<MSIDSPATokenAcquiring> acquirer;
@end

@implementation MSIDBoundTokenProvider

- (instancetype)init
{
    return [self initWithAcquirer:[MSIDLocalSPATokenAcquirer new]];
}

- (instancetype)initWithAcquirer:(id<MSIDSPATokenAcquiring>)acquirer
{
    NSParameterAssert(acquirer);
    self = [super init];
    if (self)
    {
        _acquirer = acquirer;
    }
    return self;
}

- (void)acquireBoundTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                             context:(nullable id<MSIDRequestContext>)context
                     completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ completionBlock is nil.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return;
    }
    if (![self validateRequest:request context:context completionBlock:completionBlock])
    {
        return;
    }
    NSError *parametersError = nil;
    MSIDInteractiveTokenRequestParameters *parameters =
    [self.acquirer requestParametersForRequest:request context:context error:&parametersError];
    if (!parameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to build request parameters: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(parametersError));
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                         @"Failed to build bound token request parameters.",
                                         nil, nil, parametersError, context.correlationId, nil, NO);
        completionBlock(nil, error);
        return;
    }
    MSIDBrowserNativeMessageGetTokenRoute route =
    [[self routingPolicy] routeWithForceInteractive:NO
                                         promptType:parameters.promptType
                                          canShowUI:request.canShowUI
                                  accountIdentifier:parameters.accountIdentifier
                              requiresHomeAccountId:NO];
    if (route == MSIDBrowserNativeMessageGetTokenRouteSilent)
    {
        [self acquireSilentlyWithParameters:parameters
                                    request:request
                                    context:context
                            completionBlock:completionBlock];
        return;
    }
    [self completeInteractiveRoute:route
                        parameters:parameters
                           request:request
                           context:context
                   completionBlock:completionBlock
          interactionRequiredError:nil];
}

#pragma mark - Private

- (MSIDBrowserNativeMessageGetTokenRoutingPolicy *)routingPolicy
{
    return [[MSIDDIContainer sharedInstance]
        resolveClass:MSIDBrowserNativeMessageGetTokenRoutingPolicy.class
           orDefault:^id {
               return [MSIDBrowserNativeMessageGetTokenRoutingPolicy new];
           }];
}

- (BOOL)validateRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                context:(nullable id<MSIDRequestContext>)context
        completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
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
                                         @"clientId and redirectUri are required to acquire a bound token.",
                                         nil, nil, nil, context.correlationId, nil, NO);
        completionBlock(nil, error);
        return NO;
    }
    return YES;
}

- (void)acquireSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                              request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                              context:(nullable id<MSIDRequestContext>)context
                      completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    [self.acquirer acquireSilentWithParameters:parameters
                                       request:request
                                       context:context
                               completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        if (outcome)
        {
            [self completeWithOutcome:outcome
                                error:nil
                              request:request
                              context:context
                      completionBlock:completionBlock];
            return;
        }
        BOOL interactionRequired = [error.domain isEqualToString:MSIDErrorDomain]
            && error.code == MSIDErrorInteractionRequired;
        if (interactionRequired)
        {
            MSIDBrowserNativeMessageGetTokenRoute route =
            [[self routingPolicy] routeWithForceInteractive:YES
                                                 promptType:parameters.promptType
                                                  canShowUI:request.canShowUI
                                          accountIdentifier:parameters.accountIdentifier
                                      requiresHomeAccountId:NO];
            [self completeInteractiveRoute:route
                                parameters:parameters
                                   request:request
                                   context:context
                           completionBlock:completionBlock
                  interactionRequiredError:error];
            return;
        }
        [self completeWithOutcome:nil
                            error:error
                          request:request
                          context:context
                  completionBlock:completionBlock];
    }];
}

- (void)completeInteractiveRoute:(MSIDBrowserNativeMessageGetTokenRoute)route
                      parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                         request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                         context:(nullable id<MSIDRequestContext>)context
                 completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
        interactionRequiredError:(nullable NSError *)interactionRequiredError
{
    if (route != MSIDBrowserNativeMessageGetTokenRouteInteractive)
    {
        NSString *routeReason = route == MSIDBrowserNativeMessageGetTokenRouteUIBlocked ? @"canShowUI is NO" : @"prompt=none forbids UI";
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"%@ Interactive fallback rejected. Route: %ld. Reason: %@. promptType: %ld, canShowUI: %@.",
                          MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, (long)route, routeReason, (long)parameters.promptType, request.canShowUI ? @"YES" : @"NO");
        NSError *error = interactionRequiredError
            ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                               @"Bound token acquisition requires user interaction.",
                               nil, nil, nil, context.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }
    [self.acquirer acquireInteractiveWithParameters:parameters
                                            request:request
                                            context:context
                                    completionBlock:^(MSIDSPATokenAcquisitionResult *outcome, NSError *error) {
        [self completeWithOutcome:outcome
                            error:error
                          request:request
                          context:context
                  completionBlock:completionBlock];
    }];
}

- (void)completeWithOutcome:(MSIDSPATokenAcquisitionResult *)outcome
                      error:(nullable NSError *)error
                    request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                    context:(nullable id<MSIDRequestContext>)context
            completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    if (!outcome)
    {
        NSError *completionError = error
            ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                               @"Bound token acquisition completed without a result or error.",
                               nil, nil, nil, context.correlationId, nil, YES);
        completionBlock(nil, completionError);
        return;
    }
    NSString *fallbackUpn = outcome.fallbackRequestAccountUpn;
    if ([NSString msidIsStringNilOrBlank:fallbackUpn])
    {
        fallbackUpn = request.loginHint;
    }
    MSIDBrowserNativeMessageGetTokenResponse *response =
    [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResult:outcome.tokenResult
                                                                    state:request.state
                                                fallbackRequestAccountUpn:fallbackUpn];
    NSDictionary *responseDictionary = response ? [response jsonDictionary] : nil;
    NSError *serializationError = nil;
    NSData *data = responseDictionary ? [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:&serializationError] : nil;
    NSString *responseString = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!responseString)
    {
        NSString *description = @"Failed to encode bound token response.";
        if (!response)
        {
            description = @"Failed to initialize bound token response.";
        }
        else if (!responseDictionary)
        {
            description = @"Failed to create bound token response.";
        }
        else if (!data)
        {
            description = @"Failed to serialize bound token response.";
        }
        NSError *responseError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, description,
                                                 nil, nil, serializationError,
                                                 context.correlationId, nil, YES);
        completionBlock(nil, responseError);
        return;
    }
    completionBlock(responseString, nil);
}

@end
