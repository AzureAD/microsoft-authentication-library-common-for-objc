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

#import "MSIDSSOExtensionGetDefaultAccountRequest.h"
#import "MSIDBrokerOperationGetDefaultAccountRequest.h"
#import "MSIDBrokerOperationGetDefaultAccountResponse.h"
#import "MSIDRequestParameters.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDSSOExtensionOperationRequestDelegate.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDConstants.h"
#if !EXCLUDE_FROM_MSALCPP
#import "MSIDLastRequestTelemetry.h"
#endif

@interface MSIDSSOExtensionGetDefaultAccountRequest()

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDGetDefaultAccountRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionOperationRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) NSDate *requestSentDate;
#if !EXCLUDE_FROM_MSALCPP
@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;
#endif

@end

@implementation MSIDSSOExtensionGetDefaultAccountRequest

- (nullable instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                                             error:(NSError * _Nullable __autoreleasing * _Nullable)error
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
    
    if (self)
    {
        _requestParameters = requestParameters;
        
        _extensionDelegate = [MSIDSSOExtensionOperationRequestDelegate new];
        _extensionDelegate.context = requestParameters;
        __typeof__(self) __weak weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDBrokerNativeAppOperationResponse *operationResponse, NSError *resultError)
        {
            MSIDDefaultAccount *resultDefaultAccount = nil;
            
            if (!operationResponse.success)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParameters, @"Finished reading default account with error %@", MSID_PII_LOG_MASKABLE(resultError));
            }
            else if (![operationResponse isKindOfClass:[MSIDBrokerOperationGetDefaultAccountResponse class]])
            {
                resultError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Received incorrect response type for the get default account request", nil, nil, nil, nil, nil, YES);
            }
            else
            {
                MSIDBrokerOperationGetDefaultAccountResponse *response = (MSIDBrokerOperationGetDefaultAccountResponse *)operationResponse;
                resultDefaultAccount = response.defaultAccount;
            }
            
            __typeof__(self) strongSelf = weakSelf;
            
            MSIDGetDefaultAccountRequestCompletionBlock completionBlock = strongSelf.requestCompletionBlock;
            strongSelf.requestCompletionBlock = nil;
            
            if (completionBlock) completionBlock(resultDefaultAccount, resultError);
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
#if !EXCLUDE_FROM_MSALCPP
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
#endif
    }
    
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDGetDefaultAccountRequestCompletionBlock)completionBlock
{
    MSIDBrokerOperationGetDefaultAccountRequest *getDefaultAccountRequest = [MSIDBrokerOperationGetDefaultAccountRequest new];
    
    getDefaultAccountRequest.authority = _requestParameters.authority;
    
    NSError *error;
    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createSSORequestWithOperationRequest:getDefaultAccountRequest
                                                                                          requestParameters:self.requestParameters
                                                                                                 requiresUI:NO
                                                                                                      error:&error];
    
    if (!ssoRequest)
    {
        completionBlock(nil, error);
        return;
    }
        
    self.authorizationController = [self controllerWithRequest:ssoRequest];
    self.authorizationController.delegate = self.extensionDelegate;
    self.requestSentDate = [NSDate date];

    self.requestCompletionBlock = completionBlock;
    [self.authorizationController msidPerformRequests];
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

#endif
