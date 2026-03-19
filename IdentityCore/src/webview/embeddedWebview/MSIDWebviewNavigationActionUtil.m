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
                                           intuneAuthToken:(NSString * _Nullable)intuneAuthToken
                                           isBrokerContext:(BOOL)isBrokerContext
                                   externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    if (!url)
    {
        return [MSIDWebviewNavigationAction continueDefaultAction];
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
                                     params:params
                            responseHeaders:responseHeaders];
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
    // Extract cpurl from query parameters
    NSString *cpurl = params[@"cpurl"];
    if (!cpurl)
    {
        // Missing cpurl - just complete with original URL
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    // Query parameters from cpurl
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    
    // Extract any additional params from original msauth URL (excluding cpurl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:@"cpurl"])
        {
            allQueryParams[key] = params[key];
        }
    }
    
    // Add new broker-specific query parameters for enrollment
    allQueryParams[@"inAppWebview"] = @"true";
    //webauthn=1
    
    // Prepare additional headers for enrollment
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    
    // Add enrollment scenario header
    additionalHeaders[@"x-ms-app-name"] = @"broker";
    additionalHeaders[@"x-ms-app-ver"] = @"3.16.5";
    
//    // Check for enrollment-related headers in response
//    if (responseHeaders[@"x-ms-enrollment-token"])
//    {
//        additionalHeaders[@"x-ms-enrollment-token"] = responseHeaders[@"x-ms-enrollment-token"];
//    }
//
//    if (responseHeaders[@"x-ms-compliance-token"])
//    {
//        additionalHeaders[@"x-ms-compliance-token"] = responseHeaders[@"x-ms-compliance-token"];
//    }
//
//    if (responseHeaders[@"x-ms-enrollment-id"])
//    {
//        additionalHeaders[@"x-ms-enrollment-id"] = responseHeaders[@"x-ms-enrollment-id"];
//    }
    
    // Build the final request with all query params and headers
    NSURLRequest *request = [self buildRequestForCpurl:cpurl
                                          extraHeaders:additionalHeaders
                                           extraParams:allQueryParams];
    
    if (!request)
    {
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

- (MSIDWebviewNavigationAction *)actionForComplianceURL:(NSURL *)url
                                                 params:(NSDictionary *)params
                                        responseHeaders:(nullable NSDictionary *)responseHeaders
{
    // Extract cpurl from query parameters
    // URL format: msauth://compliance?cpurl=https://go.microsoft.com/fwlink?LinkId=396941
    NSString *cpurl = params[@"cpurl"];
    if (!cpurl)
    {
        // Missing cpurl - just complete with original URL
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    // URL decode the cpurl in case it's percent-encoded
    NSString *decodedCpurl = [cpurl stringByRemovingPercentEncoding];
    if (!decodedCpurl)
    {
        decodedCpurl = cpurl; // Use original if decoding fails
    }
    
    // Parse the cpurl to extract existing query parameters
    NSURL *cpURL = [NSURL URLWithString:decodedCpurl];
    if (!cpURL)
    {
        // Invalid cpurl - complete with original URL
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    // Query parameters from cpurl
    NSMutableDictionary *allQueryParams = [NSMutableDictionary dictionary];
    
    // Add new broker-specific query parameters
    allQueryParams[@"source"] = @"broker";
    allQueryParams[@"scenario"] = @"compliance";
    
    // Extract any additional params from original msauth URL (excluding cpurl itself)
    for (NSString *key in params)
    {
        if (![key isEqualToString:@"cpurl"])
        {
            allQueryParams[key] = params[key];
        }
    }
    
    // Prepare additional headers if any compliance tokens are needed
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    
    // Check for compliance-related headers in response
    if (responseHeaders[@"x-ms-compliance-token"])
    {
        additionalHeaders[@"x-ms-compliance-token"] = responseHeaders[@"x-ms-compliance-token"];
    }
    
    if (responseHeaders[@"x-ms-enrollment-token"])
    {
        additionalHeaders[@"x-ms-enrollment-token"] = responseHeaders[@"x-ms-enrollment-token"];
    }
    
    // Build the final request with all query params and headers
    NSURLRequest *request = [self buildRequestForCpurl:decodedCpurl
                                          extraHeaders:additionalHeaders.count > 0 ? additionalHeaders : nil
                                           extraParams:allQueryParams];
    
    if (!request)
    {
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    return [MSIDWebviewNavigationAction loadRequestAction:request];
}

- (MSIDWebviewNavigationAction *)actionForInstallProfileURL:(NSURL *)url
                                                     params:(NSDictionary *)params
                                            responseHeaders:(nullable NSDictionary *)responseHeaders
                                            intuneAuthToken:(NSString * _Nullable)intuneAuthToken
{
    // Extract install URL from response header
    NSString *installURLString = params[@"profileUrl"]; //@"https://portal.manage-beta.microsoft.com/enrollment/webenrollment/installprofile?platform=iPhone";
    NSURL *profileURL = nil;
    
    if (installURLString)
    {
        profileURL = [NSURL URLWithString:installURLString];
    }
    
    if (!profileURL)
    {
        // Missing url - just complete with original URL
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];;
    }
        
    // Check if ASWebAuthenticationSession is required
    NSString *requireASWebAuthString = params[@"requireASWebAuthenticationSession"];
    BOOL requireASWebAuth = [requireASWebAuthString.lowercaseString isEqualToString:@"true"];
        
    if (requireASWebAuth)
    {
        // Extract X-Intune-AuthToken for passing to ASWebAuthenticationSession
        // Note: X-Install-Url is used for the URL, not passed in additionalHeaders
        NSDictionary<NSString *, NSString *> *authHeaders = nil;
        NSString *intuneAuthTokenInResponseHeaders = responseHeaders[@"x-ms-intune-token"];
        if (intuneAuthTokenInResponseHeaders)
        {
            authHeaders = @{@"x-ms-intune-token": intuneAuthTokenInResponseHeaders};
        }
        else if (intuneAuthToken)
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
        // TODO: Check if we need to load in external browser or embedded webview based on other parameters or headers.
        // Open in external browser
        //return [MSIDWebviewNavigationAction openInExternalBrowserAction:profileURL];
        
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


- (NSString *)extractCpurlFromMSAuthURL:(NSURL *)url
{
    if (!url)
    {
        //MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"URL is nil, cannot extract cpurl from msauth URL.");
        return nil;
    }
    
    // Manually extract cpurl parameter since it contains & characters that would be incorrectly parsed
    // URL format: msauth://enroll?cpurl=https://go.microsoft.com/fwlink?LinkId=396941&userid=...
    NSString *query = url.query;
    if (!query || query.length == 0)
    {
        //MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"No query string found in URL: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return nil;
    }
    
    // Look for "cpurl=" in the query string
    NSString *cpurlPrefix = @"cpurl=";
    NSRange cpurlRange = [query rangeOfString:cpurlPrefix];
    
    if (cpurlRange.location == NSNotFound)
    {
        //MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"cpurl parameter not found in URL: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return nil;
    }
    
    // Extract everything after "cpurl="
    // The cpurl value extends to the end of the query string (or until the next top-level parameter if any)
    NSUInteger startIndex = cpurlRange.location + cpurlRange.length;
    NSString *cpurlValue = [query substringFromIndex:startIndex];
    
    // Decode the percent-encoded URL
    NSString *decodedCpurl = [cpurlValue stringByRemovingPercentEncoding];
    
    if (!decodedCpurl)
    {
        //MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"Failed to decode cpurl value: %@", MSID_PII_LOG_MASKABLE(cpurlValue));
        return cpurlValue; // Return the encoded version if decoding fails
    }
    
    //MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Successfully extracted cpurl: %@", MSID_PII_LOG_MASKABLE(decodedCpurl));
    
    return decodedCpurl;
}

@end

