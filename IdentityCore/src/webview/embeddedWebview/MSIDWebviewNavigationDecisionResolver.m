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

#import "MSIDWebviewNavigationDecisionResolver.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDWebviewConstants.h"
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#import "MSIDConstants.h"
#import "MSIDIntuneDeviceIdCache.h"
#import "MSIDOnboardingBlobFieldKeys.h"
#import "MSIDVersion.h"
#import "MSIDUXCallbackProvider.h"
#import "MSIDFlightManager.h"
#import "MSIDOnboardingBlobBuilder.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDHelpers.h"
#import "NSBundle+MSIDExtensions.h"

#if !MSID_EXCLUDE_WEBKIT

@implementation MSIDWebviewNavigationDecisionResolver

+ (instancetype)sharedInstance
{
    static MSIDWebviewNavigationDecisionResolver *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MSIDWebviewNavigationDecisionResolver alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Public API

- (MSIDWebviewNavigationDecision * _Nullable)resolveDecisionForURL:(NSURL * _Nullable)URL
                                         embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
{
    return [self resolveDecisionForURL:URL
             embeddedWebviewController:embeddedWebviewController
                         brokerVersion:nil];
}

- (MSIDWebviewNavigationDecision * _Nullable)resolveDecisionForURL:(NSURL * _Nullable)URL
                                         embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                                                     brokerVersion:(NSString * _Nullable)brokerVersion
{
    if (!URL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve: URL is nil.");
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Cannot resolve navigation decision: URL is nil.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    NSString *scheme = URL.scheme.lowercaseString;

    if (scheme.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve: URL scheme is missing or empty. URL: %@", MSID_PII_LOG_MASKABLE(URL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Cannot resolve navigation decision: URL scheme is missing or empty.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Resolving decision for scheme '%@'.", scheme);
    
    // Route based on scheme
    if ([scheme isEqualToString:MSID_SCHEME_MSAUTH])
    {
        // Handle msauth:// URLs
        return [self handleMSAuthURL:URL
           embeddedWebviewController:embeddedWebviewController
                       brokerVersion:brokerVersion];
    }
    else if ([scheme isEqualToString:MSID_SCHEME_BROWSER])
    {
        // Handle browser:// URLs - use default decision for legacy browser flow
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] 'browser' scheme detected; continuing with default decision.");
        return [MSIDWebviewNavigationDecision continueDefault];
    }
    else
    {
        // Unknown scheme - continue with default decision
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Unhandled scheme '%@'; continuing with default decision.", scheme);
        return [MSIDWebviewNavigationDecision continueDefault];
    }
}

#pragma mark - Scheme Handlers

- (MSIDWebviewNavigationDecision *)handleMSAuthURL:(NSURL *)URL
                         embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                                     brokerVersion:(NSString * _Nullable)brokerVersion
{
    NSString *host = URL.host.lowercaseString;

    // Validate host
    if (host.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve 'msauth' URL: host is missing or empty. URL: %@", MSID_PII_LOG_MASKABLE(URL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Cannot resolve 'msauth' URL: host is missing or empty.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // Parse query parameters
    NSDictionary<NSString *, NSString *> *params = [URL msidQueryParameters];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Resolving decision for msauth host '%@'.", host);
    
    // Route based on host
    if ([host isEqualToString:MSID_MDM_ENROLL_HOST])
    {
        return [self decisionForEnrollURL:params
                embeddedWebviewController:embeddedWebviewController
                            brokerVersion:brokerVersion];
    }
    else if ([host isEqualToString:MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST])
    {
        return [self decisionForProfileDownloadComplete:params
                              embeddedWebviewController:embeddedWebviewController];
    }
    else if ([host isEqualToString:MSID_COMPLIANCE_HOST])
    {
        return [self decisionForComplianceURL:params
                    embeddedWebviewController:embeddedWebviewController];
    }
    else if ([host isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_HOST])
    {
        return [self decisionForEnrollmentCompletionURL:URL
                                                 params:params
                              embeddedWebviewController:embeddedWebviewController];
    }
    else
    {
        // Unknown host - continue with default decision
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Unhandled msauth host '%@'; continuing with default decision.", host);
        return [MSIDWebviewNavigationDecision continueDefault];
    }
}

#pragma mark - URL Decision Resolvers

- (MSIDWebviewNavigationDecision *)decisionForEnrollURL:(NSDictionary *)params
                             embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                                         brokerVersion:(NSString * _Nullable)brokerVersion
{
    MSIDOnboardingBlobBuilder *onboardingBlobBuilder = embeddedWebviewController.onboardingBlobBuilder;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] Building enrollment request from msauth redirect.");

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    // Extract intuneUrl from query parameters (fatal if missing).
    NSString *intuneURLString = [params[MSID_INTUNE_URL_KEY] stringByTrimmingCharactersInSet:whitespace];
    if (intuneURLString.length == 0)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepMdmEnrollmentUrlMissing timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Enroll] Missing required intuneUrl parameter in msauth enrollment URL.");
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing required intuneUrl parameter in enrollment URL.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    // URL-decode in case the value is percent-encoded; fall back to raw value on failure.
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Enroll] Failed to percent-decode intuneUrl; falling back to raw value.");
        decodedIntuneURL = intuneURLString;
    }

    // Build query parameters for enrollment.
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];

    // Add enrollment-specific parameters.
    allQueryParams[MSID_IN_APP_KEY] = @"true";
    allQueryParams[@"webauthn"] = @"1";

    // Copy additional params from the original msauth URL (excluding intuneUrl itself).
    for (NSString *key in params)
    {
        if (![key isEqualToString:MSID_INTUNE_URL_KEY])
        {
            allQueryParams[key] = params[key];
        }
    }

    // Re-attach intuneDeviceId from keychain if it was captured during a prior
    // profile download complete redirect and is not already present in the URL.
    if (!allQueryParams[MSID_INTUNE_DEVICE_ID_KEY])
    {
        NSError *cacheReadError = nil;
        NSString *cachedDeviceId = [[MSIDIntuneDeviceIdCache sharedCache] intuneDeviceIdWithContext:nil
                                                                                              error:&cacheReadError];
        if (cacheReadError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil,
                              @"[Enroll] Failed to read cached intuneDeviceId; proceeding without it. Error: %@",
                              MSID_PII_LOG_MASKABLE(cacheReadError));
        }

        if (cachedDeviceId.length > 0)
        {
            allQueryParams[MSID_INTUNE_DEVICE_ID_KEY] = cachedDeviceId;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] Attached cached intuneDeviceId to enrollment request.");
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] No cached intuneDeviceId available; proceeding without it.");
        }
    }

    // Prepare additional headers for enrollment.
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];

    NSString *platformName = [MSIDVersion platformName];
    if (platformName.length > 0)
    {
        additionalHeaders[MSID_PLATFORM_KEY] = platformName;
    }

    NSString *sdkVersion = [MSIDVersion sdkVersion];
    if (sdkVersion.length > 0)
    {
        additionalHeaders[MSID_VERSION_KEY] = sdkVersion;
    }

    if (brokerVersion.length > 0)
    {
        additionalHeaders[MSID_BROKER_VER_KEY] = brokerVersion;
    }

    // For Microsoft first-party apps, forward the app identity to Intune so it can
    // attribute the enrollment request to the originating app.
    if ([MSIDHelpers isMicrosoftFirstPartyApp])
    {
        NSString *appName = [NSBundle msidAppName];
        if (appName.length > 0)
        {
            additionalHeaders[MSID_APP_NAME_KEY] = appName;
        }

        NSString *appVersion = [NSBundle msidAppVersion];
        if (appVersion.length > 0)
        {
            additionalHeaders[MSID_APP_VER_KEY] = appVersion;
        }
    }

    // Build the final request with all query params and headers.
    NSURLRequest *request = [self buildRequestForURL:decodedIntuneURL
                                        extraHeaders:additionalHeaders
                                         extraParams:allQueryParams];

    if (!request)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepMdmEnrollmentRequestMalformed timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Enroll] Failed to build enrollment request from intuneUrl: %@", MSID_PII_LOG_MASKABLE(decodedIntuneURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Failed to construct enrollment request URL.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepMdmEnrollmentStarted timestamp:[NSDate date]];
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] Built enrollment request for host '%@'.", request.URL.host);
    return [MSIDWebviewNavigationDecision loadRequest:request];
}

