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
#import "NSString+MSIDExtensions.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDBrokerInvocationOptions.h"
#import "MSIDDefaultTokenRequestProvider.h"
#import "MSIDBrokerConstants.h"
#import "MSIDFlightManager.h"
#import "MSIDDefaultTokenResponseValidator.h"
#endif

static NSString *const MSID_LOCAL_SPA_ACQUIRER_LOG_PREFIX = @"[MSIDLocalSPATokenAcquirer]";

@interface MSIDLocalSPATokenAcquirer ()

@property (nonatomic, copy, nullable) MSIDLocalSPASilentTokenRequestProvider silentTokenRequestProvider;

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (BOOL)validateBoundSPABrokerAvailabilityWithContext:(nullable id<MSIDRequestContext>)context
                                                error:(NSError *__autoreleasing *)error;
- (BOOL)validateInteractivePermissionForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                     parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                        context:(nullable id<MSIDRequestContext>)context
                                          error:(NSError *__autoreleasing *)error;
- (void)configureBoundSPABrokerParameters:(MSIDInteractiveTokenRequestParameters *)parameters;
- (BOOL)validateConfiguredBrokerParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   context:(nullable id<MSIDRequestContext>)context
                                     error:(NSError *__autoreleasing *)error;
- (BOOL)isCallbackSchemeRegistered:(NSString *)callbackScheme;
- (nullable MSIDBrokerInteractiveController *)boundSPABrokerControllerWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                                              context:(nullable id<MSIDRequestContext>)context
                                                                                error:(NSError *__autoreleasing *)error;
#endif

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
    NSURLComponents *origin = [NSURLComponents componentsWithString:request.sender.absoluteString ?: @""];
    NSURLComponents *redirect = [NSURLComponents componentsWithString:request.redirectUri ?: @""];
    BOOL valid = request && [origin.scheme.lowercaseString isEqualToString:@"https"]
        && origin.host.length && !origin.user && !origin.password && !origin.query && !origin.fragment
        && (!origin.path.length || [origin.path isEqualToString:@"/"])
        && [redirect.scheme.lowercaseString isEqualToString:@"https"]
        && [origin.host.lowercaseString isEqualToString:redirect.host.lowercaseString]
        && [(origin.port ?: @443) isEqual:(redirect.port ?: @443)]
        && !redirect.user && !redirect.password && !redirect.fragment;
    for (id rawKey in request.extraParameters)
    {
        NSString *key = [rawKey isKindOfClass:NSString.class] ? [rawKey lowercaseString] : nil;
        if (!key || [key hasPrefix:@"bound_"] || [key hasPrefix:@"brk_"] || [key hasPrefix:@"broker_"]
            || [@[@"child_client_id", @"child_redirect_uri", @"client_id", @"redirect_uri",
                   @"sdk_broker_capabilities", @"grant_type", @"refresh_token", @"req_cnf",
                   @"request_nonce", @"auth_scheme", @"token_type"] containsObject:key])
        {
            valid = NO;
        }
    }
    if (!valid)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter,
                           @"Bound-SPA requires a trusted HTTPS origin, same-origin redirect, and no protocol overrides.",
                           context.correlationId);
        return nil;
    }
    MSIDInteractiveTokenRequestParameters *parameters = [MSIDInteractiveTokenRequestParameters msidParametersWithGetTokenRequest:request
                                                                       requestType:MSIDRequestBrokeredType
                                                     boundAppRefreshTokenRequested:YES
                                                             correlationIdOverride:context.correlationId
                                                                             error:error];
    parameters.requiresBoundSPACachePublication = YES;
    parameters.ignoreScopeValidation = NO;
    return parameters;
}

- (void)acquireSilentWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                            request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                            context:(nullable id<MSIDRequestContext>)context
                    completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    NSError *cacheError = nil;
    MSIDDefaultSilentTokenRequest *silentRequest = self.silentTokenRequestProvider
        ? self.silentTokenRequestProvider(parameters, context)
        : [self silentTokenRequestWithParameters:parameters context:context error:&cacheError];
    if (!silentRequest)
    {
        NSError *error = cacheError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                         @"The shared token cache could not be initialized.",
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
            NSString *username = result.account.username;
            outcome.fallbackRequestAccountUpn = [NSString msidIsStringNilOrBlank:username] ? request.loginHint : username;
            completionBlock(outcome, nil);
            return;
        }

        if ([error.domain isEqualToString:MSIDErrorDomain] && error.code == MSIDErrorBoundAppRefreshTokenRedemptionError)
        {
            completionBlock(nil, error.userInfo[NSUnderlyingErrorKey] ?: error);
            return;
        }

        completionBlock(nil, error);
    }];
}

- (void)acquireInteractiveWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                request:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                context:(nullable id<MSIDRequestContext>)context
                        completionBlock:(MSIDSPATokenAcquirerCompletionBlock)completionBlock
{
    NSError *error = nil;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    if (![self validateBoundSPABrokerAvailabilityWithContext:context error:&error]
        || ![self validateInteractivePermissionForRequest:request
                                               parameters:parameters
                                                  context:context
                                                    error:&error])
    {
        completionBlock(nil, error);
        return;
    }

    [self configureBoundSPABrokerParameters:parameters];
    if (![self validateConfiguredBrokerParameters:parameters context:context error:&error])
    {
        completionBlock(nil, error);
        return;
    }

    MSIDBrokerInteractiveController *controller =
        [self boundSPABrokerControllerWithParameters:parameters context:context error:&error];
    if (!controller)
    {
        completionBlock(nil, error);
        return;
    }

    controller.sdkBrokerCapabilities = @[MSID_BROKER_SDK_BOUND_SPA_V1_CAPABILITY];
    [controller acquireToken:^(MSIDTokenResult *result, NSError *acquisitionError)
    {
        // Retain through startup/authority discovery as well as the app switch.
        (void)controller;
        MSIDSPATokenAcquisitionResult *outcome = nil;
        if (result)
        {
            outcome = [MSIDSPATokenAcquisitionResult new];
            outcome.tokenResult = result;
            outcome.fallbackRequestAccountUpn = result.account.username ?: request.loginHint;
        }
        completionBlock(outcome, acquisitionError);
    }];
#else
    error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerNotAvailable,
                           @"Bound-SPA Broker acquisition is supported only on iOS.", nil, nil, nil, context.correlationId, nil, NO);
    completionBlock(nil, error);
