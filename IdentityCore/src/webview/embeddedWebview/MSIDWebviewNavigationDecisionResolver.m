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

#if !MSID_EXCLUDE_WEBKIT
- (MSIDWebviewNavigationDecision *)resolveDecisionForURL:(NSURL * _Nullable)URL
                                       webviewController:(nullable id<MSIDWebviewInteracting>)webviewController
                                         responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                                 appName:(NSString *)appName
                                              appVersion:(NSString *)appVersion
                                 externalNavigationBlock:(nullable MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Validate required parameters
    if (!URL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve: URL is nil.");
        return nil;
    }
    
    NSString *scheme = URL.scheme.lowercaseString;
    
    if (!scheme || scheme.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve: URL scheme is missing or empty. URL: %@", MSID_PII_LOG_MASKABLE(URL));
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Resolving decision for scheme '%@'.", scheme);
    
    // Route based on scheme
    if ([scheme isEqualToString:MSID_SCHEME_MSAUTH])
    {
        // Handle msauth:// URLs
        return [self handleMSAuthURL:URL
                   webviewController:webviewController
                     responseHeaders:responseHeaders
                             appName:appName
                          appVersion:appVersion
             externalNavigationBlock:externalNavigationBlock];
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
                                 webviewController:(id<MSIDWebviewInteracting>)webviewController
                                   responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                           appName:(NSString *)appName
                                        appVersion:(NSString *)appVersion
                           externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    NSString *host = URL.host.lowercaseString;
    
    // Validate host
    if (!host || host.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[NavDecision] Cannot resolve 'msauth' URL: host is missing or empty. URL: %@", MSID_PII_LOG_MASKABLE(URL));
        return nil;
    }
    
    // Parse query parameters
    NSDictionary<NSString *, NSString *> *params = [URL msidQueryParameters];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Resolving decision for msauth host '%@'.", host);
    
    // Route based on host
    if ([host isEqualToString:MSID_MDM_ENROLL_HOST])
    {
        return [self decisionForEnrollURL:params
                                  appName:appName
                               appVersion:appVersion];
    }
    if ([host isEqualToString:MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST])
    {
        return [self decisionForProfileDownloadComplete:params];
    }
    else if ([host isEqualToString:MSID_COMPLIANCE_HOST])
    {
        return [self decisionForComplianceURL:webviewController
                                       params:params
                      externalNavigationBlock:externalNavigationBlock];
    }
    else if ([host isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_HOST])
    {
        return [self decisionForEnrollmentCompletionURL:URL
                                                 params:params];
    }
    else
    {
        // Unknown host - continue with default decision
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[NavDecision] Unhandled msauth host '%@'; continuing with default decision.", host);
        return [MSIDWebviewNavigationDecision continueDefault];
    }
}

#endif // !MSID_EXCLUDE_WEBKIT

#pragma mark - URL Decision Resolvers

- (MSIDWebviewNavigationDecision *)decisionForEnrollURL:(NSDictionary *)params
                                                appName:(NSString *)appName
                                             appVersion:(NSString *)appVersion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] Building enrollment request from msauth redirect.");

    // Extract intuneUrl from query parameters
    NSString *intuneURLString = params[MSID_INTUNE_URL_KEY];
    if (!intuneURLString || intuneURLString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Enroll] Missing required parameter '%@' in msauth enrollment URL.", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         [NSString stringWithFormat:@"Missing required parameter '%@' in enrollment URL", MSID_INTUNE_URL_KEY],
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the intuneURL in case it's percent-encoded
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Enroll] Failed to percent-decode '%@'; falling back to raw value.", MSID_INTUNE_URL_KEY);
        decodedIntuneURL = intuneURLString;
    }
    
    // Build query parameters for enrollment
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    // Add enrollment-specific parameters
    allQueryParams[MSID_IN_APP_KEY] = @"true";
    allQueryParams[@"webauthn"] = @"1";
    
    // Add any additional params from original msauth URL (excluding intuneUrl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:MSID_INTUNE_URL_KEY])
        {
            allQueryParams[key] = params[key];
        }
    }

    // Re-attach intuneDeviceId from keychain if it was captured during a prior
    // profile download complete redirect and is not already present in the URL.
    if (![allQueryParams objectForKey:MSID_INTUNE_DEVICE_ID_KEY])
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

    // Prepare additional headers for enrollment
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    
    // Add headers
    if (appName && appName.length > 0)
    {
        additionalHeaders[MSID_APP_NAME_KEY] = appName;
    }
    
    if (appVersion && appVersion.length > 0)
    {
        additionalHeaders[MSID_APP_VER_KEY] = appVersion;
    }
    
    // Build the final request with all query params and headers
    NSURLRequest *request = [self buildRequestForURL:decodedIntuneURL
                                        extraHeaders:additionalHeaders
                                         extraParams:allQueryParams];
    
    if (!request)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Enroll] Failed to build enrollment request from intuneUrl: %@", MSID_PII_LOG_MASKABLE(decodedIntuneURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Failed to construct enrollment request URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Enroll] Built enrollment request for host '%@'.", request.URL.host);
    return [MSIDWebviewNavigationDecision loadRequest:request];
}

