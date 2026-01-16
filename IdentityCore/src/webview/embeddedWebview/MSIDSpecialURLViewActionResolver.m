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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"
#import "MSIDInteractiveWebviewState.h"
#import "NSURL+MSIDExtensions.h"

@implementation MSIDSpecialURLViewActionResolver

+ (MSIDWebviewAction *)resolveActionForURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    if (!url)
    {
        return nil;
    }
    
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host = url.host.lowercaseString;
    NSDictionary *queryParams = [url msidQueryParameters];
    
    // Handle msauth:// scheme
    if ([scheme isEqualToString:@"msauth"])
    {
        // msauth://enroll?cpurl=...
        if ([host isEqualToString:@"enroll"])
        {
            return [self resolveEnrollAction:queryParams];
        }
        
        // msauth://compliance?cpurl=...
        if ([host isEqualToString:@"compliance"])
        {
            return [self resolveComplianceAction:queryParams];
        }
        
        // msauth://installProfile?url=...&requireASWebAuthenticationSession=true
        if ([host isEqualToString:@"installprofile"])
        {
            return [self resolveInstallProfileAction:queryParams state:state];
        }
        
        // msauth://profileComplete
        if ([host isEqualToString:@"profilecomplete"])
        {
            return [MSIDWebviewAction completeWithURLAction:url];
        }
    }
    
    // Handle browser:// scheme
    if ([scheme isEqualToString:@"browser"])
    {
        return [MSIDWebviewAction completeWithURLAction:url];
    }
    
    // Unknown URL pattern
    return nil;
}

#pragma mark - Private Resolvers

+ (MSIDWebviewAction *)resolveEnrollAction:(NSDictionary *)queryParams
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
    
    return [MSIDWebviewAction loadRequestAction:request];
}

+ (MSIDWebviewAction *)resolveComplianceAction:(NSDictionary *)queryParams
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
    
    return [MSIDWebviewAction loadRequestAction:request];
}

+ (MSIDWebviewAction *)resolveInstallProfileAction:(NSDictionary *)queryParams
{
    // Extract url parameter
    NSString *urlString = queryParams[@"url"];
    if (!urlString)
    {
        return nil;
    }
    
    NSURL *profileURL = [NSURL URLWithString:urlString];
    if (!profileURL)
    {
        return nil;
    }
    
    // Check if ASWebAuthenticationSession is required
    NSString *requireASWebAuthString = queryParams[@"requireaswebauthenticationsession"];
    BOOL requireASWebAuth = [requireASWebAuthString.lowercaseString isEqualToString:@"true"];
    
    if (requireASWebAuth)
    {
        // Open in ASWebAuthenticationSession with InstallProfile purpose
        // Note: Ephemeral session behavior is implied by purpose and will be
        // enforced by the system webview handoff handler
        return [MSIDWebviewAction openASWebAuthSessionAction:profileURL
                                                     purpose:MSIDSystemWebviewPurposeInstallProfile];
    }
    else
    {
        // Load in embedded webview
        NSURLRequest *request = [NSURLRequest requestWithURL:profileURL];
        return [MSIDWebviewAction loadRequestAction:request];
    }
}

@end
