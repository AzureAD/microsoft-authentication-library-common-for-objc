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

#import "MSIDLocalInteractiveController+Internal.h"
#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "MSIDClientInfo.h"
#if TARGET_OS_IPHONE
#import "MSIDBrokerInteractiveController.h"
#endif
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDThrottlingService.h"
#import "MSIDWebviewNavigationDelegateHelper.h"
#import "MSIDWebviewNavigationAction.h"
#import "MSIDWebviewNavigationActionUtil.h"

@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;
@property (nonatomic, strong) MSIDWebviewNavigationDelegateHelper *delegateHelper;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *lastResponseHeaders;

@end

@implementation MSIDLocalInteractiveController

#pragma mark - Init

- (nullable instancetype)initWithInteractiveRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                         tokenRequestProvider:(nonnull id<MSIDTokenRequestProviding>)tokenRequestProvider
                                                        error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:nil
                                      error:error];

    if (self)
    {
        _interactiveRequestParamaters = parameters;
        // Initialize delegate helper and transition handler
        _delegateHelper = [[MSIDWebviewNavigationDelegateHelper alloc] initWithContext:parameters];
        // Set webview configuration block
        __weak typeof(self) weakSelf = self;
        parameters.webviewConfigurationBlock = ^(id<MSIDWebviewInteracting> webviewController) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            [strongSelf configureWebviewController:webviewController];
        };
    }

    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive flow.");
    
    MSIDInteractiveTokenRequest *request = [self.tokenRequestProvider interactiveTokenRequestWithParameters:self.interactiveRequestParamaters];

    MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        NSString *ssoNonce = [error.userInfo valueForKey:MSID_SSO_NONCE_QUERY_PARAM_KEY];
        if ([NSString msidIsStringNilOrBlank:ssoNonce])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Interactive flow finished. Result %@, error: %ld error domain: %@", _PII_NULLIFY(result), (long)error.code, error.domain);
        }
        if (!error)
        {
            /**
             Throttling service: when an interactive token succeed, we update the last refresh time of the throttling service
             */
            [MSIDThrottlingService updateLastRefreshTimeDatasource:request.extendedTokenCache
                                                               context:self.interactiveRequestParamaters
                                                                 error:nil];
        }
        
        if (!completionBlock)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End local interactive acquire token.");
            return;
        }
        
        completionBlock(result, error);
    };

    [self acquireTokenWithRequest:request completionBlock:completionBlockWrapper];
}

- (void)handleWebMSAuthResponse:(MSIDWebWPJResponse *)response completion:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Handling msauth response.");
    
    if (![NSString msidIsStringNilOrBlank:response.appInstallLink])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Prompt broker install.");
        [self promptBrokerInstallWithResponse:response completionBlock:completionBlock];
        return;
    }

    if (![NSString msidIsStringNilOrBlank:response.upn])
    {
        NSError *registrationError;
        if ([response isKindOfClass:MSIDWebUpgradeRegResponse.class])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Workplace join Upgrade registration is required.");
            
            NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
            additionalInfo[MSIDUserDisplayableIdkey] = response.upn;
            additionalInfo[MSIDHomeAccountIdkey] = response.clientInfo.accountIdentifier;
            
            registrationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInsufficientDeviceStrength,
                                                @"Workplace join Upgrade registration is required", nil, nil, nil, self.requestParameters.correlationId, additionalInfo, NO);
        }
        else if ([response isKindOfClass:MSIDWebWPJResponse.class])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Workplace join is required.");
            
            NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
            additionalInfo[MSIDUserDisplayableIdkey] = response.upn;
            additionalInfo[MSIDHomeAccountIdkey] = response.clientInfo.accountIdentifier;
            additionalInfo[MSIDTokenProtectionRequired] = response.tokenProtectionRequired ? @(YES) : @(NO);

            registrationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorWorkplaceJoinRequired, @"Workplace join is required", nil, nil, nil, self.requestParameters.correlationId, additionalInfo, NO);
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Invalid WebResponse. This is a critical code bug");
            registrationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Invalid WebResponse", nil, nil, nil, self.requestParameters.correlationId, nil, NO);
        }
        
#if !EXCLUDE_FROM_MSALCPP
        MSIDTelemetryAPIEvent *telemetryEvent = [self telemetryAPIEvent];
        [telemetryEvent setLoginHint:response.upn];
        [self stopTelemetryEvent:telemetryEvent error:registrationError];
#endif
        completionBlock(nil, registrationError);
        return;
    }

    NSError *appInstallError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"App install link is missing. Incorrect URL returned from server", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
    CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], appInstallError);
    completionBlock(nil, appInstallError);
}

- (void)promptBrokerInstallWithResponse:(__unused MSIDWebWPJResponse *)response completionBlock:(MSIDRequestCompletionBlock)completion
{
#if TARGET_OS_IPHONE
    if ([NSString msidIsStringNilOrBlank:response.appInstallLink])
    {
        NSError *appInstallError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"App install link is missing. Incorrect URL returned from server", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], appInstallError);
        completion(nil, appInstallError);
        return;
    }

    NSError *brokerError = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] initWithInteractiveRequestParameters:self.interactiveRequestParamaters
                                                                                                                 tokenRequestProvider:self.tokenRequestProvider
                                                                                                                    brokerInstallLink:[NSURL URLWithString:response.appInstallLink]
                                                                                                                                error:&brokerError];

    if (!brokerController)
    {
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], brokerError);
        completion(nil, brokerError);
        return;
    }

    [brokerController acquireToken:completion];
#else
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Trying to install broker on macOS, where it's not currently supported", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
    CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], error);
    completion(nil, error);
