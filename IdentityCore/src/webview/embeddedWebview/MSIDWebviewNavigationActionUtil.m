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
#import "MSIDConstants.h"

@implementation MSIDWebviewNavigationActionUtil

+ (instancetype)sharedInstance
{
    static MSIDWebviewNavigationActionUtil *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MSIDWebviewNavigationActionUtil alloc] init];
    });
    return instance;
}

- (MSIDWebviewNavigationAction *)resolveActionForMSAuthURL:(NSURL *)url
                                         webviewController:(id<MSIDWebviewInteracting>)webviewController
                                           responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                           isBrokerContext:(BOOL)isBrokerContext
                                   externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    if (!url)
    {
        return nil;
    }
    
    NSString *host = url.host.lowercaseString;
    
    // Parse query parameters
    NSDictionary<NSString *, NSString *> *params = [self queryParamsFromURL:url];
    
    // Route based on host
    if ([host isEqualToString:@"enroll"])
    {
        return [self actionForEnrollURL:url
                                 params:params
                        responseHeaders:responseHeaders];
    }
    else if ([host isEqualToString:@"compliance"])
    {
        return [self actionForComplianceURL:url
                          webviewController:webviewController
                                     params:params
                            responseHeaders:responseHeaders
                    externalNavigationBlock:externalNavigationBlock];
    }
    else if ([host isEqualToString:@"installprofile"])
    {
        return [self actionForInstallProfileURL:url
                                         params:params
                                responseHeaders:responseHeaders];
    }
    else if ([host isEqualToString:@"in_app_enrollment_complete"])
    {
        // Profile installation completed - complete auth with this URL
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    else
    {
        // Unknown host - complete with URL (default behavior)
        return [MSIDWebviewNavigationAction continueDefaultAction];
    }
}

#pragma mark - URL Action Resolvers

- (MSIDWebviewNavigationAction *)actionForEnrollURL:(NSURL *)url
                                             params:(NSDictionary *)params
                                    responseHeaders:(nullable NSDictionary *)responseHeaders
{
    // Extract intuneUrl from query parameters
    // URL format: msauth://enroll?intuneUrl=https://go.microsoft.com/fwlink?LinkId=396941
    NSString *intuneUrl = params[@"intuneUrl"];
    if (!intuneUrl)
    {
        // Missing intuneUrl - return nil
        return nil;
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneUrl = [intuneUrl stringByRemovingPercentEncoding];
    if (!decodedIntuneUrl)
    {
        decodedIntuneUrl = intuneUrl; // Use original if decoding fails
    }
    
    // Query parameters from intuneUrl
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    // Add new query parameters
    allQueryParams[@"inAppWebView"] = @"true";
    allQueryParams[@"webauthn"] = @"1";
    
    // Extract any additional params from original msauth URL (excluding intuneUrl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:@"intuneUrl"])
        {
            allQueryParams[key] = params[key];
        }
    }
    
    // Prepare additional headers for enrollment
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    
    // Build the final request with all query params and headers
    NSURLRequest *request = [self buildRequestForCpurl:decodedIntuneUrl
                                          extraHeaders:additionalHeaders
                                           extraParams:allQueryParams];
    
    if (!request)
    {
        return nil;
    }
    
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

- (MSIDWebviewNavigationAction *)actionForComplianceURL:(NSURL *)url
                                      webviewController:(id<MSIDWebviewInteracting>)webviewController
                                                 params:(NSDictionary *)params
                                        responseHeaders:(nullable NSDictionary *)responseHeaders
                                externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // Extract cpurl from query parameters
    // URL format: msauth://compliance?intuneUrl=https://go.microsoft.com/fwlink?LinkId=396941
    NSString *intuneUrl = params[@"intuneUrl"];
    if (!intuneUrl)
    {
        // Missing intuneUrl - return nil
        return nil;
    }
    
    // URL decode the intuneUrl in case it's percent-encoded
    NSString *decodedIntuneUrl = [intuneUrl stringByRemovingPercentEncoding];
    if (!decodedIntuneUrl)
    {
        decodedIntuneUrl = intuneUrl; // Use original if decoding fails
    }
    
    // Query parameters from cpurl
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    // Extract any additional params from original msauth URL (excluding intuneUrl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:@"intuneUrl"])
        {
            allQueryParams[key] = params[key];
        }
    }
    
    // Prepare additional headers if any compliance tokens are needed
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    
    // Build the final request with all query params and headers
    NSURLRequest *request = [self buildRequestForCpurl:decodedIntuneUrl
                                          extraHeaders:additionalHeaders
                                           extraParams:allQueryParams];
    
    if (!request)
    {
        return nil;
    }
    
    if (externalNavigationBlock)
    {
        NSString *requestURLString = request.URL.absoluteString;

        // Replacing 'https' scheme with 'browser' scheme
        if (requestURLString.length > 5 &&
            [[requestURLString substringToIndex:5].lowercaseString isEqualToString:@"https:"])
        {
            NSURL *legacyFlowUrl = [NSURL URLWithString:[NSString stringWithFormat:@"browser%@", [requestURLString substringFromIndex:5]]];

            if (legacyFlowUrl)
            {
                NSURLRequest *updatedURL = externalNavigationBlock((MSIDOAuth2EmbeddedWebviewController *)webviewController, legacyFlowUrl);
                if (updatedURL)
                {
                    return [MSIDWebviewNavigationAction loadRequestAction:updatedURL];
                }
            }
        }
    }
    
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

