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

#import "MSIDBrokerExtensionSilentTokenRequestController.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDVersion.h"
#import "MSIDJsonSerializer.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDSilentTokenRequest.h"

@interface MSIDBrokerExtensionSilentTokenRequestController () <ASAuthorizationControllerDelegate>

@property (nonatomic) MSIDSilentTokenRequest *currentRequest;

@end

@implementation MSIDBrokerExtensionSilentTokenRequestController

- (void)dealloc
{
    NSLog(@"dealloc");
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning silent broker flow.");
    
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Passed nil completionBlock");
        return;
    }

    self.currentRequest = [self.tokenRequestProvider silentBrokerExtensionTokenRequestWithParameters:self.requestParameters
                                                                                           forceRefresh:self.forceRefresh];

    [self.currentRequest executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Silent broker flow finished result %@, error: %ld error domain: %@", _PII_NULLIFY(result), (long)error.code, error.domain);
            completionBlock(result, error);
        };
        
        if (result || !self.fallbackController)
        {
//            MSIDTelemetryAPIEvent *telemetryEvent = [self telemetryAPIEvent];
//            [telemetryEvent setUserInformation:result.account];
//            [telemetryEvent setIsExtendedLifeTimeToken:result.extendedLifeTimeToken ? MSID_TELEMETRY_VALUE_YES : MSID_TELEMETRY_VALUE_NO];
//            [self stopTelemetryEvent:telemetryEvent error:error];
            completionBlockWrapper(result, error);
            return;
        }

        [self.fallbackController acquireToken:completionBlockWrapper];
        
        self.currentRequest = nil;
    }];
}

+ (BOOL)canPerformRequest
{
    // TODO: implement.
    return YES;
}

@end
