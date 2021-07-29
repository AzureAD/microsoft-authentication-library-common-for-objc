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

#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDSSOExtensionPrtHeaderRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDSSOExtensionOperationRequestDelegate.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDBrokerNativeAppOperationResponse.h"
#import "MSIDBrokerOperationGetPrtHeaderWithUIRequest.h"
#import "MSIDBrowserRequestValidator.h"
@interface MSIDSSOExtensionPrtHeaderRequest()

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) NSURL *requestUrl;
@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;
@property (nonatomic) NSUUID *correlationId;
@property (nonatomic) BOOL needsUi;
@property (nonatomic, copy) MSIDSSOExtensionPrtCookiesRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionOperationRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@end

@implementation MSIDSSOExtensionPrtHeaderRequest

- (nullable instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                                        requestUrl:(NSURL *)requestUrl
                                 accountIdentifier:(MSIDAccountIdentifier *)accountIdentifier
                                     correlationId:(NSUUID *)correlationId
                                           needsUi:(BOOL)needsUi
                                             error:(NSError * _Nullable * _Nullable)error
{
    self = [super init];
    
    if (!requestParameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Unexpected error. Nil request parameter provided", nil, nil, nil, nil, nil, YES);
        }
        return nil;
    }
    
    _requestParameters = requestParameters;
    _requestUrl = requestUrl;
    _accountIdentifier = accountIdentifier;
    _correlationId = correlationId;
    _needsUi = needsUi;
    _extensionDelegate = [MSIDSSOExtensionOperationRequestDelegate new];
    _extensionDelegate.context = requestParameters;
    __typeof__(self) __weak weakSelf = self;
    _extensionDelegate.completionBlock = ^(__unused MSIDBrokerNativeAppOperationResponse *operationResponse, __unused NSError *error)
    {
        // TODO response handler
        MSIDSSOExtensionPrtCookiesRequestCompletionBlock completionBlock = weakSelf.requestCompletionBlock;
        weakSelf.requestCompletionBlock = nil;
        
        if (completionBlock) completionBlock(@{}, error);
    };
    
    _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDSSOExtensionPrtCookiesRequestCompletionBlock)completionBlock
{
    NSError *error = nil;
    if (self.needsUi)
    {
        MSIDBrokerOperationGetPrtHeaderWithUIRequest *getPrtheaderRequest = [MSIDBrokerOperationGetPrtHeaderWithUIRequest prtHeaderRequestWithParameters:(MSIDInteractiveTokenRequestParameters *)self.requestParameters
                                                                                                                                              requestUrl:self.requestUrl
                                                                                                                                       accountIdentifier:self.accountIdentifier
                                                                                                                                           correlationId:self.correlationId
                                                                                                                                                   error:&error];
        
        ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createSSORequestWithOperationRequest:getPrtheaderRequest
                                                                                              requestParameters:self.requestParameters
                                                                                                     requiresUI:NO
                                                                                                          error:&error];
        if (!ssoRequest)
        {
            completionBlock(nil, error);
            return;
        }
        
        self.authorizationController = [self controllerWithRequest:ssoRequest];
    }
    
    self.authorizationController.delegate = self.extensionDelegate;
    [self.authorizationController performRequests];
    
    self.requestCompletionBlock = completionBlock;
}

#pragma mark - AuthenticationServices

- (ASAuthorizationController *)controllerWithRequest:(ASAuthorizationSingleSignOnRequest *)ssoRequest
{
    return [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
}

+ (BOOL)canPerformRequest
{
    return [[ASAuthorizationSingleSignOnProvider msidSharedProvider] canPerformAuthorization];
}

@end