#endif
}

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (BOOL)validateBoundSPABrokerAvailabilityWithContext:(nullable id<MSIDRequestContext>)context
                                                error:(NSError *__autoreleasing *)error
{
    BOOL enabled =
        [[MSIDFlightManager sharedInstance] boolForKey:MSID_FLIGHT_ENABLE_BOUND_SPA_BROKER];
    NSError *supportError = nil;
    BOOL supported = enabled && [MSIDBrokerKeyProvider hasBoundSPASupportWithError:&supportError];

    if (!supported && error)
    {
        *error = supportError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerNotAvailable,
            @"Bound-SPA Broker support has not been advertised.", nil, nil, nil,
            context.correlationId, nil, NO);
    }

    return supported;
}

- (BOOL)validateInteractivePermissionForRequest:(MSIDBrowserNativeMessageGetTokenRequest *)request
                                     parameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                        context:(nullable id<MSIDRequestContext>)context
                                          error:(NSError *__autoreleasing *)error
{
    BOOL permitted = parameters.promptType != MSIDPromptTypeNever && request.canShowUI;
    if (!permitted && error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired,
            @"Interactive acquisition is not permitted.", nil, nil, nil,
            context.correlationId, nil, NO);
    }

    return permitted;
}

- (void)configureBoundSPABrokerParameters:(MSIDInteractiveTokenRequestParameters *)parameters
{
    parameters.boundSPABrokerProtocolVersion = MSID_BROKER_BOUND_SPA_PROTOCOL_VERSION_1;
    parameters.requiresBoundSPACachePublication = YES;
    parameters.keychainAccessGroup = @"com.microsoft.adalcache";
    parameters.brokerInvocationOptions = [[MSIDBrokerInvocationOptions alloc]
        initWithRequiredBrokerType:MSIDRequiredBrokerTypeWithNonceSupport
                     protocolType:MSIDBrokerProtocolTypeCustomScheme
                aadRequestVersion:MSIDBrokerAADRequestVersionV2];

    // The native host owns the callback; browser input cannot replace it.
    parameters.nestedAuthBrokerRedirectUri =
        [NSString stringWithFormat:@"msauth.%@://auth", NSBundle.mainBundle.bundleIdentifier];
}

- (BOOL)validateConfiguredBrokerParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                   context:(nullable id<MSIDRequestContext>)context
                                     error:(NSError *__autoreleasing *)error
{
    NSString *callbackScheme = [NSURL URLWithString:parameters.nestedAuthBrokerRedirectUri].scheme;
    if (![self isCallbackSchemeRegistered:callbackScheme])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter,
                @"The native host callback is not registered in CFBundleURLTypes.",
                nil, nil, nil, context.correlationId, nil, NO);
        }
        return NO;
    }

    if (![MSIDBrokerInteractiveController canPerformRequest:parameters])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerNotAvailable,
                @"The required Broker is not installed.", nil, nil, nil,
                context.correlationId, nil, NO);
        }
        return NO;
    }

    return YES;
}

- (BOOL)isCallbackSchemeRegistered:(NSString *)callbackScheme
{
    if ([NSString msidIsStringNilOrBlank:callbackScheme])
    {
        return NO;
    }

    for (NSDictionary *urlType in [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"])
    {
        if ([urlType[@"CFBundleURLSchemes"] containsObject:callbackScheme])
        {
            return YES;
        }
    }

    return NO;
}

- (nullable MSIDBrokerInteractiveController *)boundSPABrokerControllerWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                                              context:(nullable id<MSIDRequestContext>)context
                                                                                error:(NSError *__autoreleasing *)error
{
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource =
    [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:&dataSourceError];
    if (!dataSource)
    {
        if (error)
        {
            *error = dataSourceError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                @"Unable to initialize the bound-SPA shared cache.", nil, nil, nil,
                context.correlationId, nil, NO);
        }
        return nil;
    }

    MSIDDefaultTokenCacheAccessor *accessor =
    [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    MSIDAccountMetadataCacheAccessor *metadata =
    [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    MSIDDefaultTokenRequestProvider *provider = [[MSIDDefaultTokenRequestProvider alloc]
        initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
             defaultAccessor:accessor
     accountMetadataAccessor:metadata
      tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    NSError *controllerError = nil;
    MSIDBrokerInteractiveController *controller = [[MSIDBrokerInteractiveController alloc]
        initWithInteractiveRequestParameters:parameters
                        tokenRequestProvider:provider
                          fallbackController:nil
                                       error:&controllerError];
    if (!controller && error)
    {
        *error = controllerError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
            @"Unable to initialize the bound-SPA Broker controller.", nil, nil, nil,
            context.correlationId, nil, NO);
    }

    return controller;
}
#endif

- (nullable MSIDDefaultSilentTokenRequest *)silentTokenRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                                                     context:(nullable id<MSIDRequestContext>)context
                                                                       error:(NSError * __autoreleasing *)error
{
#if TARGET_OS_IPHONE
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache"
                                                                               error:&dataSourceError];
    if (!dataSource)
    {
        if (error)
        {
            *error = dataSourceError;
        }
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