- (MSIDWebviewNavigationDecision *)decisionForProfileDownloadComplete:(NSDictionary *)params
                                           embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
{
    MSIDOnboardingBlobBuilder *onboardingBlobBuilder = embeddedWebviewController.onboardingBlobBuilder;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Processing MDM profile download completion redirect.");

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    // Extract and cache intuneDeviceId (non-fatal if missing: enrollment can recover server-side).
    NSString *intuneDeviceId = [params[MSID_INTUNE_DEVICE_ID_KEY] stringByTrimmingCharactersInSet:whitespace];
    if (intuneDeviceId.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[ProfileDownload] Missing Intune device ID in profile download completion redirect.");
    }
    else
    {
        // Persist intuneDeviceId in keychain so it can be re-attached to the
        // subsequent enrollment request if the MDM profile installation is interrupted.
        NSError *cacheError = nil;
        BOOL cached = [[MSIDIntuneDeviceIdCache sharedCache] setIntuneDeviceId:intuneDeviceId
                                                                      context:nil
                                                                        error:&cacheError];
        if (!cached)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                              @"[ProfileDownload] Failed to cache intuneDeviceId; continuing with profile download. Error: %@",
                              MSID_PII_LOG_MASKABLE(cacheError));
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Cached intuneDeviceId for subsequent enrollment.");
        }
    }

    // Extract profileInstallUrl (fatal if missing).
    NSString *profileInstallURL = [params[MSID_INTUNE_PROFILE_INSTALL_URL_KEY] stringByTrimmingCharactersInSet:whitespace];
    if (profileInstallURL.length == 0)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepProfileInstallUrlMissing timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[ProfileDownload] Missing required profile install URL in profile download completion redirect.");
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing required profile install URL in profile download completion redirect.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    // URL-decode in case the value is percent-encoded; fall back to raw value on failure.
    NSString *decodedProfileInstallURL = [profileInstallURL stringByRemovingPercentEncoding];
    if (!decodedProfileInstallURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[ProfileDownload] Failed to percent-decode profile install URL; falling back to raw value.");
        decodedProfileInstallURL = profileInstallURL;
    }

    // TODO: Add any additional headers or parameters needed for the profile installation request.

    NSURL *profileURL = [NSURL URLWithString:decodedProfileInstallURL];
    if (!profileURL || profileURL.scheme.length == 0 || profileURL.host.length == 0)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepProfileInstallUrlMalformed timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                          @"[ProfileDownload] Profile install URL is malformed (missing scheme or host). URL: %@",
                          MSID_PII_LOG_MASKABLE(decodedProfileInstallURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Invalid profile install URL: missing scheme or host.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Built profile install request for host '%@'.", profileURL.host);

    NSString *delayString = [[MSIDFlightManager sharedInstance] stringForKey:MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY];
    NSTimeInterval delay = delayString.length > 0 ? delayString.doubleValue : MSIDMDMProfileInstalledNotificationDefaultDelay;
    if (delay <= 0)
    {
        delay = MSIDMDMProfileInstalledNotificationDefaultDelay;
    }

    id<MSIDUXCallbackProtocol> provider = MSIDUXCallbackProvider.uxCallbackProvider;
    if (provider)
    {
        [provider scheduleMDMProfileInstalledNotificationWithDelay:delay];
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepProfileInstallNotificationScheduled timestamp:[NSDate date]];
    }

    [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepProfileDownloadCompleted timestamp:[NSDate date]];
    return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:profileURL]];
}


