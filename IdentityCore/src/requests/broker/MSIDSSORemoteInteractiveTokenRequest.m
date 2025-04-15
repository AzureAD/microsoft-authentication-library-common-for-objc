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

#import "MSIDSSORemoteInteractiveTokenRequest.h"
#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDJsonSerializer.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDSSOTokenResponseHandler.h"
#import "MSIDLogger+Internal.h"
#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif

@interface MSIDSSORemoteInteractiveTokenRequest()

@property (nonatomic, copy) MSIDInteractiveRequestCompletionBlock requestCompletionBlock;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;
@property (nonatomic, readonly) MSIDSSOTokenResponseHandler *ssoTokenResponseHandler;
@property (nonatomic) MSIDBrokerOperationInteractiveTokenRequest *operationRequest;
@property (nonatomic) NSDate *requestSentDate;

@end

@implementation MSIDSSORemoteInteractiveTokenRequest

- (instancetype)initWithRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       extendedTokenCache:(id<MSIDExtendedTokenCacheDataSource>)extendedTokenCache
{
    self = [super initWithRequestParameters:parameters
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                       accountMetadataCache:accountMetadataCache
                         extendedTokenCache:extendedTokenCache];

    if (self)
    {
        _ssoTokenResponseHandler = [MSIDSSOTokenResponseHandler new];
        _providerType = [oauthFactory.class providerType];
        _enrollmentIdsCache = [MSIDIntuneEnrollmentIdsCache sharedCache];
        _mamResourcesCache = [MSIDIntuneMAMResourcesCache sharedCache];
    }

    return self;
}

#pragma mark - MSIDInteractiveTokenRequest

- (void)executeRequestWithCompletion:(MSIDInteractiveRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive broker flow.");
    
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End interactive broker flow.");
        return;
    }
    
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.requestParameters.loginHint;
    
    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(__unused NSURL *openIdConfigurationEndpoint, __unused BOOL validated, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error, nil);
             return;
         }
        
        NSDictionary *enrollmentIds = [self.enrollmentIdsCache enrollmentIdsJsonDictionaryWithContext:self.requestParameters
                                                                                                error:nil];
        NSDictionary *mamResources = [self.mamResourcesCache resourcesJsonDictionaryWithContext:self.requestParameters
                                                                                          error:nil];
        
        self.requestSentDate = [NSDate date];
        self.operationRequest = [MSIDBrokerOperationInteractiveTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                                 providerType:self.providerType
                                                                                                enrollmentIds:enrollmentIds
                                                                                                 mamResources:mamResources
                                                                                              requestSentDate:self.requestSentDate];
        [self executeRequestImplWithCompletionBlock:completionBlock];
     }];
}

- (void)executeRequestImplWithCompletionBlock:(MSIDInteractiveRequestCompletionBlock)completionBlock
{
    NSAssert(NO, @"Abstract method.");
}

- (MSIDSSOExtensionRequestDelegateCompletionBlock)getCompletionBlock
{
    return ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
    {
#if TARGET_OS_IPHONE
        [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
        
#if TARGET_OS_OSX && !EXCLUDE_FROM_MSALCPP
        self.ssoTokenResponseHandler.externalCacheSeeder = self.externalCacheSeeder;
#endif
        [self.ssoTokenResponseHandler handleOperationResponse:operationResponse
                                                  requestParameters:self.requestParameters
                                             tokenResponseValidator:self.tokenResponseValidator
                                                       oauthFactory:self.oauthFactory
                                                         tokenCache:self.tokenCache
                                               accountMetadataCache:self.accountMetadataCache
                                                    validateAccount:self.requestParameters.shouldValidateResultAccount
                                                              error:error
                                                    completionBlock:^(MSIDTokenResult *result, NSError *localError)
         {
            MSIDInteractiveRequestCompletionBlock completionBlock = self.requestCompletionBlock;
            self.requestCompletionBlock = nil;
            if (completionBlock) completionBlock(result, localError, nil);
        }];
    };
}

@end
