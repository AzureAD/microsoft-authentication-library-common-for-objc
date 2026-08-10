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
#import "MSIDError.h"
#import "MSIDLogger+Internal.h"
#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "NSError+MSIDExtensions.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#endif

static NSString *const MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX = @"[MSIDLocalSPATokenAcquirer]";

@interface MSIDLocalSPATokenAcquirer ()

@property (nonatomic, copy, nullable) MSIDLocalSPASilentTokenRequestProvider silentTokenRequestProvider;

@end

@implementation MSIDLocalSPATokenAcquirer

- (instancetype)init
{
    return [self initWithSilentTokenRequestProvider:nil];
}

- (instancetype)initWithSilentTokenRequestProvider:(nullable MSIDLocalSPASilentTokenRequestProvider)silentTokenRequestProvider
{
    self = [super init];
    if (self)
    {
        _silentTokenRequestProvider = [silentTokenRequestProvider copy];
    }
    return self;
}

- (nullable MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                                        context:(nullable id<MSIDRequestContext>)context
                                                                          error:(NSError *_Nullable __autoreleasing *_Nullable)error
{
    return [MSIDInteractiveTokenRequestParameters msidParametersWithGetTokenRequest:request
                                                                       requestType:MSIDRequestBrokeredType
                                                     boundAppRefreshTokenRequested:YES
                                                             correlationIdOverride:context.correlationId
                                                                             error:error];
}

- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(nullable id<MSIDRequestContext>)context
                    completionBlock:(MSIDLocalSPATokenAcquirerCompletionBlock)completionBlock
{
    MSIDDefaultSilentTokenRequest *silentRequest = self.silentTokenRequestProvider
        ? self.silentTokenRequestProvider(parameters, context)
        : [self silentTokenRequestWithParameters:parameters context:context];
    if (!silentRequest)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Token cache unavailable; user interaction is required.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                                         @"Token cache is unavailable; user interaction is required.",
                                         nil, nil, nil, context.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }
    silentRequest.requiresBoundRefreshToken = YES;

    [silentRequest executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error) {
        // Keep the request alive until its completion finishes.
        (void)silentRequest;

        if (result)
        {
            MSIDSPATokenAcquisitionResult *outcome = [MSIDSPATokenAcquisitionResult new];
            outcome.tokenResult = result;
            outcome.fallbackRequestAccountUpn = result.account.username ?: request.loginHint;
            completionBlock(outcome, nil);
            return;
        }

        if ([error.domain isEqualToString:MSIDErrorDomain]
            && error.code == MSIDErrorBoundAppRefreshTokenRedemptionError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@ App-specific BART redemption failed; user interaction is required.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
            NSError *interactionRequiredError =
            MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
                            @"App-specific bound refresh token redemption failed; user interaction is required.",
                            error.msidOauthError, error.msidSubError, error, context.correlationId, nil, YES);
            completionBlock(nil, interactionRequiredError);
            return;
        }

        completionBlock(nil, error);
    }];
}

- (nullable MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                                     context:(nullable id<MSIDRequestContext>)context
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:[MSIDKeychainTokenCache defaultKeychainGroup]
                                                                               error:&dataSourceError];
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize the shared ADAL keychain cache: %@", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX, MSID_PII_LOG_MASKABLE(dataSourceError));
        return nil;
    }

    MSIDLegacyTokenCacheAccessor *otherAccessor =
    [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    MSIDDefaultTokenCacheAccessor *tokenCache =
    [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[otherAccessor]];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache =
    [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    if (!tokenCache || !accountMetadataCache)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@ Failed to initialize local SPA token cache accessors.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
        return nil;
    }

    MSIDAADV2Oauth2Factory *oauthFactory = [MSIDAADV2Oauth2Factory new];
    MSIDTokenResponseValidator *tokenResponseValidator = [MSIDTokenResponseValidator new];

    return [[MSIDDefaultSilentTokenRequest alloc] initWithRequestParameters:parameters
                                                              forceRefresh:NO
                                                              oauthFactory:oauthFactory
                                                    tokenResponseValidator:tokenResponseValidator
                                                                tokenCache:tokenCache
                                                      accountMetadataCache:accountMetadataCache];
#else
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"%@ Local SPA token cache is only supported on iOS.", MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX);
    return nil;
#endif
}

@end
