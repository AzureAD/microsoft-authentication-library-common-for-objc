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

#import "MSIDWebMDMEnrollmentCompletionOperation.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#import "MSIDWebviewFactory.h"
#import "MSIDInteractiveTokenRequestParameters.h"

@interface MSIDWebMDMEnrollmentCompletionOperation()

@property (nonatomic) MSIDWebMDMEnrollmentCompletionResponse *response;

@end

@implementation MSIDWebMDMEnrollmentCompletionOperation

+ (void)load
{
    [MSIDWebResponseOperationFactory registerOperationClass:self forResponseClass:MSIDWebMDMEnrollmentCompletionResponse.class];
}

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError *__autoreleasing *)error
{
    self = [super initWithResponse:response error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDWebMDMEnrollmentCompletionResponse.class])
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@ is required for creating %@", MSIDWebMDMEnrollmentCompletionResponse.class, self.class];
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMsg);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMsg, nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        _response = (MSIDWebMDMEnrollmentCompletionResponse *)response;
    }
    
    return self;
}

- (void)invokeWithRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)requestParameters
            webRequestConfiguration:(MSIDAuthorizeWebRequestConfiguration *)webRequestConfiguration
                       oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
  decidePolicyForBrowserActionBlock:(nullable MSIDExternalDecidePolicyForBrowserActionBlock)decidePolicyForBrowserActionBlock
     webviewResponseCompletionBlock:(nonnull MSIDWebviewAuthCompletionHandler)webviewResponseCompletionBlock
   authorizationCodeCompletionBlock:(nonnull MSIDInteractiveAuthorizationCodeCompletionBlock)authorizationCodeCompletionBlock
{
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"SSO extension available, completing web auth with enrollment completion URL");
        if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(self.response, nil);
    }
    else
    {
        // SSO extension not available - load error URL if provided
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"SSO extension not available for enrollment completion");
        
        NSString *errorUrlString = self.response.errorUrl;
        if (errorUrlString && errorUrlString.length > 0)
        {
            // URL decode the errorUrl in case it's percent-encoded
            NSString *decodedErrorUrlString = [errorUrlString stringByRemovingPercentEncoding];
            if (!decodedErrorUrlString)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode error URL, using original value");
                decodedErrorUrlString = errorUrlString;
            }
            
            NSURL *errorURL = [NSURL URLWithString:decodedErrorUrlString];
            if (errorURL)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Loading error URL in webview: %@", errorURL);
                webRequestConfiguration.startURL = [NSURL URLWithString:self.response.errorUrl];
                NSObject<MSIDWebviewInteracting> *webView = [oauthFactory.webviewFactory webViewWithConfiguration:webRequestConfiguration
                                                                                                requestParameters:requestParameters
                                                                             externalDecidePolicyForBrowserAction:decidePolicyForBrowserActionBlock
                                                                                                          context:requestParameters];
                
                if (!webView)
                {
                    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected error. Didn't find any supported web browsers.", nil, nil, nil, nil, nil, YES);
                    if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(nil, error);
                    return;
                }
                
                [MSIDWebviewAuthorization startSessionWithWebView:webView
                                                    oauth2Factory:oauthFactory
                                                    configuration:webRequestConfiguration
                                                          context:requestParameters
                                                completionHandler:webviewResponseCompletionBlock];
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Invalid error URL format: %@", decodedErrorUrlString);
                // No valid error URL - return error action
                NSError *error = MSIDCreateError(MSIDErrorDomain,
                                                MSIDErrorInternal,
                                                @"SSO extension is not available and no valid error URL provided for enrollment completion",
                                                nil, nil, nil, nil, nil, YES);
                if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(nil, error);
            }
        }
    }
}
@end

