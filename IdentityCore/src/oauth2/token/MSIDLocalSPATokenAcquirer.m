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

#import "MSIDLocalSPATokenAcquirer.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSIDInteractiveTokenRequestParameters+BrowserNativeMessageGetToken.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDConstants.h"
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#endif

static NSString *const MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX = @"[MSIDLocalSPATokenAcquirer]";

@interface MSIDLocalSPATokenAcquirer ()

@property (nonatomic, copy, nullable) MSIDLocalSPATokenCacheProvider tokenCacheProvider;
@property (nonatomic, copy, nullable) MSIDLocalSPAAccountMetadataCacheProvider accountMetadataCacheProvider;
@property (nonatomic, copy, nullable) MSIDLocalSPASilentTokenRequestProvider silentTokenRequestProvider;

@end

@implementation MSIDLocalSPATokenAcquirer

- (instancetype)init
{
    return [self initWithTokenCacheProvider:nil
               accountMetadataCacheProvider:nil
                 silentTokenRequestProvider:nil];
}

- (instancetype)initWithTokenCacheProvider:(MSIDLocalSPATokenCacheProvider)tokenCacheProvider
              accountMetadataCacheProvider:(MSIDLocalSPAAccountMetadataCacheProvider)accountMetadataCacheProvider
                silentTokenRequestProvider:(MSIDLocalSPASilentTokenRequestProvider)silentTokenRequestProvider
{
    self = [super init];
    if (self)
    {
        _tokenCacheProvider = [tokenCacheProvider copy];
        _accountMetadataCacheProvider = [accountMetadataCacheProvider copy];
        _silentTokenRequestProvider = [silentTokenRequestProvider copy];
    }
    return self;
}

#pragma mark - MSIDSPATokenAcquiring

- (MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                               context:(id<MSIDRequestContext>)context
                                                                 error:(NSError *__autoreleasing *)error
{
    // Local-app bound flow: brokered request type + BART requested.
    return [MSIDInteractiveTokenRequestParameters msidParametersWithGetTokenRequest:request
                                                                       requestType:MSIDRequestBrokeredType
                                                     boundAppRefreshTokenRequested:YES
                                                             correlationIdOverride:context.correlationId
                                                                             error:error];
}

- (MSIDSPAPreRouteDecision *)preRouteDecisionForParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                                   request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                                   context:(__unused id<MSIDRequestContext>)context
{
    // No PRT / signed-out / default-account concepts on the local path.
    return [MSIDSPAPreRouteDecision new];
}

- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    MSIDDefaultTokenCacheAccessor *tokenCache = self.tokenCacheProvider ? self.tokenCacheProvider(context) : [self defaultTokenCache:context];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache = self.accountMetadataCacheProvider ? self.accountMetadataCacheProvider(context) : [self accountMetadataCache:context];
    if (!tokenCache || !accountMetadataCache)
    {
        // Preserve prior behavior: an unavailable cache surfaces interaction-required so the
        // provider runs its interactive fallback / UI-blocked handling.
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Token cache unavailable; user interaction is required.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                         @"Token cache is unavailable; user interaction is required.",
                                         nil, nil, nil, context.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    MSIDDefaultSilentTokenRequest *silentRequest = self.silentTokenRequestProvider
        ? self.silentTokenRequestProvider(parameters, tokenCache, accountMetadataCache)
        : [self silentTokenRequestWithParameters:parameters tokenCache:tokenCache accountMetadataCache:accountMetadataCache];
    silentRequest.requiresBoundRefreshToken = YES;

    // Keep the request alive across async authority resolution + network round-trip.
    __block MSIDDefaultSilentTokenRequest *pendingRequest = silentRequest;
    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error) {
        pendingRequest = nil;

        if (result)
        {
            MSIDSPATokenAcquisitionResult *outcome = [MSIDSPATokenAcquisitionResult new];
            outcome.tokenResult = result;
            outcome.fallbackRequestAccountUpn = result.account.username ?: request.loginHint;
            completionBlock(outcome, nil);
            return;
        }

        completionBlock(nil, error);
    }];
}

- (void)acquireInteractiveWithParameters:(__unused MSIDInteractiveTokenRequestParameters *)parameters
                                request:(__unused MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    // A real local interactive request (MSIDInteractiveTokenRequest) replaces this stub in a
    // follow-up. For now a clear interaction-required signal is surfaced.
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ Local interactive acquisition is not yet implemented.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                     @"Local interactive acquisition is required but not yet implemented.",
                                     nil, nil, nil, context.correlationId, nil, NO);
    completionBlock(nil, error);
}

#pragma mark - Silent engine (production default)

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

#pragma mark - Dependencies (production default)

// Builds the default token cache accessor backed by the com.microsoft.adalcache keychain group.
- (MSIDDefaultTokenCacheAccessor *)defaultTokenCache:(id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:[MSIDKeychainTokenCache defaultKeychainGroup] error:&dataSourceError];
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize keychain token cache: %@", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(dataSourceError));
        return nil;
    }

    MSIDLegacyTokenCacheAccessor *otherAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    return [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor]];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Local SPA token cache is only supported on iOS.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
    return nil;
#endif
}

- (MSIDAccountMetadataCacheAccessor *)accountMetadataCache:(id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:[MSIDKeychainTokenCache defaultKeychainGroup] error:&dataSourceError];
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize account metadata cache: %@", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(dataSourceError));
        return nil;
    }

    return [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Local SPA account metadata cache is only supported on iOS.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
    return nil;
#endif
}

@end
