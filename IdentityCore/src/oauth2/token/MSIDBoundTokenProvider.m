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
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "MSIDConstants.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthenticationScheme.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConfiguration.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDTokenResponse.h"
#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDBrokerOperationTokenResponse.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#endif

NSString *const MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX = @"[MSIDBoundTokenProvider]";

@implementation MSIDBoundTokenProvider

- (void)acquireBoundTokenWithRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                             context:(nullable id<MSIDRequestContext>)context
                     completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ completionBlock is nil; cannot deliver result.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return;
    }

    if (![self validateRequest:request context:context completionBlock:completionBlock])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ BrowserNativeMessaging Get Token Request is not valid, returning early.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"%@ Servicing GetToken request in-process (no SSO extension). clientId: %@",
                      MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, request.clientId);

    NSError *parametersError = nil;
    MSIDInteractiveTokenRequestParameters *parameters = [self requestParametersFromRequest:request
                                                                                   context:context
                                                                                     error:&parametersError];
    if (!parameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to build request parameters: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(parametersError));
        completionBlock(nil, parametersError);
        return;
    }

    if ([self shouldServiceRequestSilently:request parameters:parameters context:context])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Routing GetToken request to silent path.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        [self acquireTokenSilentlyWithParameters:parameters request:request context:context completionBlock:completionBlock];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Routing GetToken request to interactive path.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        [self acquireTokenInteractivelyWithParameters:parameters request:request context:context completionBlock:completionBlock];
    }
}

#pragma mark - Private

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

#pragma mark - Request transformation

// Converts the browser-native-message GetToken request into the MSIDInteractiveTokenRequestParameters
// used across Common Core for token operations (cache lookup, silent redemption, broker flip).
- (MSIDInteractiveTokenRequestParameters *)requestParametersFromRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                context:(nullable id<MSIDRequestContext>)context
                                                                  error:(NSError *__autoreleasing *)error
{
    MSIDAADAuthority *authority = request.authority;
    if (!authority)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                                     @"An authority is required to acquire a bound token.",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }

    MSIDAuthenticationScheme *authScheme = request.authScheme ?: [MSIDAuthenticationScheme new];
    NSOrderedSet<NSString *> *scopes = [request.scopes msidScopeSet];
    NSUUID *correlationId = context.correlationId ?: [NSUUID UUID];

    NSError *parametersError = nil;
    // TODO: split OIDC scopes (openid/profile/offline_access) from resource scopes once the
    // interactive broker-flip path is wired; the silent redemption path is unaffected.
    MSIDInteractiveTokenRequestParameters *parameters =
    [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:authority
                                                          authScheme:authScheme
                                                         redirectUri:request.redirectUri
                                                            clientId:request.clientId
                                                              scopes:scopes
                                                          oidcScopes:nil
                                                extraScopesToConsent:nil
                                                       correlationId:correlationId
                                                      telemetryApiId:nil
                                                       brokerOptions:nil
                                                         requestType:MSIDRequestBrokeredType
                                                 intuneAppIdentifier:nil
                                                               error:&parametersError];
    if (!parameters)
    {
        if (error)
        {
            *error = parametersError;
        }
        return nil;
    }

    parameters.accountIdentifier = request.accountId;
    parameters.promptType = request.prompt;
    parameters.loginHint = request.loginHint;
    parameters.claimsRequest = request.claimsRequest;
    parameters.isBoundAppRefreshTokenRequested = YES;

    return parameters;
}

#pragma mark - Silent / interactive routing

// Silent servicing is viable when the request does not force UI and a usable token is already
// cached. Token availability is checked the same way Bound App Refresh Tokens are searched.
// Note: token *validity* is authoritative server-side - even with a cached BART, the silent engine
// may return MSIDErrorInteractionRequired (expired BART / device re-registration), at which point
// orchestration falls back to the interactive path.
- (BOOL)shouldServiceRequestSilently:(MSIDBrowserNativeMessageGetTokenRequest *)request
                          parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                             context:(nullable id<MSIDRequestContext>)context
{
    if ([self promptForcesInteraction:request.prompt])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Prompt forces UI; silent path not allowed.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return NO;
    }

    if (!parameters.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ No account identifier on request; silent path not possible.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return NO;
    }

    return [self hasCachedTokenForParameters:parameters context:context];
}

