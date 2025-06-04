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
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDInteractiveRequestControlling.h"
#import "ASAuthorizationController+MSIDExtensions.h"

#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif

@interface MSIDSSOExtensionInteractiveTokenRequest () <ASAuthorizationControllerPresentationContextProviding>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDInteractiveRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic) MSIDBrokerOperationInteractiveTokenRequest *operationRequest;

@end

@implementation MSIDSSOExtensionInteractiveTokenRequest

@synthesize requestCompletionBlock, operationRequest;

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
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        _extensionDelegate.completionBlock = [super getCompletionBlock];
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    }

    return self;
}

#pragma mark - MSIDSSORemoteInteractiveTokenRequest

- (void)executeRequestImplWithCompletionBlock:(MSIDInteractiveRequestCompletionBlock)completionBlock
{
    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
    ssoRequest.requestedOperation = [self.operationRequest.class operation];
    [ASAuthorizationSingleSignOnProvider setRequiresUI:YES forRequest:ssoRequest];
    NSDictionary *jsonDictionary = [self.operationRequest jsonDictionary];
    
    if (!jsonDictionary)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to serialize SSO request dictionary for interactive token request", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(nil, error, nil);
        return;
    }
    
    __auto_type queryItems = [jsonDictionary msidQueryItems];
    ssoRequest.authorizationOptions = queryItems;
    
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
    
    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
    self.authorizationController.delegate = self.extensionDelegate;
    self.authorizationController.presentationContextProvider = self;
    self.requestCompletionBlock = completionBlock;
    
    [self.authorizationController msidPerformRequests];
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
    
    __typeof__(self.requestParameters.parentViewController) parentViewController = self.requestParameters.parentViewController;
    return parentViewController ? parentViewController.view.window : self.requestParameters.presentationAnchorWindow;
}

#pragma mark - Dealloc

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
}

@end
#endif
