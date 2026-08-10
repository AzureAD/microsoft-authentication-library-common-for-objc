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

@property (nonatomic, copy, nullable) MSIDLocalSPASilentTokenRequestProvider silentTokenRequestProvider;

@end

@implementation MSIDSPATokenAcquisitionResult

@end

@implementation MSIDLocalSPATokenAcquirer

- (instancetype)init
{
    return [self initWithSilentTokenRequestProvider:nil];
}

- (instancetype)initWithSilentTokenRequestProvider:(MSIDLocalSPASilentTokenRequestProvider)silentTokenRequestProvider
{
    self = [super init];
    if (self)
    {
        _silentTokenRequestProvider = [silentTokenRequestProvider copy];
    }
    return self;
}

#pragma mark - MSIDSPATokenAcquiring

- (MSIDInteractiveTokenRequestParameters *)requestParametersForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                                               context:(id<MSIDRequestContext>)context
                                                                 error:(NSError *__autoreleasing *)error
{
    return [MSIDInteractiveTokenRequestParameters msidParametersWithGetTokenRequest:request
                                                                       requestType:MSIDRequestBrokeredType
                                                     boundAppRefreshTokenRequested:YES
                                                             correlationIdOverride:context.correlationId
                                                                             error:error];
}

- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
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

    // Retain the request until its asynchronous completion runs.
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

- (MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                           context:(id<MSIDRequestContext>)context
{
    MSIDDefaultTokenCacheAccessor *tokenCache = [self defaultTokenCache:context];
    MSIDAccountMetadataCacheAccessor *accountMetadataCache = [self accountMetadataCache:context];
    if (!tokenCache || !accountMetadataCache)
    {
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
}

#pragma mark - Dependencies

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
