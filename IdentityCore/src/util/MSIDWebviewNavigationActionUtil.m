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
#import "NSURL+MSIDExtensions.h"

@implementation MSIDWebviewNavigationActionUtil

+ (MSIDWebviewNavigationActionUtil *)sharedInstance
{
    static dispatch_once_t once;
    static MSIDWebviewNavigationActionUtil *s_webviewNavigationActionUtil = nil;
    dispatch_once(&once, ^{
        s_webviewNavigationActionUtil = [[MSIDWebviewNavigationActionUtil alloc] init];
    });
    return s_webviewNavigationActionUtil;
}

- (MSIDWebviewNavigationAction *)resolveActionForMSAuthURL:(NSURL *)url
                                           responseHeaders:(NSDictionary<NSString *,NSString *> * _Nullable)responseHeaders
                                   externalNavigationBlock:(MSIDExternalDecidePolicyForBrowserActionBlock)externalNavigationBlock
{
    // handle msauth redirect , can be moved to util
    if (!url)
    {
        return nil;
    }
    
    NSString *host = url.host.lowercaseString;
    NSDictionary *queryParams = [url msidQueryParameters];
    
    // msauth://enroll?cpurl=...
    if ([host isEqualToString:@"enroll"])
    {
        // Extract cpurl parameter
        NSString *cpurlString = queryParams[@"cpurl"];
        if (!cpurlString)
        {
            return nil;
        }
        
        NSURL *cpurl = [NSURL URLWithString:cpurlString];
        if (!cpurl)
        {
            return nil;
        }
        
        // TODO: Add extra headers and query parameters for enrollment
        // For now, create a basic request
        NSURLRequest *request = [NSURLRequest requestWithURL:cpurl];
        
        return [MSIDWebviewNavigationAction loadRequestAction:request];
    }
    
    // msauth://compliance?cpurl=...
    if ([host isEqualToString:@"compliance"])
    {
        // Extract cpurl parameter
        NSString *cpurlString = queryParams[@"cpurl"];
        if (!cpurlString)
        {
            return nil;
        }
        
        NSURL *cpurl = [NSURL URLWithString:cpurlString];
        if (!cpurl)
        {
            return nil;
        }
        
        // TODO: Add extra headers and query parameters for compliance
        // For now, create a basic request
        NSURLRequest *request = [NSURLRequest requestWithURL:cpurl];

        // Optional legacy browser flow decision.
        // Note: MSIDExternalDecidePolicyForBrowserActionBlock expects an embedded webview
        // controller as the first param. This util doesn't have that instance, so we pass nil.
        // Implementations should treat nil as "no webview context".
        if (externalNavigationBlock)
        {
            NSString *requestURLString = request.URL.absoluteString;

            // Create new URL replacing 'https' scheme with 'browser' scheme
            // ("https://..." => "browser://..."). Only do this for https URLs.
            if (requestURLString.length > 5 &&
                [[requestURLString substringToIndex:5].lowercaseString isEqualToString:@"https:"])
            {
                NSURL *legacyFlowUrl = [NSURL URLWithString:[NSString stringWithFormat:@"browser%@", [requestURLString substringFromIndex:5]]];

                if (legacyFlowUrl)
                {
                    NSURLRequest *challengeResponse = externalNavigationBlock(nil, legacyFlowUrl);
                    if (challengeResponse)
                    {
                        return [MSIDWebviewNavigationAction loadRequestAction:challengeResponse];
                    }
                }
            }
        }
        
        return [MSIDWebviewNavigationAction loadRequestAction:request];
    }
    
    // msauth://installProfile?url=...&requireASWebAuthenticationSession=true
    if ([host isEqualToString:@"installprofile"])
    {
        
        NSString *installURLString = responseHeaders[@"x-ms-intune-install-url"];
        NSURL *profileURL = nil;
        
        if (installURLString)
        {
            profileURL = [NSURL URLWithString:installURLString];
        }
        
        if (!profileURL)
        {
            return nil;
        }
        
        // Check if ASWebAuthenticationSession is required
        NSString *requireASWebAuthString = queryParams[@"requireASWebAuthenticationSession"];
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
    
    // msauth://in_app_enrollment_complete
    if ([host isEqualToString:@"in_app_enrollment_complete"] )
    {
        return [MSIDWebviewNavigationAction completeWebAuthWithURLAction:url];
    }
    
    return [MSIDWebviewNavigationAction continueDefaultAction];
}

@end
