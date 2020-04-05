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

#if MSID_ENABLE_SSO_EXTENSION
#import <AuthenticationServices/AuthenticationServices.h>
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionSilentTokenRequest.h"
#import "MSIDSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDJsonSerializer.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDSSOTokenResponseHandler.h"
#ifdef ENABLE_SPM
#import "IdentityCore_Internal.h"
#endif

@interface MSIDSSOExtensionSilentTokenRequest () <ASAuthorizationControllerDelegate>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) id<MSIDCacheAccessor> tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;
@property (nonatomic, readonly) MSIDSSOTokenResponseHandler *ssoTokenResponseHandler;

@end

@implementation MSIDSSOExtensionSilentTokenRequest

- (instancetype)initWithRequestParameters:(MSIDRequestParameters *)parameters
                             forceRefresh:(BOOL)forceRefresh
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    self = [super initWithRequestParameters:parameters
                               forceRefresh:forceRefresh
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator];
    
    if (self)
    {
        _tokenCache = tokenCache;
        _ssoTokenResponseHandler = [MSIDSSOTokenResponseHandler new];
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __weak typeof(self) weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
        {
#if TARGET_OS_OSX
            weakSelf.ssoTokenResponseHandler.externalCacheSeeder = weakSelf.externalCacheSeeder;
#endif
            [weakSelf.ssoTokenResponseHandler handleOperationResponse:operationResponse
                                                    requestParameters:weakSelf.requestParameters
                                               tokenResponseValidator:weakSelf.tokenResponseValidator
                                                         oauthFactory:weakSelf.oauthFactory
                                                           tokenCache:weakSelf.tokenCache
                                                 accountMetadataCache:weakSelf.accountMetadataCache
                                                      validateAccount:NO
                                                                error:error
                                                      completionBlock:^(MSIDTokenResult *result, NSError *error)
             {
                MSIDRequestCompletionBlock completionBlock = weakSelf.requestCompletionBlock;
                weakSelf.requestCompletionBlock = nil;
                if (completionBlock) completionBlock(result, error);
            }];
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
        _providerType = [[oauthFactory class] providerType];
        _enrollmentIdsCache = [MSIDIntuneEnrollmentIdsCache sharedCache];
        _mamResourcesCache = [MSIDIntuneMAMResourcesCache sharedCache];
        _accountMetadataCache = accountMetadataCache;
    }
    
    return self;
}

#pragma mark - MSIDSilentTokenRequest

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
        
        __auto_type operationRequest = [MSIDBrokerOperationSilentTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                            providerType:self.providerType
                                                                                           enrollmentIds:enrollmentIds
                                                                                            mamResources:mamResources];
        
        NSDictionary *jsonDictionary = [operationRequest jsonDictionary];
        
        if (!jsonDictionary)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to serialize SSO request dictionary for silent token request", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
            completionBlock(nil, error);
            return;
        }
        
        ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
        ssoRequest.requestedOperation = [operationRequest.class operation];
        __auto_type queryItems = [jsonDictionary msidQueryItems];
        ssoRequest.authorizationOptions = queryItems;
        
        self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
        self.authorizationController.delegate = self.extensionDelegate;
        [self.authorizationController performRequests];
        
        self.requestCompletionBlock = completionBlock;
    }];
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
#endif