// Prompt types that require user interaction and therefore cannot be serviced silently.
- (BOOL)promptForcesInteraction:(MSIDPromptType)prompt
{
    switch (prompt)
    {
        case MSIDPromptTypeLogin:
        case MSIDPromptTypeConsent:
        case MSIDPromptTypeCreate:
        case MSIDPromptTypeSelectAccount:
        case MSIDPromptTypeRefreshSession:
            return YES;
        default:
            return NO;
    }
}

// Returns YES only when a token usable for silent redemption is cached: a valid access token
// (Scenario 1 cache hit) or a Bound App Refresh Token (BART, Scenario 2). Per the BART SPA design,
// a regular (non-bound) refresh token does NOT qualify - without a cached BART the request must fall
// back to the interactive broker flip (Scenario 3). Token *validity* remains authoritative
// server-side: even with a cached BART the silent engine may return MSIDErrorInteractionRequired
// (expired BART / device re-registration), at which point orchestration falls back to interactive.
- (BOOL)hasCachedTokenForParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            context:(nullable id<MSIDRequestContext>)context
{
    MSIDDefaultTokenCacheAccessor *tokenCache = [self defaultTokenCache:context];
    if (!tokenCache)
    {
        return NO;
    }

    NSError *cacheError = nil;
    MSIDAccessToken *accessToken = [tokenCache getAccessTokenForAccount:parameters.accountIdentifier
                                                         configuration:parameters.msidConfiguration
                                                               context:context
                                                                 error:&cacheError];
    if (accessToken && ![accessToken isExpired])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Found valid cached access token; silent path viable.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return YES;
    }

    // getRefreshTokenWithAccount: prefers a Bound App Refresh Token when one is cached. Only a bound
    // token makes silent redemption viable here; a regular refresh token is intentionally rejected.
    MSIDRefreshToken *refreshToken = [tokenCache getRefreshTokenWithAccount:parameters.accountIdentifier
                                                                  familyId:nil
                                                             configuration:parameters.msidConfiguration
                                                                   context:context
                                                                     error:&cacheError];
    if ([refreshToken isKindOfClass:[MSIDBoundRefreshToken class]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Found cached bound app refresh token; silent path viable.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        return YES;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ No cached bound app refresh token; silent path not viable.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
    return NO;
}

#pragma mark - Silent path

// Drives the existing silent engine (MSIDDefaultSilentTokenRequest), which performs the AT lookup,
// BART lookup, DK-signed JWT redemption against ESTS, and STK-decryption. Orchestration of the
// outcome (success / interaction-required fall-through to interactive / hard failure) is housed here.
- (void)acquireTokenSilentlyWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                   context:(nullable id<MSIDRequestContext>)context
                           completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    MSIDDefaultTokenCacheAccessor *tokenCache = [self defaultTokenCache:context];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [self accountMetadataCache:context];
    if (!tokenCache || !accountMetadataCache)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Token cache unavailable; routing to interactive path.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
        [self acquireTokenInteractivelyWithParameters:parameters request:request context:context completionBlock:completionBlock];
        return;
    }

    MSIDDefaultSilentTokenRequest *silentRequest = [self silentTokenRequestWithParameters:parameters
                                                                               tokenCache:tokenCache
                                                                     accountMetadataCache:accountMetadataCache];

    // Keep the request alive across the async authority resolution + network round-trip.
    __block MSIDDefaultSilentTokenRequest *pendingRequest = silentRequest;
    __weak __typeof(self) weakSelf = self;
    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error) {
        __typeof(self) strongSelf = weakSelf;
        pendingRequest = nil;

        if (result)
        {
            NSError *shapeError = nil;
            NSString *payload = [strongSelf responsePayloadFromResult:result request:request error:&shapeError];
            if (payload)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Silent GetToken request completed.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
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
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Silent path requires user interaction; falling back to interactive path.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
            [strongSelf acquireTokenInteractivelyWithParameters:parameters request:request context:context completionBlock:completionBlock];
            return;
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Silent GetToken request failed: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(error));
        completionBlock(nil, error);
    }];
}

// Factory seam for the silent engine. Extracted so tests can substitute a stub silent request
// (avoiding live authority resolution / network) while production builds the real engine.
- (MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                        tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                                              accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    MSIDAADV2Oauth2Factory *oauthFactory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponseValidator *tokenResponseValidator = [MSIDTokenResponseValidator new];

    return [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                              forceRefresh:NO
                                                              oauthFactory:oauthFactory
                                                    tokenResponseValidator:tokenResponseValidator
                                                                tokenCache:tokenCache
                                                      accountMetadataCache:accountMetadataCache];
}