- (MSIDWebviewNavigationDecision *)decisionForEnrollmentCompletionURL:(NSURL *)URL
                                                               params:(NSDictionary *)params
                                           embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
{
    MSIDOnboardingBlobBuilder *onboardingBlobBuilder = embeddedWebviewController.onboardingBlobBuilder;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] Processing enrollment completion redirect.");

    // Cancel any previously scheduled MDM profile installed notification
    id<MSIDUXCallbackProtocol> provider = MSIDUXCallbackProvider.uxCallbackProvider;
    if (provider)
    {
        [provider cancelMDMProfileInstalledNotification];
    }

    // Check if SSO extension can perform request
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] SSO extension available; completing web auth with enrollment completion URL.");
        return [MSIDWebviewNavigationDecision completeWithURL:URL];
    }
    
    // SSO extension not available - load error URL if provided.
    [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepSSOExtensionUnavailable timestamp:[NSDate date]];
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[EnrollmentCompletion] SSO extension is not available; attempting fallback error URL.");

    NSString *errorUrlString = [params[MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY]
                                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (errorUrlString.length > 0)
    {
        // URL-decode in case the value is percent-encoded; fall back to raw value on failure.
        NSString *decodedErrorUrlString = [errorUrlString stringByRemovingPercentEncoding];
        if (!decodedErrorUrlString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[EnrollmentCompletion] Failed to percent-decode fallback error URL; falling back to raw value.");
            decodedErrorUrlString = errorUrlString;
        }

        NSURL *errorURL = [NSURL URLWithString:decodedErrorUrlString];
        if (errorURL)
        {
            [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepMdmEnrollmentCompletionRetryStarted timestamp:[NSDate date]];
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] Loading fallback error URL in webview (host: '%@').", errorURL.host);
            return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:errorURL]];
        }

        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[EnrollmentCompletion] Fallback error URL is not parseable: %@", MSID_PII_LOG_MASKABLE(decodedErrorUrlString));
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[EnrollmentCompletion] No fallback error URL provided in redirect.");
    }

    // No valid error URL - return error decision.
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal,
                                     @"SSO extension is not available and no valid fallback error URL was provided for enrollment completion.",
                                     nil, nil, nil, nil, nil, YES);
    return [MSIDWebviewNavigationDecision failWithError:error];
}

