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
- (MSIDWebviewNavigationDecision *)resolveDecisionForURL:(NSURL *)URL
                                       webviewController:(id<MSIDWebviewInteracting>)webviewController
                                         responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                                 appName:(NSString *)appName
                                              appVersion:(NSString *)appVersion
                                 externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Validate required parameters
    if (!URL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot resolve navigation decision: URL is nil");
        return nil;
    }
    
    NSString *scheme = URL.scheme.lowercaseString;
    
    if (!scheme || scheme.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot resolve navigation decision: URL scheme is nil or empty");
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Resolving navigation decision for special redirect URL with scheme: %@", scheme);
    
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
        // Handle browser:// URLs - use default action for legacy browser flow
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Browser scheme detected, continuing with default action");
        return [MSIDWebviewNavigationDecision continueDefault];
    }
    else
    {
        // Unknown scheme - continue with default behavior
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Unknown special redirect scheme: %@, continuing with default action", scheme);
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
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to resolve navigation decision: 'msauth' URL has empty or missing host. URL: %@", URL);
        return nil;
    }
    
    // Parse query parameters
    NSDictionary<NSString *, NSString *> *params = [URL msidQueryParameters];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Resolving action for msauth URL with host: %@", host);
    
    // Route based on host
    if ([host isEqualToString:MSID_MDM_ENROLL_HOST])
    {
        return [self actionForEnrollURL:params
                                appName:appName
                             appVersion:appVersion];
    }
    if ([host isEqualToString:MSID_MDM_PROFILE_DOWNLOAD_COMPLETE_HOST])
    {
        return [self actionForProfileDownloadComplete:params
        ];
    }
    else if ([host isEqualToString:MSID_COMPLIANCE_HOST])
    {
        return [self actionForComplianceURL:webviewController
                                     params:params
                    externalNavigationBlock:externalNavigationBlock];
    }
    else if ([host isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_HOST])
    {
        return [self actionForEnrollmentCompletionURL:URL
                                               params:params];
    }
    else
    {
        // Unknown host - continue with default behavior
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Unknown msauth host: %@, continuing with default action", host);
        return [MSIDWebviewNavigationDecision continueDefault];
    }
}

#endif // !MSID_EXCLUDE_WEBKIT

#pragma mark - URL Action Resolvers

- (MSIDWebviewNavigationDecision *)actionForEnrollURL:(NSDictionary *)params
                                              appName:(NSString *)appName
                                           appVersion:(NSString *)appVersion
{
    // Extract intuneUrl from query parameters
    NSString *intuneURLString = params[MSID_INTUNE_URL_KEY];
    if (!intuneURLString || intuneURLString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Enroll URL missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing intuneRedirectUrl parameter in enrollment URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the intuneURL in case it's percent-encoded
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode intuneUrl, using original value");
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
                              @"Failed to read cached intuneDeviceId: %@", MSID_PII_LOG_MASKABLE(cacheReadError));
        }
        if (cachedDeviceId.length > 0)
        {
            allQueryParams[MSID_INTUNE_DEVICE_ID_KEY] = cachedDeviceId;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Attached cached intuneDeviceId to enroll request.");
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to build enrollment request for URL: %@", decodedIntuneURL);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Failed to construct enrollment request URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Created enrollment request for URL: %@", request.URL);
    return [MSIDWebviewNavigationDecision loadRequest:request];
}

