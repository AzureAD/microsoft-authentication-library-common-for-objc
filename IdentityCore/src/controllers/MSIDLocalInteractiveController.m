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
#import "MSIDWebviewNavigationHandler.h"
#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDRequestControllerFactory.h"

@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;
@property (nonatomic, strong) MSIDWebviewNavigationHandler *navigationHandler;

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
        _navigationHandler = [[MSIDWebviewNavigationHandler alloc] initWithContext:parameters];

        // Wire the navigation handler into the webview controller once it's created.
        __weak typeof(self) weakSelf = self;
        parameters.webviewConfigurationBlock = ^(id<MSIDWebviewInteracting> webviewController) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf)
            {
                return;
            }

            [strongSelf.navigationHandler configureWebviewController:webviewController
                                                          delegate:strongSelf];
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
            [[MSIDThrottlingService resolvedRefresher] updateLastRefreshTimeDatasource:request.extendedTokenCache
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
    
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error, MSIDWebviewResponse *msauthResponse)
    {
        if (msauthResponse)
        {
            self.currentRequest = nil;
            
            // Handle MDM enrollment completion response
            if ([msauthResponse isKindOfClass:MSIDWebMDMEnrollmentCompletionResponse.class])
            {
                [self handleWebMDMEnrollmentCompletionResponse:(MSIDWebMDMEnrollmentCompletionResponse *)msauthResponse
                                                    completion:completionBlock];
                return;
            }
            
            if ([msauthResponse isKindOfClass:[MSIDWebWPJResponse class]])
            {
                [self handleWebMSAuthResponse:(MSIDWebWPJResponse *)msauthResponse
                                   completion:completionBlock];
                return;
            }
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

#pragma mark - MDM Response Handlers

- (void)handleWebMDMEnrollmentCompletionResponse:(MSIDWebMDMEnrollmentCompletionResponse *)mdmEnrollmentCompletionResponse
                                      completion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                          @"Passed nil completionBlock to handleWebMDMEnrollmentCompletionResponse.");
        return;
    }

    NSString *status = mdmEnrollmentCompletionResponse.status ?: @"<none>";

    // Failure path: MDM enrollment did not complete.
    if (!mdmEnrollmentCompletionResponse.isSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                          @"MDM enrollment failed (status=%@).", status);

        NSString *errorDescription = [NSString stringWithFormat:@"MDM enrollment failed with status: %@", status];
        NSError *enrollmentError = MSIDCreateError(MSIDErrorDomain,
                                                   MSIDErrorInternal,
                                                   errorDescription,
                                                   nil, nil, nil,
                                                   self.requestParameters.correlationId,
                                                   nil,
                                                   NO);

        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], enrollmentError);
        completionBlock(nil, enrollmentError);
        return;
    }

    // MDM enrollment complete. Retry the token request through the appropriate controller.
    // If broker is installed and SSO extension is active, the factory returns the SSO controller.
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                      @"MDM enrollment complete (status=%@); retrying token request.", status);

    NSError *brokerError = nil;
    id<MSIDRequestControlling> brokerController =
        [MSIDRequestControllerFactory interactiveControllerForParameters:self.interactiveRequestParamaters
                                                    tokenRequestProvider:self.tokenRequestProvider
                                                                   error:&brokerError];

    // Could not build a controller, cannot retry the request.
    if (!brokerController)
    {
        if (!brokerError)
        {
            brokerError = MSIDCreateError(MSIDErrorDomain,
                                          MSIDErrorInternal,
                                          @"Failed to resolve a controller after MDM enrollment.",
                                          nil, nil, nil,
                                          self.requestParameters.correlationId,
                                          nil,
                                          YES);
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                          @"Failed to resolve a controller after MDM enrollment: %@", brokerError);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], brokerError);
        completionBlock(nil, brokerError);
        return;
    }

    // Stop local telemetry, the downstream controller owns its own event.
    CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], nil);

    // Retry the request; the result flows back to the caller via completionBlock.
    [brokerController acquireToken:completionBlock];
}

#pragma mark - Webview Navigation Delegate

- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion
{
    [self.navigationHandler handleSpecialRedirectURL:URL
                           embeddedWebviewController:embeddedWebviewController
                                          completion:completion];
}

- (BOOL)processNavigationResponseAndCheckForASWebAuthHandoff:(NSHTTPURLResponse *)response
                                   embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
{
    return [self.navigationHandler processNavigationResponseAndCheckForASWebAuthHandoff:response
                                                              embeddedWebviewController:embeddedWebviewController];
}

#if !MSID_EXCLUDE_SYSTEMWV
- (void)performASWebAuthenticationHandoffWithCompletion:(void (^)(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                  NSError * _Nullable error))completion
{
    [self.navigationHandler performASWebAuthenticationHandoffWithParentController:self.interactiveRequestParamaters.parentViewController
                                                                       completion:completion];
}
#endif // !MSID_EXCLUDE_SYSTEMWV

@end
