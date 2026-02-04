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
#import "MSIDWebInstallProfileResponse.h"
#import "MSIDWebProfileInstallTriggerResponse.h"
#import "MSIDWebviewTransitionCoordinator.h"
#import "MSIDThrottlingService.h"

@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;
@property (nonatomic) MSIDWebviewTransitionCoordinator *transitionCoordinator;

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

- (void)handleWebInstallProfileResponse:(MSIDWebInstallProfileResponse *)response completion:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Handling profile installed response.");
    
    // Check if profile installation was successful
    if (response.status && [response.status isEqualToString:@"success"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Profile installation completed successfully. Resuming authentication flow.");
        
        // TODO: Perform any custom actions needed by localInteractiveController before continuing
        // This is where you can add custom logic such as:
        // - Updating local state
        // - Notifying delegates
        // - Performing additional validation
        // - etc.
        
        // After custom actions, restart the authentication request
        MSIDInteractiveTokenRequest *request = [self.tokenRequestProvider interactiveTokenRequestWithParameters:self.interactiveRequestParamaters];
        [self acquireTokenWithRequest:request completionBlock:completionBlock];
    }
    else
    {
        // Profile installation failed or status is not success
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Profile installation failed with status: %@", response.status);
        
        NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
        if (response.status)
        {
            additionalInfo[@"profile_install_status"] = response.status;
        }
        if (response.additionalInfo)
        {
            [additionalInfo addEntriesFromDictionary:response.additionalInfo];
        }
        
        NSError *profileError = MSIDCreateError(MSIDErrorDomain,
                                               MSIDErrorInternal,
                                               @"Profile installation failed",
                                               nil, nil, nil,
                                               self.requestParameters.correlationId,
                                               additionalInfo,
                                               NO);
        
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], profileError);
        completionBlock(nil, profileError);
    }
}

- (void)handleProfileInstallTrigger:(MSIDWebProfileInstallTriggerResponse *)triggerResponse 
                         completion:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Handling profile install trigger (msauth://installProfile)");
    
    if (!triggerResponse.intuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Profile install trigger detected but no x-intune-url header provided");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, 
                                        @"Intune profile installation URL not found in x-intune-url header", 
                                        nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], error);
        completionBlock(nil, error);
        return;
    }
    
    NSURL *profileURL = [NSURL URLWithString:triggerResponse.intuneURL];
    if (!profileURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Invalid Intune profile installation URL");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, 
                                        @"Invalid Intune profile installation URL", 
                                        nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], error);
        completionBlock(nil, error);
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.requestParameters, 
                         @"Starting Intune profile installation with URL: %@", MSID_PII_LOG_MASKABLE(profileURL));
    
    // Get the current embedded webview to suspend
    MSIDOAuth2EmbeddedWebviewController *embeddedWebview = (MSIDOAuth2EmbeddedWebviewController *)self.currentRequest.currentWebview;
    
    if (!embeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Cannot suspend webview - no current webview found");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, 
                                        @"No current webview found for suspension", 
                                        nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], error);
        completionBlock(nil, error);
        return;
    }
    
    // Prepare additional headers for ASWebAuthenticationSession
    NSDictionary<NSString *, NSString *> *additionalHeaders = nil;
    if (triggerResponse.intuneToken)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Including x-intune-token in ASWebAuthenticationSession headers");
        additionalHeaders = @{@"x-intune-token": triggerResponse.intuneToken};
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"No x-intune-token header found - proceeding without it");
    }
    
    // Suspend the embedded webview (hide but keep alive)
    [self.transitionCoordinator suspendEmbeddedWebview:embeddedWebview];
    
    // Launch ASWebAuthenticationSession for profile installation
    [self.transitionCoordinator launchExternalSession:profileURL
                                      parentController:self.interactiveRequestParamaters.parentViewController
                                        callbackScheme:@"msauth"
                                     additionalHeaders:additionalHeaders
                                     completionHandler:^(NSURL *callbackURL, NSError *sessionError) {
        [self handleProfileInstallationCompletion:callbackURL 
                                            error:sessionError 
                                       completion:completionBlock];
    }];
}

- (void)handleProfileInstallationCompletion:(NSURL *)callbackURL 
                                      error:(NSError *)error
                                 completion:(MSIDRequestCompletionBlock)completionBlock
{
    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, 
                         @"Profile installation session failed: %@", error);
        
        // Clean up
        [self.transitionCoordinator cleanup];
        
        // End the flow with error
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], error);
        completionBlock(nil, error);
        return;
    }
    
    // Check if callback is msauth://profileInstalled
    if (callbackURL && 
        [callbackURL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame &&
        [callbackURL.host caseInsensitiveCompare:@"profileInstalled"] == NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, 
                         @"Profile installation completed successfully (msauth://profileInstalled)");
        
        // ASWebAuthenticationSession has already completed successfully
        // Its completion handler has fired, and the session has cleaned itself up
        // We should NOT call dismiss (which would try to cancel it) - just release our reference
        self.transitionCoordinator.externalSessionHandler = nil;
        
        // Resume the suspended embedded webview
        [self.transitionCoordinator resumeSuspendedEmbeddedWebview];
        
        // The webview will continue its flow naturally
        // It's still alive and will process the next response from the server
        // We don't call completionBlock here - the webview will complete when auth finishes
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, 
                         @"Unexpected callback URL from profile installation: %@", callbackURL);
        
        // Clean up - this will dismiss the session if still active
        [self.transitionCoordinator cleanup];
        
        // Create error for unexpected callback
        NSError *callbackError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, 
                                                @"Unexpected callback from profile installation", 
                                                nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], callbackError);
        completionBlock(nil, callbackError);
    }
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
    
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error, MSIDWebWPJResponse *msauthResponse)
    {
        if (msauthResponse)
        {
            self.currentRequest = nil;
            
            // Handle profile installation trigger - orchestrate the flow
            if ([msauthResponse isKindOfClass:MSIDWebProfileInstallTriggerResponse.class])
            {
                [self handleProfileInstallTrigger:(MSIDWebProfileInstallTriggerResponse *)msauthResponse 
                                       completion:completionBlock];
                return;
            }
            
            // Handle profile installation response - custom actions before continuing
            if ([msauthResponse isKindOfClass:MSIDWebInstallProfileResponse.class])
            {
                [self handleWebInstallProfileResponse:(MSIDWebInstallProfileResponse *)msauthResponse 
                                           completion:completionBlock];
                return;
            }
            
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

@end
