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

#import "MSIDSSORemoteSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDJsonSerializer.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDSSOTokenResponseHandler.h"
#import "MSIDThrottlingService.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#if !EXCLUDE_FROM_MSALCPP
#import "MSIDLastRequestTelemetry.h"
#endif

@interface MSIDSSORemoteSilentTokenRequest ()

@property (nonatomic) id<MSIDCacheAccessor> tokenCache;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;
@property (nonatomic, readonly) MSIDSSOTokenResponseHandler *ssoTokenResponseHandler;
@property (nonatomic) MSIDBrokerOperationSilentTokenRequest *operationRequest;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic) NSDate *requestSentDate;

@end

@implementation MSIDSSORemoteSilentTokenRequest

- (instancetype)initWithRequestParameters:(MSIDRequestParameters *)parameters
                             forceRefresh:(BOOL)forceRefresh
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       extendedTokenCache:(nullable id<MSIDExtendedTokenCacheDataSource>)extendedTokenCache
{
    self = [super initWithRequestParameters:parameters
                               forceRefresh:forceRefresh
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator];
    
    if (self)
    {
        _tokenCache = tokenCache;
        _ssoTokenResponseHandler = [MSIDSSOTokenResponseHandler new];
        _providerType = [[oauthFactory class] providerType];
        _enrollmentIdsCache = [MSIDIntuneEnrollmentIdsCache sharedCache];
        _mamResourcesCache = [MSIDIntuneMAMResourcesCache sharedCache];
        _accountMetadataCache = accountMetadataCache;

        self.throttlingService = [[MSIDThrottlingService alloc] initWithDataSource:extendedTokenCache context:parameters];

    }
    
    return self;
}

- (MSIDSSOExtensionRequestDelegateCompletionBlock)getCompletionBlock
{
    return ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
            {
#if TARGET_OS_OSX && !EXCLUDE_FROM_MSALCPP
                self.ssoTokenResponseHandler.externalCacheSeeder = self.externalCacheSeeder;
#endif      
                [self.ssoTokenResponseHandler handleOperationResponse:operationResponse
                                                          requestParameters:self.requestParameters
                                                     tokenResponseValidator:self.tokenResponseValidator
                                                               oauthFactory:self.oauthFactory
                                                                 tokenCache:self.tokenCache
                                                       accountMetadataCache:self.accountMetadataCache
                                                            validateAccount:NO
                                                                      error:error
                                                            completionBlock:^(MSIDTokenResult *result, NSError *localError)
                 {
                    MSIDRequestCompletionBlock completionBlock = self.requestCompletionBlock;
                    self.requestCompletionBlock = nil;
                    if (localError)
                    {
                        /**
                         * If SSO-EXT responses error, we should update throttling db
                         */
                        if ([MSIDThrottlingService isThrottlingEnabled])
                        {
                            [self.throttlingService updateThrottlingService:localError tokenRequest:self.operationRequest];
                        }
                    }
                    if (completionBlock) completionBlock(result, localError);
                }];
            };
}

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!self.requestParameters.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Account parameter cannot be nil");

        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMissingAccountParameter, @"Account parameter cannot be nil", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    NSString *upn = self.requestParameters.accountIdentifier.displayableId;

    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                                           __unused BOOL validated, NSError *error)
     {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }

        NSDictionary *enrollmentIds = [self.enrollmentIdsCache enrollmentIdsJsonDictionaryWithContext:self.requestParameters
                                                                                                error:nil];

        NSDictionary *mamResources = [self.mamResourcesCache resourcesJsonDictionaryWithContext:self.requestParameters
                                                                                          error:nil];
        self.requestSentDate = [NSDate date];
        self.operationRequest = [MSIDBrokerOperationSilentTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                            providerType:self.providerType
                                                                                           enrollmentIds:enrollmentIds
                                                                                            mamResources:mamResources
                                                                                  requestSentDate:self.requestSentDate];
        if (![MSIDThrottlingService isThrottlingEnabled])
        {
            [self executeRequestImplWithCompletionBlock:completionBlock];
        }
        else
        {
            [self.throttlingService shouldThrottleRequest:self.operationRequest resultBlock:^(BOOL shouldBeThrottled, NSError * _Nullable cachedError)
             {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Throttle decision: %@" , (shouldBeThrottled ? @"YES" : @"NO"));

                if (cachedError)
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"Throttling return error: %@ ", MSID_PII_LOG_MASKABLE(cachedError));
                }

                if (shouldBeThrottled && cachedError)
                {
                    completionBlock(nil,cachedError);
                    return;
                }

                [self executeRequestImplWithCompletionBlock:completionBlock];
            }];
        }

    }];
}

- (void)executeRequestImplWithCompletionBlock:(MSIDRequestCompletionBlock _Nonnull)completionBlock
{
    NSAssert(NO, @"Abstract method.");
}

- (id<MSIDCacheAccessor>)tokenCache
{
    return _tokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)metadataCache
{
    return self.accountMetadataCache;
}

@end