- (MSIDWebviewNavigationDecision *)decisionForComplianceURL:(NSDictionary *)params
                                  embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
{
    MSIDOnboardingBlobBuilder *onboardingBlobBuilder = embeddedWebviewController.onboardingBlobBuilder;
    [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepComplianceRemediationMSAuthRedirect timestamp:[NSDate date]];
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Building compliance request from msauth redirect.");

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    // Extract intuneUrl from query parameters (fatal if missing).
    NSString *intuneURLString = [params[MSID_INTUNE_URL_KEY] stringByTrimmingCharactersInSet:whitespace];
    if (intuneURLString.length == 0)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepComplianceRemediationUrlMissing timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Compliance] Missing required intuneUrl parameter in msauth compliance URL.");
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing required intuneUrl parameter in compliance URL.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    // URL-decode in case the value is percent-encoded; fall back to raw value on failure.
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Compliance] Failed to percent-decode intuneUrl; falling back to raw value.");
        decodedIntuneURL = intuneURLString;
    }

    // Build query parameters for compliance check (copy all params except intuneUrl itself).
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    for (NSString *key in params)
    {
        if (![key isEqualToString:MSID_INTUNE_URL_KEY])
        {
            allQueryParams[key] = params[key];
        }
    }

    // Build the final request with all query params.
    NSURLRequest *request = [self buildRequestForURL:decodedIntuneURL
                                        extraHeaders:nil  // TODO: Add compliance-specific headers if needed.
                                         extraParams:allQueryParams];

    if (!request)
    {
        [onboardingBlobBuilder addStep:MSIDOnboardingBlobStepComplianceRemediationRequestMalformed timestamp:[NSDate date]];
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Compliance] Failed to build compliance request from intuneUrl: %@", MSID_PII_LOG_MASKABLE(decodedIntuneURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Failed to construct compliance request URL.",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    // For legacy flows we rewrite the request URL's `https` scheme to `browser`
    // and let the external navigation block decide whether to override the request.
    if (embeddedWebviewController && embeddedWebviewController.externalDecidePolicyForBrowserAction &&
        [request.URL.scheme.lowercaseString isEqualToString:@"https"])
    {
        NSURLComponents *legacyComponents = [NSURLComponents componentsWithURL:request.URL
                                                       resolvingAgainstBaseURL:NO];
        legacyComponents.scheme = @"browser";
        NSURL *legacyFlowUrl = legacyComponents.URL;

        if (legacyFlowUrl)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Invoking external navigation block with 'browser' scheme (host: '%@').", legacyFlowUrl.host);

            // The block is responsible for type checking and casting the controller.
            NSURLRequest *updatedRequest = embeddedWebviewController.externalDecidePolicyForBrowserAction(embeddedWebviewController, legacyFlowUrl);
            if (updatedRequest)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] External navigation block returned overridden request (host: '%@').", updatedRequest.URL.host);
                return [MSIDWebviewNavigationDecision loadRequest:updatedRequest];
            }
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Compliance] Failed to build legacy 'browser' scheme URL; skipping external navigation.");
        }
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Built compliance request for host '%@'.", request.URL.host);
    return [MSIDWebviewNavigationDecision loadRequest:request];
}

#pragma mark - Helper Methods

- (nullable NSURLRequest *)buildRequestForURL:(NSString *)URLString
                                 extraHeaders:(nullable NSDictionary<NSString *, NSString *> *)extraHeaders
                                  extraParams:(nullable NSDictionary<NSString *, NSString *> *)extraParams
{
    // Validate input URL string.
    if (URLString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[NavDecision] buildRequestForURL: URL string is nil or empty.");
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:URLString];
    if (!components)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[NavDecision] buildRequestForURL: failed to parse URL components from string: %@", MSID_PII_LOG_MASKABLE(URLString));
        return nil;
    }

    // Append additional query parameters while preserving any existing ones.
    if (extraParams.count > 0)
    {
        NSMutableArray<NSURLQueryItem *> *queryItems =
            [NSMutableArray arrayWithArray:components.queryItems ?: @[]];

        for (NSString *key in extraParams)
        {
            NSString *value = extraParams[key];
            if (key.length > 0 && value != nil)
            {
                [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:value]];
            }
        }

        components.queryItems = queryItems;
    }

    // Create the final URL from components.
    NSURL *finalURL = components.URL;
    if (!finalURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[NavDecision] buildRequestForURL: failed to assemble final URL from components.");
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:finalURL];

    // Apply additional headers, if any.
    if (extraHeaders.count > 0)
    {
        for (NSString *key in extraHeaders)
        {
            NSString *value = extraHeaders[key];
            if (key.length > 0 && value != nil)
            {
                [request setValue:value forHTTPHeaderField:key];
            }
        }
    }

    return request;
}

@end

#endif // !MSID_EXCLUDE_WEBKIT