- (MSIDWebviewNavigationDecision *)actionForProfileDownloadComplete:(NSDictionary *)params
{
    // Extract intuneDeviceId from query parameters
    NSString *intuneDeviceId = params[MSID_INTUNE_DEVICE_ID_KEY];
    if (!intuneDeviceId || intuneDeviceId.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Intune deviceId is missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing intuneDeviceId parameter in enrollment URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }

    // Persist intuneDeviceId in keychain so it can be re-attached to the
    // subsequent enrollment request if the MDM profile installation interrupted
    NSError *cacheError = nil;
    if (![[MSIDIntuneDeviceIdCache sharedCache] setIntuneDeviceId:intuneDeviceId
                                                          context:nil
                                                            error:&cacheError])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil,
                          @"Failed to cache intuneDeviceId: %@", MSID_PII_LOG_MASKABLE(cacheError));
        // continue with profile download.
    }

    // Extract profileInstallUrl from query parameters
    NSString *profileInstallURL = params[MSID_INTUNE_PROFILE_INSTALL_URL_KEY];
    if (!profileInstallURL || profileInstallURL.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Profile install URL is missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing profileInstallUrl parameter in enrollment URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedProfileInstallURL = [profileInstallURL stringByRemovingPercentEncoding];
    if (!decodedProfileInstallURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode intuneURL, using original value");
        decodedProfileInstallURL = profileInstallURL;
    }
    
    // TODO: Add any additional headers or parameters needed for profile installation request
    
    NSURL *profileURL = [NSURL URLWithString:decodedProfileInstallURL];
    if (!profileURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create valid NSURL from profile install URL string");
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Invalid profile install URL: could not parse URL string",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Created enrollment request for URL: %@", decodedProfileInstallURL);
    return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:profileURL]];
}


- (MSIDWebviewNavigationDecision *)actionForEnrollmentCompletionURL:(NSURL *)URL
                                                             params:(NSDictionary *)params
{
    // Check if SSO extension can perform request
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"SSO extension available, completing web auth with enrollment completion URL");
        
        // If enrollment completed successfully, drop the cached intuneDeviceId so it is not
        // accidentally attach a stale value to a future enroll request.
        [[MSIDIntuneDeviceIdCache sharedCache] clear];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Cleared cached intuneDeviceId after successful enrollment.");
        
        return [MSIDWebviewNavigationDecision completeWithURL:URL];
    }
    
    // SSO extension not available - load error URL if provided
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"SSO extension not available for enrollment completion");
    
    NSString *errorUrlString = params[MSID_MDM_ENROLLMENT_COMPLETION_ERROR_URL_KEY];
    
    if (errorUrlString && errorUrlString.length > 0)
    {
        // URL decode the errorUrl in case it's percent-encoded
        NSString *decodedErrorUrlString = [errorUrlString stringByRemovingPercentEncoding];
        if (!decodedErrorUrlString)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode error URL, using original value");
            decodedErrorUrlString = errorUrlString;
        }
        
        NSURL *errorURL = [NSURL URLWithString:decodedErrorUrlString];
        if (errorURL)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Loading error URL in webview: %@", errorURL);
            return [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:errorURL]];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Invalid error URL format: %@", decodedErrorUrlString);
        }
    }
    
    // No valid error URL - return error action
    NSError *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorInternal,
                                     @"SSO extension is not available and no valid error URL provided for enrollment completion",
                                     nil, nil, nil, nil, nil, YES);
    return [MSIDWebviewNavigationDecision failWithError:error];
}

#if !MSID_EXCLUDE_WEBKIT
- (MSIDWebviewNavigationDecision *)actionForComplianceURL:(id<MSIDWebviewInteracting>)webviewController
                                                   params:(NSDictionary *)params
                                  externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Extract intuneUrl from query parameters
    NSString *intuneURLString = params[MSID_INTUNE_URL_KEY];
    if (!intuneURLString || intuneURLString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Compliance URL missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorInvalidInternalParameter,
                                         @"Missing intuneRedirectUrl parameter in compliance URL",
                                         nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationDecision failWithError:error];
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneURL = [intuneURLString stringByRemovingPercentEncoding];
    if (!decodedIntuneURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode compliance intuneUrl, using original value");
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to build compliance request for URL: %@", decodedIntuneURL);
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
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Attempting external navigation with browser scheme: %@", legacyFlowUrl);
                
                // Call external navigation block with legacy flow URL
                // Note: The block is responsible for type checking and casting
                NSURLRequest *updatedRequest = externalNavigationBlock((MSIDOAuth2EmbeddedWebviewController *)webviewController, legacyFlowUrl);
                if (updatedRequest)
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Using updated request from external navigation block");
                    return [MSIDWebviewNavigationDecision loadRequest:updatedRequest];
                }
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to create legacy flow URL with browser scheme");
            }
        }
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Loading compliance request: %@", request.URL);
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot build request: URL string is empty");
        return nil;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithString:URLString];
    
    if (!components)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot build request: Failed to parse URL components from string: %@", URLString);
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
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot build request: Failed to create URL from components");
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
