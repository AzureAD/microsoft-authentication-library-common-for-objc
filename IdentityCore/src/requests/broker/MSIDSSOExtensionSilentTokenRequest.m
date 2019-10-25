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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 && !MSID_EXCLUDE_WEBKIT
#import <AuthenticationServices/AuthenticationServices.h>
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionSilentTokenRequest.h"
#import "MSIDSilentTokenRequest+Internal.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDJsonSerializer.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"

@interface MSIDSSOExtensionSilentTokenRequest () <ASAuthorizationControllerDelegate>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) id<MSIDCacheAccessor> tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;

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
        
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __weak typeof(self) weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDTokenResponse *response, NSError *error)
        {
            [weakSelf handleTokenResponse:response error:error completionBlock:weakSelf.requestCompletionBlock];
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    }
    
    return self;
}

#pragma mark - MSIDSilentTokenRequest

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!self.requestParameters.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Account parameter cannot be nil");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMissingAccountParameter, @"Account parameter cannot be nil", nil, nil, nil, self.requestParameters.correlationId, nil);
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
        
        NSError *localError;
        __auto_type operationRequest = [MSIDBrokerOperationSilentTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                                    error:&localError];
        
        if (!operationRequest)
        {
            completionBlock(nil, localError);
            return;
        }
        
        ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
        ssoRequest.requestedOperation = [operationRequest.class operation];
        ssoRequest.authorizationOptions = [[operationRequest jsonDictionary] msidQueryItems];
        
        self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
        self.authorizationController.delegate = self.extensionDelegate;
        [self.authorizationController performRequests];
        
        self.requestCompletionBlock = completionBlock;
    }];
}

- (id<MSIDCacheAccessor>)tokenCache
{
    return self.tokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)metadataCache
{
    return self.accountMetadataCache;
}

@end
#endif
