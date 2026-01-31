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
#import "MSIDInteractiveWebviewState.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"
#import "MSIDWebviewResponse.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDASWebAuthenticationSessionHandler.h"
#if TARGET_OS_IPHONE
#import "MSIDBrokerInteractiveController.h"
#endif
#import "MSIDWebWPJResponse.h"
#import "MSIDWebUpgradeRegResponse.h"
#import "MSIDThrottlingService.h"

@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;
@property (nonatomic, strong) MSIDSpecialURLViewActionResolver *urlResolver;

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
        _specialURLHandlingEnabled = NO; // Default OFF for safety
        _sessionState = [[MSIDInteractiveWebviewState alloc] init];
        _urlResolver = [[MSIDSpecialURLViewActionResolver alloc] init];
    }

    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive flow.");
    
    MSIDInteractiveTokenRequest *request = [self.tokenRequestProvider interactiveTokenRequestWithParameters:self.interactiveRequestParamaters];
    
    // Set handler for special URL processing (weak reference - no cyclic reference)
    request.webviewHandler = self;

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
    
    [request executeRequestWithCompletion:^(MSIDTokenResult *result, NSError *error, MSIDWebWPJResponse *msauthResponse)
    {
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

- (void)configureWebviewController:(NSObject<MSIDWebviewInteracting> *)webviewController
{
    if (!self.specialURLHandlingEnabled)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Special URL handling disabled - skipping webview configuration");
        return;
    }
    
    if (![webviewController isKindOfClass:[MSIDOAuth2EmbeddedWebviewController class]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Webview controller is not embedded webview - skipping special URL configuration");
        return;
    }
    
    MSIDOAuth2EmbeddedWebviewController *embeddedController = (MSIDOAuth2EmbeddedWebviewController *)webviewController;
    
    // Wire handler (self implements MSIDInteractiveWebviewHandler)
    embeddedController.handler = self;
    
    // Pass session state (owned by this controller)
    embeddedController.sessionState = self.sessionState;
    
    // Simplified approach: No state machine needed!
    // Handler is called directly for synchronous action resolution
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Webview controller configured with simplified special URL handling (direct handler pattern)");
}

#pragma mark - MSIDInteractiveWebviewHandler

#pragma mark Context Checking

- (BOOL)isRunningInBrokerContext
{
    // MSIDLocalInteractiveController is non-broker context
    // Broker context is handled by ADBrokerInteractiveControllerWithPRT
    return NO;
}

#pragma mark Policy Hooks

- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Only acquire BRT if NOT in broker context (always NO for LocalInteractiveController)
    if ([self isRunningInBrokerContext])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Skipping BRT acquisition - already in broker context");
        return NO;
    }
    
    // Check if already acquired successfully
    if (state.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Skipping BRT acquisition - already acquired");
        return NO;
    }
    
    // Check if max attempts reached
    if (state.brtAttemptCount >= 2)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"Skipping BRT acquisition - max attempts (%ld) reached", (long)state.brtAttemptCount);
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.requestParameters, @"BRT acquisition needed for URL: %@", MSID_PII_LOG_MASKABLE(url));
    return YES;
}

- (MSIDInteractiveWebviewBRTFailurePolicy)brtFailurePolicyForSpecialURL:(__unused NSURL *)url
                                                                   state:(__unused MSIDInteractiveWebviewState *)state
{
    // For now, always continue even if BRT fails
    // This allows the flow to proceed and potentially retry on next special URL
    return MSIDInteractiveWebviewBRTFailurePolicyContinue;
}

- (BOOL)shouldRetryInBrokerForSpecialURL:(__unused NSURL *)url state:(__unused MSIDInteractiveWebviewState *)state
{
    // Only retry in broker if NOT already in broker context
    if ([self isRunningInBrokerContext])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Already in broker context - no retry needed");
        return NO;
    }
    
#if TARGET_OS_IPHONE
    // On iOS, we can retry in broker via MSIDBrokerInteractiveController
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Will retry in broker context");
    return YES;
#else
    // On macOS, broker retry not currently supported
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Broker retry not supported on macOS");
    return NO;
#endif
}

#pragma mark Action Implementations

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!completion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"acquireBRTTokenWithCompletion called with nil completion");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Acquiring BRT token (attempt %ld/%d)", (long)self.sessionState.brtAttemptCount + 1, 2);
    
    // TODO: Implement actual BRT token acquisition
    // For now, return error indicating not implemented
    // In production, this would make a token request for broker refresh token
    
    NSError *error = MSIDCreateError(MSIDErrorDomain, 
                                     MSIDErrorInternal,
                                     @"BRT acquisition not yet implemented in MSIDLocalInteractiveController", 
                                     nil, nil, nil, 
                                     self.requestParameters.correlationId, 
                                     nil, NO);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"BRT acquisition result: FAILED (not implemented)");
    
    completion(NO, error);
}

