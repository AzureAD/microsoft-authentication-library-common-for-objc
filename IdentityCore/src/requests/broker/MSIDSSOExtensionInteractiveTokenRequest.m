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
#import "MSIDSSOExtensionInteractiveTokenRequest.h"
#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDJsonSerializer.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"

@interface MSIDSSOExtensionInteractiveTokenRequest () <ASAuthorizationControllerPresentationContextProviding>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDInteractiveRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;

@end

@implementation MSIDSSOExtensionInteractiveTokenRequest

- (instancetype)initWithRequestParameters:(MSIDInteractiveRequestParameters *)parameters
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    self = [super initWithRequestParameters:parameters
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                       accountMetadataCache:accountMetadataCache];

    if (self)
    {
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __weak typeof(self) weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
        {
            if (operationResponse.authority) weakSelf.requestParameters.cloudAuthority = operationResponse.authority;
            
            [weakSelf handleTokenResponse:operationResponse.tokenResponse error:error completionBlock:weakSelf.requestCompletionBlock];
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End silent broker flow.");
        return;
    }
    
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.requestParameters.loginHint;
    
    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                           userPrincipalName:upn
                                                     context:self.requestParameters
                                             completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                                               __unused BOOL validated, NSError *error)
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
        
        NSError *localError;
        __auto_type operationRequest = [MSIDBrokerOperationInteractiveTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                                 providerType:self.providerType
                                                                                                enrollmentIds:enrollmentIds
                                                                                                 mamResources:mamResources
                                                                                                        error:&localError];
        
        if (!operationRequest)
        {
            completionBlock(nil, localError, nil);
            return;
        }
        
        // TODO: fix
        
        operationRequest.instanceAware = YES;
        
        ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
        ssoRequest.requestedOperation = [operationRequest.class operation];
        __auto_type queryItems = [[operationRequest jsonDictionary] msidQueryItems];
        ssoRequest.authorizationOptions = queryItems;
        
        self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
        self.authorizationController.delegate = self.extensionDelegate;
        self.authorizationController.presentationContextProvider = self;
        [self.authorizationController performRequests];
        
        self.requestCompletionBlock = completionBlock;
     }];
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(__unused ASAuthorizationController *)controller
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    return self.requestParameters.parentViewController.view.window;
}

@end
#endif
