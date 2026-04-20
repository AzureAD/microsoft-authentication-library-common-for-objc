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

#import "MSIDWebviewNavigationActionUtil.h"
#import "MSIDWebviewNavigationAction.h"
#import "MSIDWebviewConstants.h"
#import "MSIDSSOExtensionInteractiveTokenRequestController.h"
#import "MSIDConstants.h"

@implementation MSIDWebviewNavigationActionUtil

+ (instancetype)sharedInstance
{
    static MSIDWebviewNavigationActionUtil *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MSIDWebviewNavigationActionUtil alloc] init];
    });
    return sharedInstance;
}

->msauth->completeWebAuthWithURLAction->preprocessing in PRT controller -> webview.loadRequest with intuneUrl and headers
->msuth->loadRequestAction with intuneUrl and headers//current thing-> controller
- (MSIDWebviewNavigationAction *)resolveActionForURL:(NSURL *)url
                                   webviewController:(id<MSIDWebviewInteracting>)webviewController
                                     responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                             appName:(NSString *)appName
                                          appVersion:(NSString *)appVersion
                             externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Validate required parameters
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot resolve navigation action: URL is nil");
        return nil;
    }
    
    NSString *scheme = url.scheme.lowercaseString;
    
    if (!scheme || scheme.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot resolve navigation action: URL scheme is nil or empty");
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Resolving action for special redirect URL with scheme: %@", scheme);
    
    // Route based on scheme
    if ([scheme isEqualToString:MSID_SCHEME_MSAUTH])
    {
        // Handle msauth:// URLs
        return [self handleMSAuthURL:url
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
        return [MSIDWebviewNavigationAction continueDefaultAction];
    }
    else
    {
        // Unknown scheme - continue with default behavior
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Unknown special redirect scheme: %@, continuing with default action", scheme);
        return [MSIDWebviewNavigationAction continueDefaultAction];
    }
}

#pragma mark - Scheme Handlers

- (MSIDWebviewNavigationAction *)handleMSAuthURL:(NSURL *)url
                               webviewController:(id<MSIDWebviewInteracting>)webviewController
                                 responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                         appName:(NSString *)appName
                                      appVersion:(NSString *)appVersion
                         externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    NSString *host = url.host.lowercaseString;
    
    // Validate host
    if (!host || host.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to resolve navigation action: 'msauth' URL has empty or missing host. URL: %@", url);
        return nil;
    }
    
    // Parse query parameters
    NSDictionary<NSString *, NSString *> *params = [self queryParamsFromURL:url];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Resolving action for msauth URL with host: %@", host);
    
    // Route based on host
    if ([host isEqualToString:MSID_MDM_ENROLL_HOST])
    {
        return [self actionForEnrollURL:params
                                appName:appName
                             appVersion:appVersion];
    }
    else if ([host isEqualToString:MSID_COMPLIANCE_HOST])
    {
        return [self actionForComplianceURL:webviewController
                                     params:params
                    externalNavigationBlock:externalNavigationBlock];
    }
    else if ([host isEqualToString:MSID_MDM_ENROLLMENT_COMPLETION_HOST])
    {
        return [self actionForEnrollmentCompletionURL:url
                                               params:params];
    }
    else
    {
        // Unknown host - continue with default behavior
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Unknown msauth host: %@, continuing with default action", host);
        return [MSIDWebviewNavigationAction continueDefaultAction];
    }
}

#pragma mark - URL Action Resolvers

