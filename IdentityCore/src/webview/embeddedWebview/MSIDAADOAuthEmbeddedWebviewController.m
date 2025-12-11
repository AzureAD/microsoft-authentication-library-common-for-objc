//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDPKeyAuthHandler.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWebAuthNUtil.h"
#import "MSIDFlightManager.h"
#import "MSIDConstants.h"
#import "NSURL+MSIDExtensions.h"

#if !MSID_EXCLUDE_WEBKIT

@implementation MSIDAADOAuthEmbeddedWebviewController

- (id)initWithStartURL:(NSURL *)startURL
                endURL:(NSURL *)endURL
               webview:(WKWebView *)webview
         customHeaders:(NSDictionary<NSString *, NSString *> *)customHeaders
          platfromParams:(MSIDWebViewPlatformParams *)platformParams
               context:(id<MSIDRequestContext>)context
{
    NSMutableDictionary *headers = [NSMutableDictionary new];
    if (customHeaders)
    {
        [headers addEntriesFromDictionary:customHeaders];
    }
    
    // Declare our client as PkeyAuth-capable
    [headers setValue:kMSIDPKeyAuthHeaderVersion forKey:kMSIDPKeyAuthHeader];
        
    return [super initWithStartURL:startURL endURL:endURL
                           webview:webview
                     customHeaders:headers
                    platfromParams:platformParams
                           context:context];
}

- (BOOL)decidePolicyAADForNavigationAction:(WKNavigationAction *)navigationAction
                           decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //AAD specific policy for handling navigation action
    NSURL *requestURL = navigationAction.request.URL;
    
    // Stop at broker or browser
    BOOL isBrokerUrl = [@"msauth" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    BOOL isBrowserUrl = [@"browser" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame;
    
    //Todo: Remove special handling for this URL after URL changes
    // Check if this is the enrollment browser URL by comparing scheme, host, path, and LinkId query parameter
    if (isBrowserUrl)
    {
        NSString *host = requestURL.host;
        NSString *path = requestURL.path;
        NSDictionary *queryParams = [requestURL msidQueryParameters];
        NSString *linkId = queryParams[@"LinkId"];
        
        // Check for enrollment URL (path could be /fwlink or /fwlink/)
        BOOL isEnrollmentPath = [path isEqualToString:@"/fwlink"] || [path isEqualToString:@"/fwlink/"];
        
        if ([host isEqualToString:@"go.microsoft.com"] &&
            isEnrollmentPath &&
            [linkId isEqualToString:@"396941"])
        {
            // Construct proper https URL with all query parameters
            NSString *cpurlValue;
            if (requestURL.query && requestURL.query.length > 0)
            {
                cpurlValue = [NSString stringWithFormat:@"https://%@%@?%@", host, path, requestURL.query];
            }
            else
            {
                cpurlValue = [NSString stringWithFormat:@"https://%@%@", host, path];
            }
            
            // Properly encode the cpurl value for use as a query parameter
            NSString *encodedCpurl = [cpurlValue stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            NSString *msauthURLString = [NSString stringWithFormat:@"msauth://enroll?cpurl=%@", encodedCpurl];
            
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Converting browser enrollment URL to msauth URL. Original: %@, Converted: %@", MSID_PII_LOG_MASKABLE(requestURL.absoluteString), MSID_PII_LOG_MASKABLE(msauthURLString));
            
            requestURL = [NSURL URLWithString:msauthURLString];
        }
    }
    
    if([self verifyMSAuthSchemeAndEnrollmentURL:requestURL])
    {
        requestURL = [NSURL URLWithString:[self extractCpurlFromMSAuthURL:requestURL]];
        NSURLRequest *updatedRequest = [NSURLRequest requestWithURL:requestURL];
        if (updatedRequest)
        {
            decisionHandler(WKNavigationActionPolicyCancel);
            [self loadRequest:updatedRequest];

            return YES;
        }
    }
    
    if (![MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_DISABLE_JIT_TROUBLESHOOTING_LEGACY_AUTH])
    {
        // When not running in SSO extension, the CA block page will return with "https" scheme instead of "browser"
        if (requestURL && ![MSIDWebAuthNUtil amIRunningInExtension] &&
            self.externalDecidePolicyForBrowserAction &&
            [@"https" caseInsensitiveCompare:requestURL.scheme] == NSOrderedSame)
        {
            // Create new URL replacing 'https' scheme with 'browser' scheme
            NSURL *legacyFlowUrl = [NSURL URLWithString:[NSString stringWithFormat:@"browser%@", [requestURL.absoluteString substringFromIndex:5]]];
            NSURLRequest *challengeResponse = self.externalDecidePolicyForBrowserAction(self, legacyFlowUrl);

            if (challengeResponse)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Found AAD policy for navigation using https url and externalDecidePolicyForBrowserAction in legacy auth flow.");
                decisionHandler(WKNavigationActionPolicyCancel);
                [self loadRequest:challengeResponse];

                return YES;
            }
        }
    }
    
    if (isBrokerUrl || isBrowserUrl)
    {
        // Let external code decide if browser url is allowed to continue
        if (isBrowserUrl && self.externalDecidePolicyForBrowserAction)
        {
            NSURLRequest *challengeResponse = self.externalDecidePolicyForBrowserAction(self, requestURL);

            if (challengeResponse)
            {
                decisionHandler(WKNavigationActionPolicyCancel);
                [self loadRequest:challengeResponse];

                return YES;
            }
        }
        
        [self completeWebAuthWithURL:requestURL];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return YES;
    }
    
    // check for pkeyauth challenge.
    NSString *requestURLString = [requestURL.absoluteString lowercaseString];
    
    if ([requestURLString hasPrefix:[kMSIDPKeyAuthUrn lowercaseString]])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        [MSIDPKeyAuthHandler handleChallenge:requestURL.absoluteString
                                     context:self.context
                               customHeaders:self.customHeaders
                          externalSSOContext:self.platformParams.externalSSOContext
                           completionHandler:^(NSURLRequest *challengeResponse, NSError *error) {
                               if (!challengeResponse)
                               {
                                   [self endWebAuthWithURL:nil error:error];
                                   return;
                               }
                               [self loadRequest:challengeResponse];
                           }];
        return YES;
    }
    
    return NO;
}