#endif
}

#if !EXCLUDE_FROM_MSALCPP
- (MSIDTelemetryAPIEvent *)telemetryAPIEvent
{
    MSIDTelemetryAPIEvent *event = [super telemetryAPIEvent];

    if (self.interactiveRequestParamaters.loginHint)
    {
        [event setLoginHint:self.interactiveRequestParamaters.loginHint];
    }

    [event setWebviewType:self.interactiveRequestParamaters.telemetryWebviewType];
    [event setPromptType:self.interactiveRequestParamaters.promptType];

    return event;
}
#endif

#pragma mark - Protected

- (void)acquireTokenWithRequest:(MSIDInteractiveTokenRequest *)request
                completionBlock:(MSIDRequestCompletionBlock)completionBlock
{
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock.");
        return;
    }

    CONDITIONAL_START_EVENT(CONDITIONAL_SHARED_INSTANCE, self.interactiveRequestParamaters.telemetryRequestId, MSID_TELEMETRY_EVENT_API_EVENT);

    self.currentRequest = request;
    
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error, MSIDWebviewResponse *response)
    {
        MSIDWebWPJResponse *msauthResponse = (MSIDWebWPJResponse *)response;;
        if (msauthResponse)
        {
            self.currentRequest = nil;
            [self handleWebMSAuthResponse:msauthResponse completion:completionBlock];
            return;
        }
#if !EXCLUDE_FROM_MSALCPP
        MSIDTelemetryAPIEvent *telemetryEvent = [self telemetryAPIEvent];
        [telemetryEvent setUserInformation:result.account];
        [self stopTelemetryEvent:telemetryEvent error:error];
#endif
        self.currentRequest = nil;
        
        completionBlock(result, error);
    }];
}

#pragma mark - Webview Configuration

- (void)configureWebviewController:(id)webviewController
{
    // Setting navigation delegate
    [self.delegateHelper configureWebviewController:webviewController delegate:self];
}

#pragma mark - Webview Navigation Delegate

- (void)handleSpecialRedirectUrl:(NSURL *)url
               webviewController:(id<MSIDWebviewInteracting>)webviewController
                      completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"MSIDLocalInteractiveController handling special redirect: %@", _PII_NULLIFY(url));
    
    // Create BRT evaluator block
    __weak typeof(self) weakSelf = self;
    BOOL (^brtEvaluator)(void) = ^BOOL {
        __strong typeof(self) strongSelf = weakSelf;
        return strongSelf ? [strongSelf shouldAcquireBRT] : NO;
    };
    
    // Create BRT handler block
    void (^brtHandler)(void(^)(BOOL success, NSError * _Nullable error)) = ^(void(^brtCompletion)(BOOL success, NSError * _Nullable error)) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            brtCompletion(NO, nil);
            return;
        }
        
        [strongSelf acquireBRTWithCompletion:^(BOOL success, NSError *error) {
            // Track BRT acquisition attempt and result
            strongSelf.brtAttempted = YES;
            
            if (error) {
                MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.requestParameters,
                                 @"Failed to acquire BRT: %@", error);
            }
            
            if (success) {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, strongSelf.requestParameters,
                                 @"BRT acquired successfully");
                strongSelf.brtAcquired = YES;
            }
            
            // Call the completion from DelegateHelper
            brtCompletion(success, error);
        }];
    };
    
    // Delegate ALL logic to DelegateHelper
    // DelegateHelper will handle:
    // - Scheme checking (msauth://, browser://)
    // - BRT acquisition (if needed)
    // - Navigation action resolution
    // - Error handling
    [self.delegateHelper handleSpecialRedirectUrl:url
                                webviewController:webviewController
                                       completion:completion
                                     brtEvaluator:brtEvaluator
                                       brtHandler:brtHandler
                                  isBrokerContext:NO
                          externalNavigationBlock:self.currentRequest.externalDecidePolicyForBrowserAction];
}

- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *_Nullable)headers
                    completion:(void (^)(MSIDWebviewNavigationAction *action, NSError *error))completion
{
//    [self.delegateHelper processResponseHeaders:headers
//                              transitionHandler:self.transitionHandler
//                               parentController:self.requestParameters.parentViewController];
}

#pragma mark - BRT Acquisition

/**
 * Acquires Broker Refresh Token (BRT)
 * This is the new logic that needs to be implemented
 */
- (void)acquireBRTWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                     @"Starting BRT acquisition.");
    
    // TODO: Implement BRT acquisition logic
    // This would involve:
    // 1. Creating BRT request with current parameters
    // 2. Executing BRT token request
    // 3. Storing BRT in cache
    // 4. Calling completion with success/failure
    
    // Placeholder implementation:
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Simulate BRT acquisition work
        // Replace with actual implementation
        BOOL success = YES; // Replace with actual logic
        NSError *error = nil;
        
        if (!success)
        {
            error = MSIDCreateError(MSIDErrorDomain,
                                   MSIDErrorInternal,
                                   @"Failed to acquire BRT",
                                   nil, nil, nil,
                                   self.requestParameters.correlationId,
                                   nil, NO);
        }

        // Call completion on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    });
}

#pragma mark - Policy Checks (Internal)

- (BOOL)shouldAcquireBRT
{
    id<MSIDRequestContext> context = self.requestParameters;
    
    // Check if already acquired successfully
    if (self.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Skipping BRT acquisition - already acquired");
        return NO;
    }
    
    // Simplified: Check if already attempted (only attempt once)
    if (self.brtAttempted)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Skipping BRT acquisition - already attempted once");
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"BRT acquisition needed for special redirect URL");
    return YES;
}
@end
