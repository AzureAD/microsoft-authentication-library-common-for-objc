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


#import "MSIDSSOExtensionGetDataBaseRequest.h"
#import "MSIDSSOExtensionGetDataBaseRequest+Internal.h"

@implementation MSIDSSOExtensionGetDataBaseRequest

- (nullable instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                                             error:(NSError * _Nullable * _Nullable)error
{
    if (!requestParameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Unexpected error. Nil request parameter provided", nil, nil, nil, nil, nil, YES);
        }
        
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _requestParameters = requestParameters;
        _extensionDelegate = [MSIDSSOExtensionOperationRequestDelegate new];
        _extensionDelegate.context = requestParameters;
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
    }
    
    return self;
}

- (void)executeBrokerOperationRequest:(MSIDBrokerOperationRequest *)request
                        continueBlock:(MSIDSsoExtenionWrapperContinueBlock)continueBlock
                           errorBlock:(MSIDSsoExtenionWrapperErrorBlock)errorBlock
{
    NSError *error;
    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createSSORequestWithOperationRequest:request
                                                                                          requestParameters:self.requestParameters
                                                                                                 requiresUI:NO
                                                                                                      error:&error];

    if (!ssoRequest)
    {
        errorBlock(error);
        return;
    }

    self.authorizationController = [self controllerWithRequest:ssoRequest];
    self.authorizationController.delegate = self.extensionDelegate;
    [self.authorizationController performRequests];

    continueBlock();
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
