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

#import "MSIDBrokerExtensionInteractiveTokenRequestController.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "MSIDVersion.h"
#import "MSIDJsonSerializer.h"
#import "MSIDBrokerExtensionTokenRequestController+Internal.h"
#import "MSIDAuthority.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDInteractiveTokenRequest.h"

@interface MSIDBrokerExtensionInteractiveTokenRequestController ()

@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;

@end

@implementation MSIDBrokerExtensionInteractiveTokenRequestController

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveRequestParameters *)parameters
                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                  fallbackController:(id<MSIDRequestControlling>)fallbackController
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:fallbackController
                                      error:error];
    if (self)
    {
        _interactiveRequestParameters = parameters;
    }
    
    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive broker flow.");
    
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End interactive broker flow.");
        return;
    }
    
    // TODO: check for current request and cancel it?
    
    self.currentRequest = [self.tokenRequestProvider interactiveBrokerExtensionTokenRequestWithParameters:self.interactiveRequestParameters];

    [self.currentRequest executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error, MSIDWebWPJResponse * msauthResponse)
    {
        MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Interactive broker flow finished result %@, error: %ld error domain: %@", _PII_NULLIFY(result), (long)error.code, error.domain);
            completionBlock(result, error);
        };
        
//        if (msauthResponse)
//        {
//            [self handleWebMSAuthResponse:msauthResponse completion:completionBlockWrapper];
//            return;
//        }

//        MSIDTelemetryAPIEvent *telemetryEvent = [self telemetryAPIEvent];
//        [telemetryEvent setUserInformation:result.account];
//        [self stopTelemetryEvent:telemetryEvent error:error];
        completionBlockWrapper(result, error);
        self.currentRequest = nil;
    }];
}

@end