- (void)decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                webview:(WKWebView *)webView
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([self decidePolicyAADForNavigationAction:navigationAction decisionHandler:decisionHandler])
    {
         return;
    }

    [super decidePolicyForNavigationAction:navigationAction webview:webView decisionHandler:decisionHandler];
}

- (BOOL)verifyMSAuthSchemeAndEnrollmentURL:(NSURL *)url
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"URL is nil, cannot verify msauth scheme and enrollment URL.");
        return NO;
    }
    
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // Verify the scheme is msauth
    if (![scheme.lowercaseString isEqualToString:@"msauth"])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"URL scheme is not msauth: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return NO;
    }
    
    // Verify the host is enroll
    if (![host.lowercaseString isEqualToString:@"enroll"])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"URL host is not enroll: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return NO;
    }
    
    // Extract and verify cpurl parameter exists
    NSString *cpurl = [self extractCpurlFromMSAuthURL:url];
    if (!cpurl || cpurl.length == 0)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"cpurl parameter is missing in enrollment URL: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return NO;
    }
    
    // Verify cpurl starts with the expected enrollment URL base
    NSURL *cpurlURL = [NSURL URLWithString:cpurl];
    if (!cpurlURL)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"cpurl is not a valid URL: %@", MSID_PII_LOG_MASKABLE(cpurl));
        return NO;
    }
    
    // Check if cpurl points to the go.microsoft.com/fwlink enrollment page
    if (!([cpurlURL.host isEqualToString:@"go.microsoft.com"] &&
          ([cpurlURL.path isEqualToString:@"/fwlink"] || [cpurlURL.path isEqualToString:@"/fwlink/"])))
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"cpurl does not point to expected enrollment URL. Found: %@", MSID_PII_LOG_MASKABLE(cpurl));
        return NO;
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Successfully verified msauth scheme and enrollment URL with cpurl: %@", MSID_PII_LOG_MASKABLE(cpurl));
    return YES;
}

- (NSString *)extractCpurlFromMSAuthURL:(NSURL *)url
{
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"URL is nil, cannot extract cpurl from msauth URL.");
        return nil;
    }
    
    // Manually extract cpurl parameter since it contains & characters that would be incorrectly parsed
    // URL format: msauth://enroll?cpurl=https://go.microsoft.com/fwlink?LinkId=396941&userid=...
    NSString *query = url.query;
    if (!query || query.length == 0)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"No query string found in URL: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
        return nil;
    }
    
    // Look for "cpurl=" in the query string
    NSString *cpurlPrefix = @"cpurl=";
    NSRange cpurlRange = [query rangeOfString:cpurlPrefix];
    
    if (cpurlRange.location == NSNotFound)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"cpurl parameter not found in URL: %@", MSID_PII_LOG_MASKABLE(url.absoluteString));
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
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, self.context, @"Failed to decode cpurl value: %@", MSID_PII_LOG_MASKABLE(cpurlValue));
        return cpurlValue; // Return the encoded version if decoding fails
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"Successfully extracted cpurl: %@", MSID_PII_LOG_MASKABLE(decodedCpurl));
    
    return decodedCpurl;
}

@end

#endif