- (MSIDWebviewNavigationDecision *)decisionForProfileDownloadComplete:(NSDictionary *)params
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Processing MDM profile download completion redirect.");

    // Extract intuneDeviceId from query parameters
    NSString *intuneDeviceId = params[MSID_INTUNE_DEVICE_ID_KEY];
    if (!intuneDeviceId || intuneDeviceId.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[ProfileDownload] Missing Intune device ID '%@' in profile download completion redirect.", MSID_INTUNE_DEVICE_ID_KEY);
    }

    // Persist intuneDeviceId in keychain so it can be re-attached to the
    // subsequent enrollment request if the MDM profile installation is interrupted.
    NSError *cacheError = nil;
    if (![[MSIDIntuneDeviceIdCache sharedCache] setIntuneDeviceId:intuneDeviceId
                                                          context:nil
                                                            error:&cacheError])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                          @"[ProfileDownload] Failed to cache intuneDeviceId; continuing with profile download. Error: %@",
                          MSID_PII_LOG_MASKABLE(cacheError));
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Cached intuneDeviceId for subsequent enrollment.");
    }

    // Extract profileInstallUrl from query parameters
    NSString *profileInstallURL = params[MSID_INTUNE_PROFILE_INSTALL_URL_KEY];
    if (!profileInstallURL || profileInstallURL.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[ProfileDownload] Missing required parameter '%@' in profile download completion redirect.", MSID_INTUNE_PROFILE_INSTALL_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         [NSString stringWithFormat:@"Missing required parameter '%@' in profile download completion redirect.", MSID_INTUNE_PROFILE_INSTALL_URL_KEY],
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the profile install URL in case it's percent-encoded
    NSString *decodedProfileInstallURL = [profileInstallURL stringByRemovingPercentEncoding];
    if (!decodedProfileInstallURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[ProfileDownload] Failed to percent-decode '%@'; falling back to raw value.", MSID_INTUNE_PROFILE_INSTALL_URL_KEY);
        decodedProfileInstallURL = profileInstallURL;
    }
    
    // TODO: Add any additional headers or parameters needed for profile installation request
    
    NSURL *profileURL = [NSURL URLWithString:decodedProfileInstallURL];
    if (!profileURL || !profileURL.scheme.length || !profileURL.host.length)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[ProfileDownload] Profile install URL is malformed (missing scheme or host). URL: %@", MSID_PII_LOG_MASKABLE(decodedProfileInstallURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Invalid profile install URL: missing scheme or host",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[ProfileDownload] Built profile install request for host '%@'.", profileURL.host);
    return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:profileURL]];
}


- (MSIDWebviewNavigationDecision *)decisionForEnrollmentCompletionURL:(NSURL *)URL
                                                               params:(NSDictionary *)params
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] Processing enrollment completion redirect.");

    // Check if SSO extension can perform request
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] SSO extension available; completing web auth with enrollment completion URL.");
        return [MSIDWebviewNavigationDecision completeWithURL:URL];
    }
    
    // SSO extension not available - load error URL if provided
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[EnrollmentCompletion] SSO extension is not available; attempting fallback error URL.");
    
    NSString *errorUrlString = params[MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY];
    
    if (errorUrlString && errorUrlString.length > 0)
    {
        // URL decode the errorUrl in case it's percent-encoded
        NSString *decodedErrorUrlString = [errorUrlString stringByRemovingPercentEncoding];
        if (!decodedErrorUrlString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[EnrollmentCompletion] Failed to percent-decode '%@'; falling back to raw value.", MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY);
            decodedErrorUrlString = errorUrlString;
        }
        
        NSURL *errorURL = [NSURL URLWithString:decodedErrorUrlString];
        if (errorURL)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[EnrollmentCompletion] Loading fallback error URL in webview (host: '%@').", errorURL.host);
            return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:errorURL]];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[EnrollmentCompletion] Fallback error URL is not parseable: %@", MSID_PII_LOG_MASKABLE(decodedErrorUrlString));
        }
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[EnrollmentCompletion] No fallback error URL ('%@') provided in redirect.", MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY);
    }
    
    // No valid error URL - return error decision
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal,
                                     @"SSO extension is not available and no valid fallback error URL was provided for enrollment completion",
                                     nil, nil, nil, nil, nil, YES);
    return [MSIDWebviewNavigationDecision failWithError:error];
}