- (MSIDWebviewNavigationAction *)actionForEnrollURL:(NSDictionary *)params
                                            appName:(NSString *)appName
                                         appVersion:(NSString *)appVersion
{
    // Extract intuneUrl from query parameters
    NSString *intuneUrlString = params[MSID_INTUNE_URL_KEY];
    if (!intuneUrlString || intuneUrlString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Enroll URL missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                        MSIDErrorInvalidInternalParameter,
                                        @"Missing intuneRedirectUrl parameter in enrollment URL",
                                        nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneUrl = [intuneUrlString stringByRemovingPercentEncoding];
    if (!decodedIntuneUrl)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode intuneUrl, using original value");
        decodedIntuneUrl = intuneUrlString;
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
    NSURLRequest *request = [self buildRequestForUrl:decodedIntuneUrl
                                        extraHeaders:additionalHeaders
                                         extraParams:allQueryParams];
    
    if (!request)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to build enrollment request for URL: %@", decodedIntuneUrl);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                        MSIDErrorInvalidInternalParameter,
                                        @"Failed to construct enrollment request URL",
                                        nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Created enrollment request for URL: %@", request.URL);
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

- (MSIDWebviewNavigationAction *)actionForEnrollmentCompletionURL:(NSURL *)url
                                                           params:(NSDictionary *)params
{
    // Check if SSO extension can perform request
    if ([MSIDSSOExtensionInteractiveTokenRequestController canPerformRequest])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"SSO extension available, completing web auth with enrollment completion URL");
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
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
            return [MSIDWebviewNavigationAction loadRequestAction:[NSURLRequest requestWithURL:errorURL]];
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
    return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
}

- (MSIDWebviewNavigationAction *)actionForComplianceURL:(id<MSIDWebviewInteracting>)webviewController
                                                 params:(NSDictionary *)params
                                externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Extract intuneUrl from query parameters
    NSString *intuneUrlString = params[MSID_INTUNE_URL_KEY];
    if (!intuneUrlString || intuneUrlString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Compliance URL missing required parameter: %@", MSID_INTUNE_URL_KEY);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                        MSIDErrorInvalidInternalParameter,
                                        @"Missing intuneRedirectUrl parameter in compliance URL",
                                        nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneUrl = [intuneUrlString stringByRemovingPercentEncoding];
    if (!decodedIntuneUrl)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to decode compliance intuneUrl, using original value");
        decodedIntuneUrl = intuneUrlString;
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
    NSURLRequest *request = [self buildRequestForUrl:decodedIntuneUrl
                                        extraHeaders:nil  // TODO: Add additional compliance-specific headers if needed
                                         extraParams:allQueryParams];
    
    if (!request)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to build compliance request for URL: %@", decodedIntuneUrl);
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                        MSIDErrorInvalidInternalParameter,
                                        @"Failed to construct compliance request URL",
                                        nil, nil, nil, nil, nil, YES);
        return [MSIDWebviewNavigationAction failWebAuthWithErrorAction:error];
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
                    return [MSIDWebviewNavigationAction loadRequestAction:updatedRequest];
                }
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to create legacy flow URL with browser scheme");
            }
        }
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Loading compliance request: %@", request.URL);
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

#pragma mark - Helper Methods

- (nullable NSURLRequest *)buildRequestForUrl:(NSString *)urlString
                                 extraHeaders:(nullable NSDictionary<NSString *, NSString *> *)extraHeaders
                                  extraParams:(nullable NSDictionary<NSString *, NSString *> *)extraParams
{
    // Validate input URL string
    if (!urlString || urlString.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot build request: URL string is empty");
        return nil;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    
    if (!components)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Cannot build request: Failed to parse URL components from string: %@", urlString);
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

- (NSDictionary<NSString *, NSString *> *)queryParamsFromURL:(NSURL *)url
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot extract query params: URL is nil");
        return @{};
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (!components)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Cannot extract query params: Failed to parse URL components for URL: %@", url);
        return @{};
    }
    
    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary new];
    
    NSArray<NSURLQueryItem *> *queryItems = components.queryItems;
    if (!queryItems || queryItems.count == 0)
    {
        return @{};
    }
    
    for (NSURLQueryItem *item in queryItems)
    {
        // Only add items with both name and value present
        if (item.name && item.value)
        {
            result[item.name] = item.value;
        }
        else if (item.name)
        {
            // Query parameter with no value - log as warning
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Query parameter '%@' has no value", item.name);
        }
    }
    
    return [result copy];
}

@end

