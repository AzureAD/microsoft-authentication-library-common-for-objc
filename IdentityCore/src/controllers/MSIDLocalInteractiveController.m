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
#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDKeychainUtil.h"
#import "MSIDExternalRedirectContext.h"
#import "MSIDOpportunisticBRTSeeder.h"
#if !MSID_EXCLUDE_WEBKIT
#import "MSIDWebviewNavigationHandler.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#endif

@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveTokenRequestParameters *interactiveRequestParamaters;
@property (nonatomic) MSIDInteractiveTokenRequest *currentRequest;
@property (nonatomic) BOOL brtAttempted;
#if !MSID_EXCLUDE_WEBKIT
@property (nonatomic, strong) MSIDWebviewNavigationHandler *navigationHandler;
#endif

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
        
#if !MSID_EXCLUDE_WEBKIT
        // Wire self as navigation delegate for BRT acquisition (POC)
        _navigationHandler = [[MSIDWebviewNavigationHandler alloc] initWithContext:parameters];

        __weak typeof(self) weakSelf = self;
        parameters.webviewConfigurationBlock = ^(id<MSIDWebviewInteracting> webviewController) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf)
            {
                [strongSelf.navigationHandler configureWebviewController:webviewController
                                                               delegate:strongSelf];
            }
        };
#endif
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
            if ([msauthResponse isKindOfClass:MSIDWebMDMEnrollmentCompletionResponse.class])
            {
                [self handleWebMDMEnrollmentCompletionResponse:(MSIDWebMDMEnrollmentCompletionResponse *)msauthResponse
                                                  completion:completionBlock];
                return;
            }
            if ([msauthResponse isKindOfClass:[MSIDWebWPJResponse class]])
            {
                [self handleWebMSAuthResponse:(MSIDWebWPJResponse *)msauthResponse completion:completionBlock];
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
    NSString *status = mdmEnrollmentCompletionResponse.status ?: @"<none>";
    
    if (mdmEnrollmentCompletionResponse.isSuccess)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Profile installation completed successfully. Resuming authentication flow in broker context.");
        
        // TODO: Perform any custom actions needed by localInteractiveController before continuing
        NSError *brokerError = nil;
        id<MSIDRequestControlling> brokerController = [MSIDRequestControllerFactory interactiveControllerForParameters:self.interactiveRequestParamaters tokenRequestProvider:self.tokenRequestProvider error:&brokerError];
        
        // if broker is installed and sso profile is active this should return sso controller
        if (!brokerController)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                              @"Failed to create broker controller after profile installation: %@", brokerError);
            CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], brokerError);
            completionBlock(nil, brokerError);
            return;
        }
        
        // Broker will invoke SSO extension which handles the request in its own webview
        // Response will be sent back to calling app through the broker completion handler
        [brokerController acquireToken:completionBlock];
    }
    else
    {
        // Profile installation failed or status is not success
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters,
                          @"MDM Enrollment failed (status=%@).", status);
        
        NSError *profileError = MSIDCreateError(MSIDErrorDomain,
                                                MSIDErrorInternal,
                                                @"Profile installation failed",
                                                nil, nil, nil,
                                                self.requestParameters.correlationId,
                                                nil, NO);
        
        CONDITIONAL_STOP_TELEMETRY_EVENT([self telemetryAPIEvent], profileError);
        completionBlock(nil, profileError);
    }
}

#if !MSID_EXCLUDE_WEBKIT
#pragma mark - MSIDWebviewNavigationDelegate (BRT POC)

- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable, NSError * _Nullable))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                      @"Received special redirect URL: %@", URL.scheme);
    
    // Fire-and-forget BRT seeding — does not block parent navigation
    if (!self.brtAttempted)
    {
        self.brtAttempted = YES;

        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                          @"BRT POC: Firing opportunistic BRT seed (fire-and-forget).");

        MSIDBRTAcquisitionBlock block = self.brtAcquisitionBlock;
        
        // Only fire BRT acquisition for the enroll redirect (msauth://enroll?url=…).
        // Other special redirects (e.g. browser://) should not trigger BRT seeding.
        BOOL isBRTEnrollRedirect = [URL.scheme caseInsensitiveCompare:@"msauth"] == NSOrderedSame
                                   && [URL.host caseInsensitiveCompare:@"enroll"] == NSOrderedSame;
        
        if (block && isBRTEnrollRedirect && MSIDIsMicrosoft1PHostProcess())
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
        else if (!block && isBRTEnrollRedirect && MSIDIsMicrosoft1PHostProcess())
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                              @"No BRT acquisition block set");
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters,
                              @"BRT POC: Firing opportunistic BRT seed (fire-and-forget).");
            // Proceed immediately — seeder runs in background and does not block parent navigation.
            [MSIDOpportunisticBRTSeeder seedWithParentParameters:self.interactiveRequestParamaters
                                                         webView:embeddedWebviewController.webView
                                                      tokenCache:self.currentRequest.tokenCache
                                            accountMetadataCache:self.currentRequest.accountMetadataCache
                                                    oauthFactory:self.currentRequest.oauthFactory
                                          tokenResponseValidator:self.currentRequest.tokenResponseValidator
                                                         context:self.requestParameters];
        }
        else if (!MSIDIsMicrosoft1PHostProcess())
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters,
                              @"BRT acquisition skipped — host app is not Microsoft-signed.");
        }
    }

    // Proceed immediately — seeder runs in background
    [self.navigationHandler handleSpecialRedirectURL:URL
                        embeddedWebviewController:embeddedWebviewController
                                          appName:@"MSAL"
                                       appVersion:@"1.0"
                                       completion:completion];
}
#endif

#if !MSID_EXCLUDE_WEBKIT
- (BOOL)processResponseHeadersAndCheckForASWebAuthHandoff:(NSDictionary *)headers
                                              responseURL:(NSURL *)responseURL
{
    return [self.navigationHandler processResponseHeadersAndCheckForASWebAuthHandoff:headers
                                                                          responseURL:responseURL];
}

#if !MSID_EXCLUDE_SYSTEMWV
- (void)performASWebAuthenticationHandoffWithCompletion:(void (^)(MSIDWebviewNavigationDecision * _Nullable decision,
                                                                  NSError * _Nullable error))completion
{
    [self.navigationHandler performASWebAuthenticationHandoffWithParentController:self.interactiveRequestParamaters.parentViewController
                                                                       completion:completion];
}
#endif // !MSID_EXCLUDE_SYSTEMWV
#endif // !MSID_EXCLUDE_WEBKIT

static NSString * const kMSIDMicrosoft1PTeamIdIosA   = @"SGGM6D27TK";
static NSString * const kMSIDMicrosoft1PTeamIdIosB   = @"9KBH5RKYEW";

// Returns YES iff the currently-running process is signed by Microsoft.
// Result is cached (Team ID does not change during process lifetime).
static BOOL MSIDIsMicrosoft1PHostProcess(void)
{
    static BOOL isMicrosoft1P = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *teamId = [MSIDKeychainUtil sharedInstance].teamId;
        if (teamId.length == 0) return;

        NSSet<NSString *> *allowedTeamIds = [NSSet setWithObjects:
                                             kMSIDMicrosoft1PTeamIdIosA,
                                             kMSIDMicrosoft1PTeamIdIosB,
                                             nil];
        isMicrosoft1P = [allowedTeamIds containsObject:teamId];
    });
    return isMicrosoft1P;
}
@end