#pragma mark - Interactive path

// Interactive broker flip (app flip to Authenticator) is not yet implemented. For now a clear
// "interaction required" signal is surfaced so callers can decide how to proceed.
- (void)acquireTokenInteractivelyWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                        request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                        context:(nullable id<MSIDRequestContext>)context
                                completionBlock:(MSIDBoundTokenProviderCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Interactive broker flip is not yet implemented.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                     @"Interactive broker flip is required but not yet implemented in MSIDBoundTokenProvider.",
                                     nil, nil, nil, context.correlationId, nil, NO);
    completionBlock(nil, error);
}

#pragma mark - Response shaping

// Serializes a token result into the browser-native-message GetToken response payload (JSON string).
- (NSString *)responsePayloadFromResult:(MSIDTokenResult *)result
                                request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                  error:(NSError *__autoreleasing *)error
{
    NSDictionary *responseDictionary = [self responseDictionaryFromResult:result request:request];
    if (!responseDictionary)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                     @"Failed to build GetToken response payload.",
                                     nil, nil, nil, result.correlationId, nil, NO);
        }
        return nil;
    }

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseDictionary options:0 error:&serializationError];
    if (!data)
    {
        if (error)
        {
            *error = serializationError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                                           @"Failed to serialize GetToken response payload.",
                                                           nil, nil, nil, result.correlationId, nil, NO);
        }
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)responseDictionaryFromResult:(MSIDTokenResult *)result
                                       request:(MSIDBrowserNativeMessageGetTokenRequest *)request
{
    // Preferred: a fresh server token response (silent redemption) maps to the canonical shape.
    if (result.tokenResponse)
    {
        MSIDBrokerOperationTokenResponse *operationTokenResponse = [[MSIDBrokerOperationTokenResponse alloc] initWithDeviceInfo:nil];
        operationTokenResponse.tokenResponse = result.tokenResponse;
        operationTokenResponse.authority = result.authority;

        MSIDBrowserNativeMessageGetTokenResponse *getTokenResponse =
        [[MSIDBrowserNativeMessageGetTokenResponse alloc] initWithTokenResponse:operationTokenResponse];
        getTokenResponse.state = request.state;
        getTokenResponse.requestAccountUpn = result.account.username ?: request.loginHint;
        return [getTokenResponse jsonDictionary];
    }

    // Cache hit (no fresh server response): shape the payload from the cached result directly.
    return [self responseDictionaryFromCachedResult:result request:request];
}

- (NSDictionary *)responseDictionaryFromCachedResult:(MSIDTokenResult *)result
                                             request:(MSIDBrowserNativeMessageGetTokenRequest *)request
{
    MSIDAccessToken *accessToken = result.accessToken;
    if (!accessToken)
    {
        return nil;
    }

    NSMutableDictionary *response = [NSMutableDictionary new];
    response[@"access_token"] = accessToken.accessToken ?: @"";
    response[@"token_type"] = accessToken.tokenType ?: @"Bearer";
    response[@"id_token"] = result.rawIdToken ?: @"";
    response[@"scope"] = [accessToken.scopes msidToString] ?: @"";

    if (accessToken.expiresOn)
    {
        response[@"expires_on"] = @((long long)[accessToken.expiresOn timeIntervalSince1970]);
        response[@"expires_in"] = @((long long)MAX(0, (NSInteger)[accessToken.expiresOn timeIntervalSinceNow]));
    }

    NSMutableDictionary *account = [NSMutableDictionary new];
    account[@"id"] = result.account.accountIdentifier.homeAccountId;
    account[@"userName"] = result.account.username ?: request.loginHint;
    response[@"account"] = account;
    response[@"state"] = request.state ?: @"";

    return response;
}

#pragma mark - Dependencies

// Builds the default token cache accessor backed by the com.microsoft.adalcache keychain group.
- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(nullable id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:&dataSourceError];
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize keychain token cache: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(dataSourceError));
        return nil;
    }

    MSIDLegacyTokenCacheAccessor *otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    return [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor]];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Bound token provider cache is only supported on iOS.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
    return nil;
#endif
}

- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(nullable id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:nil error:&dataSourceError];
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize account metadata cache: %@", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(dataSourceError));
        return nil;
    }

    return [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Bound token provider cache is only supported on iOS.", MSID_BOUND_TOKEN_PROVIDER_LOG_PREFIX);
    return nil;
#endif
}

@end
