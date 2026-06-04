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
#import "MSIDWebviewNavigationDelegate.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDExternalRedirectContext.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDOauth2Factory.h"
#import "MSIDWebviewInteracting.h"
#import "MSIDKeychainUtil.h"

@interface MSIDLocalInteractiveController() <MSIDWebviewNavigationDelegate>

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;

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
        
        // Wire this controller as the webview's navigation delegate so we
        // receive handleSpecialRedirectURL: callbacks from the embedded
        // webview controller when mobile onboarding redirects are detected.
        __weak typeof(self) weakSelf = self;
        MSIDWebviewConfigurationBlock existingBlock = parameters.webviewConfigurationBlock;
        parameters.webviewConfigurationBlock = ^(id<MSIDWebviewInteracting> webviewController) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (existingBlock)
            {
                existingBlock(webviewController);
            }
            if ([webviewController isKindOfClass:[MSIDOAuth2EmbeddedWebviewController class]])
            {
                ((MSIDOAuth2EmbeddedWebviewController *)webviewController).navigationDelegate = strongSelf;
            }
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
        if (msauthResponse && [msauthResponse isKindOfClass:[MSIDWebWPJResponse class]])
        {
            self.currentRequest = nil;
            [self handleWebMSAuthResponse:(MSIDWebWPJResponse *)msauthResponse completion:completionBlock];
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

#pragma mark - MSIDWebviewNavigationDelegate

#if TARGET_OS_IPHONE
- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                      @"Received special redirect URL: %@", URL.scheme);
    
    MSIDBRTAcquisitionBlock block = self.brtAcquisitionBlock;
    
    // Only fire BRT acquisition for the enroll redirect (msauth://enroll?url=…).
    // Other special redirects (e.g. browser://) should not trigger BRT seeding.
    BOOL isBRTEnrollRedirect = [URL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame
                               && [URL.host caseInsensitiveCompare:@"enroll"] == NSOrderedSame;
    
    // Defense-in-depth: BRT seeding is only allowed for Microsoft 1P apps
    // (Team ID UBF8T346G9). This prevents 3P apps from triggering BRT
    // acquisition even if they somehow obtain a reference to this controller.
    NSString *teamId = [MSIDKeychainUtil sharedInstance].teamId;
    BOOL isMicrosoftApp = [teamId isEqualToString:@"UBF8T346G9"];
    
    if (block && isBRTEnrollRedirect && isMicrosoftApp)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                          @"BRT acquisition block is set — building context and firing (fire-and-forget).");
        
        MSIDExternalRedirectContext *context =
            [[MSIDExternalRedirectContext alloc] initWithRedirectURL:URL
                                                      parentWebView:embeddedWebviewController.webView
                                                    parentAuthority:self.interactiveRequestParamaters.authority
                                                      correlationId:self.interactiveRequestParamaters.correlationId
                                                          loginHint:self.interactiveRequestParamaters.loginHint
                                                         tokenCache:self.currentRequest.tokenCache
                                               accountMetadataCache:self.currentRequest.accountMetadataCache
                                                       oauthFactory:self.currentRequest.oauthFactory
                                       parentExtraURLQueryParameters:self.interactiveRequestParamaters.extraURLQueryParameters];
        
        // Fire-and-forget — do not block the parent interactive flow.
        block(context);
    }
    else if (!block)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                          @"No BRT acquisition block set — skipping.");
    }
    else if (!isMicrosoftApp)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters,
                          @"BRT acquisition skipped — app team ID is not Microsoft (UBF8T346G9).");
    }
    
    // Always let the parent webview continue with its default navigation.
    MSIDWebviewNavigationDecision *decision = [MSIDWebviewNavigationDecision new];
    decision.type = MSIDWebviewNavigationDecisionContinueDefault;
    completion(decision, nil);
}
#endif

@end