- (NSError *)genericBrtError
{
    return MSIDCreateError(MSIDErrorDomain,
                          MSIDErrorInternal,
                          @"BRT acquisition failed",
                          nil, nil, nil,
                          self.requestParameters.correlationId,
                          nil, NO);
}

- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url
                                          completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (!completion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"retryInteractiveRequestInBrokerContextForURL called with nil completion");
        return;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.requestParameters, @"Retrying request in broker context for URL: %@", MSID_PII_LOG_MASKABLE(url));
    
#if TARGET_OS_IPHONE
    // Create broker controller and retry the request
    NSError *brokerError = nil;
    MSIDBrokerInteractiveController *brokerController = [[MSIDBrokerInteractiveController alloc] 
                                                         initWithInteractiveRequestParameters:self.interactiveRequestParamaters
                                                         tokenRequestProvider:self.tokenRequestProvider
                                                         brokerInstallLink:nil
                                                         error:&brokerError];
    
    if (!brokerController)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Failed to create broker controller: %@", brokerError);
        completion(NO, brokerError);
        return;
    }
    
    // TODO: Actually execute the broker request
    // For now, just signal success that we transferred to broker
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Successfully transferred to broker context");
    completion(YES, nil);
    
    // Note: Broker controller will continue the flow in broker context
    // The current webview should be dismissed by caller
#else
    NSError *error = MSIDCreateError(MSIDErrorDomain, 
                                     MSIDErrorInternal,
                                     @"Broker retry not supported on macOS", 
                                     nil, nil, nil,
                                     self.requestParameters.correlationId,
                                     nil, NO);
    MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Broker retry not supported on this platform");
    completion(NO, error);
#endif
}

- (void)dismissEmbeddedWebviewIfPresent
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Dismissing embedded webview");
    
    // TODO: Implement webview dismissal
    // This should dismiss the current webview if it's presented
    // The InteractiveController knows about the webview through the request
}

#pragma mark Header Capture

- (void)didReceiveHTTPResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    // Controller owns sessionState, so controller sets responseHeaders
    // This ensures proper ownership - no external mutation of controller's state
    self.sessionState.responseHeaders = headers;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, 
                     @"Captured %lu HTTP response header(s) for special URL processing", 
                     (unsigned long)headers.count);
}

#pragma mark View Action Resolution

- (MSIDWebviewAction * _Nullable)viewActionForSpecialURL:(NSURL *)url
                                                    state:(MSIDInteractiveWebviewState *)state
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.requestParameters, @"Resolving view action for special URL: %@", MSID_PII_LOG_MASKABLE(url));
    
    // Use resolver to map URL to action
    MSIDWebviewAction *action = [self.urlResolver resolveActionForURL:url state:state];
    
    if (action)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Resolved action type: %ld", (long)action.type);
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"No action resolved for URL");
    }
    
    return action;
}

#pragma mark Telemetry

- (void)handleWebviewResponseForTelemetry:(MSIDWebviewResponse *)response
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Handling webview response for telemetry");
    
    // TODO: Record telemetry for special URL responses
    // This can track special URL types, timing, success/failure, etc.
}

#pragma mark - System Webview Management

- (void)openSystemWebviewWithURL:(NSURL *)url
                         headers:(NSDictionary<NSString *, NSString *> *)headers
                         purpose:(MSIDSystemWebviewPurpose)purpose
                      completion:(void (^)(NSURL * _Nullable callbackURL, NSError * _Nullable error))completion
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.requestParameters, 
                         @"Opening system webview for purpose: %d with URL: %@", 
                         (int)purpose, MSID_PII_LOG_MASKABLE(url));
    
    // Create ASWebAuthenticationSession in CONTROLLER layer (correct architectural layer)
    // This keeps EmbeddedWebViewController focused only on embedded webview management
    MSIDASWebAuthenticationSessionHandler *asWebAuthHandler = 
        [[MSIDASWebAuthenticationSessionHandler alloc] 
            initWithParentController:self.parentController
                            startURL:url
                      callbackScheme:@"msauth"
                  useEmpheralSession:YES
                  additionalHeaders:headers];
    
    self.currentSystemWebview = asWebAuthHandler;
    
    // Start ASWebAuth session
    __weak typeof(self) weakSelf = self;
    [asWebAuthHandler startWithCompletionHandler:^(NSURL *callbackURL, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (error) {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.requestParameters, 
                             @"System webview failed: %@", error);
        } else if (callbackURL) {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, strongSelf.requestParameters, 
                                 @"System webview completed with callback: %@", 
                                 MSID_PII_LOG_MASKABLE(callbackURL));
        }
        
        // Clear reference
        strongSelf.currentSystemWebview = nil;
        
        // Call completion
        if (completion) {
            completion(callbackURL, error);
        }
    }];
}

@end
