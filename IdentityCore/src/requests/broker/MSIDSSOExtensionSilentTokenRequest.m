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
#import "MSIDRequestParameters.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDGCDStarvationDetector.h"
#import "MSIDLogger+Internal.h"

@interface MSIDSSOExtensionSilentTokenRequest () <ASAuthorizationControllerDelegate>

@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDBrokerOperationSilentTokenRequest *operationRequest;
@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic) MSIDGCDStarvationDetector *threadMonitoring;
@property (nonatomic) NSTimeInterval GCDStarvedDuration;

@end

@implementation MSIDSSOExtensionSilentTokenRequest

@synthesize requestCompletionBlock, operationRequest;

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
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                       accountMetadataCache:accountMetadataCache
                         extendedTokenCache:extendedTokenCache];
    if (self)
    {
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __weak typeof(self) weakSelf = self;
        _extensionDelegate.completionBlock = ^(_Nullable id response, NSError  * _Nullable error) {
            [weakSelf.threadMonitoring stopMonitoring];
            MSIDSSOExtensionRequestDelegateCompletionBlock completionBlock = [super getCompletionBlock];
            if (completionBlock) completionBlock(response, error);
        };
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
        _threadMonitoring = [MSIDGCDStarvationDetector new];
    }

    return self;
}

- (void)executeRequestImplWithCompletionBlock:(MSIDRequestCompletionBlock _Nonnull)completionBlock
{
    NSDictionary *jsonDictionary = [self.operationRequest jsonDictionary];

    if (!jsonDictionary)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to serialize SSO request dictionary for silent token request", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
    ssoRequest.requestedOperation = [self.operationRequest.class operation];
    __auto_type queryItems = [jsonDictionary msidQueryItems];
    ssoRequest.authorizationOptions = queryItems;
    [ASAuthorizationSingleSignOnProvider setRequiresUI:NO forRequest:ssoRequest];

    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
    self.authorizationController.delegate = self.extensionDelegate;
    
    self.requestCompletionBlock = completionBlock;
    [self.authorizationController msidPerformRequests];
    __weak typeof(self) weakSelf = self;
    [self.threadMonitoring startMonitoringWithInterval:1.0
                                  timeout:0.01
                                onStarved:^{
        weakSelf.GCDStarvedDuration += 1100;
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"GCD may be starved");
    }];
}

@end
#endif
