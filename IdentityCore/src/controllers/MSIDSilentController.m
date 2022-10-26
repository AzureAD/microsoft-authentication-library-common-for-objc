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

#import "MSIDSilentController+Internal.h"
#import "MSIDSilentTokenRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif

@interface MSIDSilentController() <MSIDSilentTokenRequestDelegate>

@property (nonatomic, readwrite) BOOL forceRefresh;
@property (nonatomic) NSError *ssoError;
@property (nonatomic) MSIDSilentTokenRequest *currentRequest;

@end

@implementation MSIDSilentController

#pragma mark - Init

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                              tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                             error:(NSError * _Nullable * _Nullable)error
{
    return [self initWithRequestParameters:parameters
                              forceRefresh:forceRefresh
                      tokenRequestProvider:tokenRequestProvider
             fallbackInteractiveController:nil
                                     error:error];
}

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                              tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                     fallbackInteractiveController:(nullable id<MSIDRequestControlling>)fallbackController
                                             error:(NSError * _Nullable * _Nullable)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:fallbackController
                                      error:error];
    
    if (self)
    {
        _forceRefresh = forceRefresh;
    }
    
    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeSilentRequest];
#endif
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning silent flow.");
    
    MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeSilentRequest];
#endif
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Silent flow finished. Result %@, error: %ld error domain: %@", _PII_NULLIFY(result), (long)error.code, error.domain);
        completionBlock(result, error);
    };
    
    __auto_type request = [self.tokenRequestProvider silentTokenRequestWithParameters:self.requestParameters
                                                                         forceRefresh:self.forceRefresh];
    request.delegate = self;
    [self acquireTokenWithRequest:request completionBlock:completionBlockWrapper];
}

#pragma mark - Protected

- (void)acquireTokenWithRequest:(MSIDSilentTokenRequest *)request
                completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Passed nil completionBlock");
        return;
    }

    CONDITIONAL_START_EVENT(CONDITIONAL_SHARED_INSTANCE, self.requestParameters.telemetryRequestId, MSID_TELEMETRY_EVENT_API_EVENT);
    self.currentRequest = request;
    __weak typeof (self) weakSelf = self;
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error)
    {
        typeof (self) strongSelf = weakSelf;
        // This should not happen, and good to add a check point.
        if (!strongSelf)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Instance is dealloc");
            return;
        }
        
        if (strongSelf.ssoError
            || result
            || !strongSelf.fallbackController)
        {
#if !EXCLUDE_FROM_MSALCPP
            MSIDTelemetryAPIEvent *telemetryEvent = [strongSelf telemetryAPIEvent];
            [telemetryEvent setUserInformation:result.account];
            [telemetryEvent setIsExtendedLifeTimeToken:result.extendedLifeTimeToken ? MSID_TELEMETRY_VALUE_YES : MSID_TELEMETRY_VALUE_NO];
            if(strongSelf.ssoError)
            {
                [telemetryEvent setSsoExtFallBackFlow:1];
            }
            
            [strongSelf stopTelemetryEvent:telemetryEvent error:error];
#endif
            strongSelf.currentRequest = nil;
            completionBlock(result, error);
            return;
        }

        strongSelf.currentRequest = nil;
        MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult *ssoResult, NSError *ssoError)
        {
            // We don't have any meaningful information from fallback controller (edge case of SSO error) so we use the local controller result earlier
            
            // If ssoError presented already, skip broker when came back from local RT fallback
            strongSelf.ssoError = ssoError;
            if (!ssoResult && (strongSelf.requestParameters.allowGettingAccessTokenWithRefreshToken || ssoError.code == MSIDErrorSSOExtensionUnexpectedError))
            {
                // Skip duplicate local cache lookups
                strongSelf.forceRefresh = YES;
                [strongSelf acquireToken:^(MSIDTokenResult *localRtResults, NSError *localRtError)
                {
                    [strongSelf completionHandler:localRtResults
                                  ssoResult:nil
                                      error:localRtError
                                   ssoError:strongSelf.ssoError
                            completionBlock:completionBlock];
                }];
                
                return;
            }
            
            [strongSelf completionHandler:nil
                          ssoResult:ssoResult
                              error:error
                           ssoError:self.ssoError
                    completionBlock:completionBlock];
        };

        [strongSelf.fallbackController acquireToken:completionBlockWrapper];
    }];
}

- (void)completionHandler:(nullable MSIDTokenResult *)result
                ssoResult:(nullable MSIDTokenResult *)ssoResult
                    error:(nullable NSError *)error
                 ssoError:(nullable NSError *)ssoError
          completionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    if (result)
    {
        completionBlock(result, error);
    }
    else if (!ssoResult && (ssoError.code == MSIDErrorSSOExtensionUnexpectedError))
    {
        completionBlock(result, error);
    }
    else
    {
        completionBlock(ssoResult, ssoError);
    }
}

#pragma mark - MSIDSilentTokenRequestDelegate

- (BOOL)skipCahcedRefreshToken
{
    // Use Sso Ext when MSIDSSOExtensionSilentTokenRequestController is available and has not run through Sso Ext yet
    return self.fallbackController && !self.ssoError;
}

@end
