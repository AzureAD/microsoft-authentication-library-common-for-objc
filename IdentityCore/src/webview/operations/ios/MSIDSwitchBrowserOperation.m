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


#import "MSIDSwitchBrowserOperation.h"
#import "MSIDSystemWebviewController.h"
#import "MSIDWebviewResponse.h"
#import "MSIDSwitchBrowserResponse.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDMainThreadUtil.h"
#import "MSIDSwitchBrowserResumeResponse.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDCertAuthManager.h"
#import "MSIDInteractiveTokenRequestParameters.h"

@interface MSIDSwitchBrowserOperation()

@property (nonatomic) MSIDSwitchBrowserResponse *switchBrowserResponse;

@end


@implementation MSIDSwitchBrowserOperation

+ (void)load
{
    [MSIDWebResponseOperationFactory registerOperationClass:self forResponseClass:MSIDSwitchBrowserResponse.class];
}

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError *__autoreleasing *)error
{
    self = [super initWithResponse:response error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDSwitchBrowserResponse.class])
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@ is required for creating %@", MSIDSwitchBrowserResponse.class, self.class];
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMsg);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMsg, nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        _switchBrowserResponse = (MSIDSwitchBrowserResponse *)response;
        _certAuthManager = MSIDCertAuthManager.sharedInstance;
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
    NSMutableDictionary *queryItems = [NSMutableDictionary new];
    queryItems[@"code"] = self.switchBrowserResponse.switchBrowserSessionToken;
    queryItems[MSID_OAUTH2_REDIRECT_URI] = requestParameters.redirectUri;
    NSURLComponents *requestURLComponents = [[NSURLComponents alloc] initWithString:self.switchBrowserResponse.actionUri];
    requestURLComponents.percentEncodedQuery = [queryItems msidURLEncode];
    NSURL *startURL = requestURLComponents.URL;
    
    [self.certAuthManager startWithURL:startURL
                      parentController:requestParameters.parentViewController
                               context:requestParameters
                       completionBlock:^(NSURL *callbackURL, NSError *error)
     {
        [self.certAuthManager resetState];
        
        if (error)
        {
            if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(nil, error);
            return;
        }
        
        NSError *localError;
        __auto_type response = [webRequestConfiguration responseWithResultURL:callbackURL factory:oauthFactory.webviewFactory context:requestParameters error:&localError];
        response.parentResponse = self.switchBrowserResponse;
        
        if (localError)
        {
            if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(nil, localError);
            return;
        }
        
        
        if (webviewResponseCompletionBlock) webviewResponseCompletionBlock(response, nil);
    }];
}

@end
