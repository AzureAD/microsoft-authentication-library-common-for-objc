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


#import "MSIDWebUpgradeRegOperation.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDWebUpgradeRegResponse.h"

@interface MSIDWebUpgradeRegOperation()

@property (nonatomic) MSIDWebUpgradeRegResponse *response;

@end

@implementation MSIDWebUpgradeRegOperation

+ (void)load
{
    [MSIDWebResponseOperationFactory registerOperationClass:self forResponseClass:MSIDWebUpgradeRegResponse.class];
}

- (nullable instancetype)initWithResponse:(MSIDWebviewResponse *)response
                                    error:(NSError *__autoreleasing *)error
{
    self = [super initWithResponse:response error:error];
    if (self)
    {
        if (![response isKindOfClass:MSIDWebUpgradeRegResponse.class])
        {
            NSString *errorMsg = [NSString stringWithFormat:@"%@ is required for creating %@", MSIDWebUpgradeRegResponse.class, self.class];
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMsg);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMsg, nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        _response = (MSIDWebUpgradeRegResponse *)response;
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
    if (authorizationCodeCompletionBlock) authorizationCodeCompletionBlock(nil, nil, self.response);
}
@end