#if !MSID_EXCLUDE_WEBKIT
- (MSIDWebviewNavigationDecision *)decisionForComplianceURL:(id<MSIDWebviewInteracting>)webviewController
                                                     params:(NSDictionary *)params
                                    externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Building compliance request from msauth redirect.");

    // Extract intuneUrl from query parameters
    NSString *intuneURLString = params[MSID_INTUNE_URL_KEY];
    if (!intuneURLString || intuneURLString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Compliance] Missing required parameter '%@' in msauth compliance URL.", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         [NSString stringWithFormat:@"Missing required parameter '%@' in compliance URL", MSID_INTUNE_URL_KEY],
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"[Compliance] Failed to percent-decode '%@'; falling back to raw value.", MSID_INTUNE_URL_KEY);
        decodedIntuneURL = intuneURLString;
    }
    
    // Build query parameters for compliance check
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    // Add any additional params from original msauth URL (excluding intuneUrl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:MSID_INTUNE_URL_KEY])
        {
            allQueryParams[key] = params[key];
        }
    }
    
    // Build the final request with all query params
    NSURLRequest *request = [self buildRequestForURL:decodedIntuneURL
                                        extraHeaders:nil  // TODO: Add additional compliance-specific headers if needed
                                         extraParams:allQueryParams];
    
    if (!request)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[Compliance] Failed to build compliance request from intuneUrl: %@", MSID_PII_LOG_MASKABLE(decodedIntuneURL));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Failed to construct compliance request URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // Handle external navigation if block is provided
    if (externalNavigationBlock && webviewController)
    {
        NSString *requestURLString = request.URL.absoluteString;
        
        // Check if URL uses https scheme
        if (requestURLString.length > 5 &&
            [[requestURLString substringToIndex:5].lowercaseString isEqualToString:@"https"])
        {
            // Replace 'https' scheme with 'browser' scheme for legacy flow
            NSString *browserSchemeURL = [NSString stringWithFormat:@"browser%@", [requestURLString substringFromIndex:5]];
            NSURL *legacyFlowUrl = [NSURL URLWithString:browserSchemeURL];
            
            if (legacyFlowUrl)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Invoking external navigation block with 'browser' scheme (host: '%@').", legacyFlowUrl.host);
                
                // Call external navigation block with legacy flow URL
                // Note: The block is responsible for type checking and casting
                NSURLRequest *updatedRequest = externalNavigationBlock((MSIDOAuth2EmbeddedWebviewController *)webviewController, legacyFlowUrl);
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
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Compliance] Built compliance request for host '%@'.", request.URL.host);
    return [MSIDWebviewNavigationDecision loadRequest:request];
}

#endif // !MSID_EXCLUDE_WEBKIT

#pragma mark - Helper Methods

- (nullable NSURLRequest *)buildRequestForURL:(NSString *)URLString
                                 extraHeaders:(nullable NSDictionary<NSString *, NSString *> *)extraHeaders
                                  extraParams:(nullable NSDictionary<NSString *, NSString *> *)extraParams
{
    // Validate input URL string
    if (!URLString || URLString.length == 0)
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
    
    // Add query parameters if provided
    if (extraParams && extraParams.count > 0)
    {
        NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
        
        // Keep existing query items from the URL
        if (components.queryItems)
        {
            [queryItems addObjectsFromArray:components.queryItems];
        }
        
        // Add new query items
        for (NSString *key in extraParams)
        {
            NSString *value = extraParams[key];
            if (key && value) // Ensure both key and value are non-nil
            {
                NSURLQueryItem *item = [NSURLQueryItem queryItemWithName:key value:value];
                [queryItems addObject:item];
            }
        }
        
        components.queryItems = queryItems;
    }
    
    // Create URL from components
    NSURL *finalURL = components.URL;
    if (!finalURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"[NavDecision] buildRequestForURL: failed to assemble final URL from components.");
        return nil;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:finalURL];
    
    // Add headers if provided
    if (extraHeaders && extraHeaders.count > 0)
    {
        for (NSString *key in extraHeaders)
        {
            NSString *value = extraHeaders[key];
            if (key && value) // Ensure both key and value are non-nil
            {
                [request setValue:value forHTTPHeaderField:key];
            }
        }
    }
    
    return request;
}

@end