- (MSIDWebviewNavigationAction *)actionForInstallProfileURL:(NSURL *)url
                                                     params:(NSDictionary *)params
                                            responseHeaders:(nullable NSDictionary *)responseHeaders
{
    // Extract install URL from response header
    NSString *installURLString = responseHeaders[@"x-ms-intune-install-url"];
    NSURL *profileURL = nil;
    
    if (installURLString)
    {
        profileURL = [NSURL URLWithString:installURLString];
    }
    
    if (!profileURL)
    {
        // Missing url for profile installation - return nil
        return nil;
    }
        
    // Check if ASWebAuthenticationSession is required
    NSString *requireASWebAuthString = params[@"requireASWebAuthenticationSession"];
    BOOL requireASWebAuth = [requireASWebAuthString.lowercaseString isEqualToString:@"true"];
        
    if (requireASWebAuth)
    {
        // Extract X-Intune-AuthToken for passing to ASWebAuthenticationSession
        // Note: X-Install-Url is used for the URL, not passed in additionalHeaders
        NSDictionary<NSString *, NSString *> *authHeaders = nil;
        NSString *intuneAuthToken = responseHeaders[@"x-ms-intune-token"];
        if (intuneAuthToken)
        {
            authHeaders = @{@"x-ms-intune-token": intuneAuthToken};
        }
        
        // Open in ASWebAuthenticationSession with InstallProfile purpose
        // URL: from X-Install-Url header
        // Headers: X-Intune-AuthToken only
        // Note: Ephemeral session behavior is implied by purpose and will be
        // enforced by the system webview handoff handler
        return [MSIDWebviewNavigationAction openInASWebAuthSessionAction:profileURL
                                                                 purpose:MSIDSystemWebviewPurposeInstallProfile
                                                       additionalHeaders:authHeaders];
    }
    else
    {
        // Load in embedded webview
        NSURLRequest *request = [NSURLRequest requestWithURL:profileURL];
        return [MSIDWebviewNavigationAction loadRequestAction:request];
    }
}

#pragma mark - Helper Methods

- (nullable NSURLRequest *)buildRequestForCpurl:(NSString *)cpurl
                                   extraHeaders:(nullable NSDictionary<NSString *, NSString *> *)extraHeaders
                                    extraParams:(nullable NSDictionary<NSString *, NSString *> *)extraParams
{
    NSURLComponents *components = [NSURLComponents componentsWithString:cpurl];
    
    if (!components)
    {
        return nil;
    }
    
    // Add query parameters
    if (extraParams.count > 0)
    {
        NSMutableArray *queryItems = [NSMutableArray array];
        
        // Keep existing query items
        if (components.queryItems)
        {
            [queryItems addObjectsFromArray:components.queryItems];
        }
        
        // Add new query items
        for (NSString *key in extraParams)
        {
            NSURLQueryItem *item = [NSURLQueryItem queryItemWithName:key value:extraParams[key]];
            [queryItems addObject:item];
        }
        
        components.queryItems = queryItems;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    
    // Add headers
    if (extraHeaders.count > 0)
    {
        for (NSString *key in extraHeaders)
        {
            [request setValue:extraHeaders[key] forHTTPHeaderField:key];
        }
    }
    
    return request;
}

- (NSDictionary<NSString *, NSString *> *)queryParamsFromURL:(NSURL *)url
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableDictionary *result = [NSMutableDictionary new];

    for (NSURLQueryItem *item in components.queryItems ?: @[])
    {
        if (item.name && item.value)
        {
            result[item.name] = item.value;
        }
    }
    return result;
}

@end

