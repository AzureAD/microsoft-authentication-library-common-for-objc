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


#import "MSIDSwtichBrowserResumeOperation.h"
#import "MSIDSwitchBrowserResumeResponse.h"
#import "MSIDWebviewFactory.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDWebResponseOperationFactory.h"

@interface MSIDSwtichBrowserResumeOperation()

@property (nonatomic) MSIDSwitchBrowserResumeResponse *switchBrowserResumeResponse;

@end


@implementation MSIDSwtichBrowserResumeOperation

+ (void)load
{
    [MSIDWebResponseOperationFactory registerOperationClass:self forResponseClass:MSIDSwitchBrowserResumeResponse.class];
}

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError *__autoreleasing *)error
{
    self = [super initWithResponse:response error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDSwitchBrowserResumeResponse.class])
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@ is required for creating %@", MSIDSwitchBrowserResumeResponse.class, self.class];
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMsg);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMsg, nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        _switchBrowserResumeResponse = (MSIDSwitchBrowserResumeResponse *)response;
    }
    
    return self;
}

- (void)invokeWithRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)requestParameters
                       oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
  decidePolicyForBrowserActionBlock:(nullable MSIDExternalDecidePolicyForBrowserActionBlock)decidePolicyForBrowserActionBlock
                    completionBlock:(nonnull MSIDWebviewAuthCompletionHandler)completionBlock
{
    __auto_type webViewConfiguration = [oauthFactory.webviewFactory authorizeWebRequestConfigurationWithRequestParameters:requestParameters];
    webViewConfiguration.startURL = [[NSURL alloc] initWithString:self.switchBrowserResumeResponse.actionUri];
    NSMutableDictionary *customHeaders = [webViewConfiguration.customHeaders mutableCopy] ?: [NSMutableDictionary new];
    customHeaders[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@", self.switchBrowserResumeResponse.switchBrowserSessionToken];
    webViewConfiguration.customHeaders = customHeaders;
    
    NSObject<MSIDWebviewInteracting> *webView = [oauthFactory.webviewFactory webViewWithConfiguration:webViewConfiguration
                                                                                         requestParameters:requestParameters
                                                                      externalDecidePolicyForBrowserAction:decidePolicyForBrowserActionBlock
                                                                                                   context:requestParameters];
    
    if (!webView)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected error. Didn't find any supported web browsers.", nil, nil, nil, nil, nil, YES);
        if (completionBlock) completionBlock(nil, error);
        return;
    }
    
    [MSIDWebviewAuthorization startSessionWithWebView:webView
                                        oauth2Factory:oauthFactory
                                        configuration:webViewConfiguration
                                              context:requestParameters
                                    completionHandler:completionBlock];
}

@end
