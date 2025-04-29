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

#import "MSIDXpcSilentTokenRequestController.h"
#import "MSIDSilentController+Internal.h"
#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDLogger+Internal.h"
#import "MSIDXpcProviderCache.h"

@interface MSIDXpcSilentTokenRequestController ()

// shouldSkipXpcRequest is used when the fallback is not needed for non ASAuthorizationErrorDomain or MSIDErrorSSOExtensionUnexpectedError
@property (nonatomic) BOOL shouldSkipAcquireToken;

@end

@implementation MSIDXpcSilentTokenRequestController

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning silent broker xpc flow, should use Xpc flow to acquire token: %@", @(!self.shouldSkipAcquireToken));
    if (!self.shouldSkipAcquireToken)
    {
        MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult *result, NSError *error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Silent broker xpc flow finished. Result %@, error: %ld error domain: %@, shouldFallBack: %@", _PII_NULLIFY(result), (long)error.code, error.domain, @(self.fallbackController != nil));
            completionBlock(result, error);
        };
        
        __auto_type request = [self.tokenRequestProvider silentXpcTokenRequestWithParameters:self.requestParameters
                                                                                forceRefresh:self.forceRefresh];
        [self acquireTokenWithRequest:request completionBlock:completionBlockWrapper];
    }
    else
    {
        // self.fallbackController cannot be nil here as it has been validated from caller
        if (self.fallbackController)
        {
            [self.fallbackController acquireToken:completionBlock];
        }
        else
        {
            // Add handler in case
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Fallback controller is nil", nil, nil, nil, nil, nil, YES);
            if (completionBlock) completionBlock(nil, error);
        }
    }
}

+ (BOOL)canPerformRequest
{
    if (@available(macOS 13, *)) {
        return [MSIDXpcSingleSignOnProvider canPerformRequest:MSIDXpcProviderCache.sharedInstance];
    }
    else
    {
        return NO;
    }
}

- (void)shouldSkipAcquireTokenBasedOn:(NSError *)error
{
    self.shouldSkipAcquireToken = YES;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Looking if we should fallback to Xpc controller, error: %ld error domain: %@.", (long)error.code, error.domain);
    // If it is MSIDErrorDomain and Sso Extension returns unexpected error, we should fall back to local controler and unblock user
    if (![error.domain isEqualToString:ASAuthorizationErrorDomain] && ![error.domain isEqualToString:MSIDErrorDomain]) {
    }
    
    switch (error.code)
    {
        case ASAuthorizationErrorNotHandled:
        case ASAuthorizationErrorUnknown:
        case ASAuthorizationErrorFailed:
        case MSIDErrorSSOExtensionUnexpectedError:
            self.shouldSkipAcquireToken = NO;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Xpc controller should do fallback: %@", !self.shouldSkipAcquireToken ? @"YES" : @"NO");
}

@end
