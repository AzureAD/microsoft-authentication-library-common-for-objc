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

//#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDRequestParameters.h"
#import "MSIDSSOExtensionGetSsoCookiesRequest.h"
#import "MSIDBrokerOperationGetSsoCookiesRequest.h"
#import "MSIDBrokerOperationGetSsoCookiesResponse.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDBrokerNativeAppOperationResponse.h"
#import "MSIDSSOExtensionOperationRequestDelegate.h"

// TODO: This file can be refactored and confined with other Sso Ext request file
@interface MSIDSSOExtensionGetSsoCookiesRequest()

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDGetSsoCookiesRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionOperationRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
 
@end

@implementation MSIDSSOExtensionGetSsoCookiesRequest

- (nullable instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                                             error:(NSError * _Nullable * _Nullable)error
{
    self = [super initWithRequestParameters:requestParameters error:error];
    
    if (self)
    {
        __typeof__(self) __weak weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDBrokerNativeAppOperationResponse *operationResponse, NSError *error)
        {
            NSArray *prtHeaders = nil;
            NSArray *deviceHeaders = nil;
            NSError *resultError = error;
            
            if (!operationResponse.success)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParameters, @"Finished get sso cookies request with error %@", MSID_PII_LOG_MASKABLE(error));
            }
            else if (![operationResponse isKindOfClass:[MSIDBrokerOperationGetSsoCookiesResponse class]])
            {
                resultError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Received incorrect response type for the get sso cookies request", nil, nil, nil, nil, nil, YES);
            }
            else
            {
                MSIDBrokerOperationGetSsoCookiesResponse *response = (MSIDBrokerOperationGetSsoCookiesResponse *)operationResponse;
                prtHeaders = response.prtHeaders;
                deviceHeaders = response.deviceHeaders;
            }
            
            MSIDGetSsoCookiesRequestCompletionBlock completionBlock = weakSelf.requestCompletionBlock;
            weakSelf.requestCompletionBlock = nil;
            
            if (completionBlock) completionBlock(prtHeaders, deviceHeaders, resultError);
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    }
    
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDGetSsoCookiesRequestCompletionBlock)completionBlock
{
    MSIDBrokerOperationGetSsoCookiesRequest *getSsoCookiesRequest = [MSIDBrokerOperationGetSsoCookiesRequest new];
    getSsoCookiesRequest.accountIdentifier = self.requestParameters.accountIdentifier;
    
    __typeof__(self) __weak weakSelf = self;
    [self executeBrokerOperationRequest:getSsoCookiesRequest continueBlock:^{
        weakSelf.requestCompletionBlock = completionBlock;
    } errorBlock:^(NSError *error) {
        completionBlock(nil, nil, error);
    }];
}

@end
