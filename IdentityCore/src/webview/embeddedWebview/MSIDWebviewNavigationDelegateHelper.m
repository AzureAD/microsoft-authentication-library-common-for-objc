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

#import "MSIDWebviewNavigationDelegateHelper.h"
#import "MSIDWebviewNavigationAction.h"
#import "MSIDWebviewNavigationActionUtil.h"
#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDInteractiveTokenRequest.h"
#import "MSIDWebviewTransitionHandler.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDRequestContext.h"
#import "MSIDError.h"
#import "MSIDWebMDMEnrollmentCompletionResponse.h"
#import "MSIDConstants.h"

@interface MSIDWebviewNavigationDelegateHelper()

@property (nonatomic) id<MSIDRequestContext> context;
@property (nonatomic) NSString *intuneAuthToken;
@property (nonatomic) MSIDWebviewTransitionHandler *transitionHandler;

@end

@implementation MSIDWebviewNavigationDelegateHelper

#pragma mark - Init

- (instancetype)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
        _transitionHandler = [[MSIDWebviewTransitionHandler alloc] init];
    }
    return self;
}

#pragma mark - Webview Configuration

- (void)configureWebviewController:(id)webviewController
                          delegate:(id)delegate
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Configuring webview controller with navigation delegate helper");
    
    // Set navigation delegate if webview supports it
    if ([webviewController isKindOfClass:MSIDOAuth2EmbeddedWebviewController.class])
    {
        MSIDAADOAuthEmbeddedWebviewController *aadWebviewController =
        (MSIDAADOAuthEmbeddedWebviewController *)webviewController;
        
        aadWebviewController.navigationDelegate = delegate;
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"Set navigation delegate on embedded webview controller.");
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"Webview controller is not EmbeddedWebviewController, skipping navigation delegate setup.");
    }
}

#pragma mark - Navigation Delegate Methods

- (void)handleSpecialRedirectUrl:(NSURL *)url
               webviewController:(id)webviewController
                      completion:(void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                 isBrokerContext:(BOOL)isBrokerContext
            externalNavigationBlock:(nullable id)externalNavigationBlock
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Helper handling special redirect: %@", _PII_NULLIFY(url));
    
    NSString *scheme = url.scheme.lowercaseString;
    
    // Handle msauth:// scheme
    if ([scheme isEqualToString:@"msauth"])
    {
        // Check if BRT is needed (Local controller only)
        if (brtEvaluator && brtEvaluator())
        {
            // BRT needed - acquire it first
            if (brtHandler)
            {
                brtHandler(^(__unused BOOL success, __unused NSError *error) {
                    // After BRT acquisition, resolve action
                    MSIDWebviewNavigationActionUtil *util = [MSIDWebviewNavigationActionUtil sharedInstance];
                    MSIDWebviewNavigationAction *action = [util resolveActionForMSAuthURL:url
                                                                           webviewController:webviewController
                                                                            responseHeaders:self.lastResponseHeaders
                                                                          intuneAuthToken:self.intuneAuthToken
                                                                            isBrokerContext:isBrokerContext
                                                                       externalNavigationBlock:externalNavigationBlock];
                    completion(action, nil);
                });
                return;
            }
        }
        
        // No BRT needed or broker context - resolve action directly
        MSIDWebviewNavigationActionUtil *util = [MSIDWebviewNavigationActionUtil sharedInstance];
        MSIDWebviewNavigationAction *action = [util resolveActionForMSAuthURL:url
                                                               webviewController:webviewController
                                                                responseHeaders:self.lastResponseHeaders
                                                              intuneAuthToken:self.intuneAuthToken
                                                                isBrokerContext:isBrokerContext
                                                           externalNavigationBlock:externalNavigationBlock];
        completion(action, nil);
        return;
    }
    
    // Handle browser:// scheme
    if ([scheme isEqualToString:@"browser"])
    {
        // Check if BRT is needed (Local controller only)
        if (brtEvaluator && brtEvaluator())
        {
            // BRT needed - acquire it first
            if (brtHandler)
            {
                brtHandler(^(__unused BOOL success, __unused NSError *error) {
                    // After BRT acquisition, use default action
                    MSIDWebviewNavigationAction *action = [MSIDWebviewNavigationAction continueDefaultAction];
                    completion(action, nil);
                });
                return;
            }
        }
        
        // No BRT needed - use default action
        MSIDWebviewNavigationAction *action = [MSIDWebviewNavigationAction continueDefaultAction];
        completion(action, nil);
        return;
    }
    
    // Unknown scheme - use default behavior
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                     @"Unknown special redirect scheme: %@. Using default behavior.", scheme);
    completion([MSIDWebviewNavigationAction continueDefaultAction], nil);
}

- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
              parentController:(MSIDViewController *)parentController
                    completion:(void (^)(MSIDWebviewNavigationAction * _Nullable, NSError * _Nullable))completion
{
    self.lastResponseHeaders = [headers copy];
    id<MSIDRequestContext> context = self.context;
    
    // Normalize headers once upfront: lowercase keys, filter by prefix
    NSMutableDictionary<NSString *, NSString *> *normalizedHeaders = [NSMutableDictionary dictionary];
    
    for (NSString *key in headers.allKeys)
    {
        // Only consider headers with required prefix (case-insensitive check)
        if (![[key lowercaseString] hasPrefix:MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX])
        {
            continue;  // Skip headers outside namespace
        }
        
        // Normalize key to lowercase for case-insensitive matching
        normalizedHeaders[key.lowercaseString] = headers[key];
    }
    
    // Now we can use direct O(1) lookup with normalized (lowercase) keys
    // Check for x-ms-aswebauth-handoff-url header
    NSString *handoffUrlString = normalizedHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY];
    if (![handoffUrlString isKindOfClass:NSString.class] || handoffUrlString.length == 0)
    {
        // No handoff URL - continue normal flow
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"No %@ header found, continuing normal flow", MSID_ASWEBAUTH_HANDOFF_URL_KEY);
        return;
    }
    
    // Validate URL is valid HTTPS
    NSURL *handoffUrl = [NSURL URLWithString:handoffUrlString];
    if (!handoffUrl || [@"https" caseInsensitiveCompare:handoffUrl.scheme] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Invalid handoff URL (not HTTPS): %@", _PII_NULLIFY(handoffUrlString));
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter,
                                        @"x-ms-aswebauth-handoff-url must be a valid HTTPS URL",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Validate domain allowlist (security check)
    if (![self isURLInAllowedDomains:handoffUrl])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Handoff URL domain not in allowlist: %@", _PII_NULLIFY(handoffUrl.host));
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter,
                                        @"Handoff URL domain is not in the trusted allowlist",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Found valid ASWebAuth handoff URL: %@", _PII_NULLIFY(handoffUrlString));
    
    // Read use of ephemeral session header (optional, defaults to YES)
    BOOL useEphemeralSession = YES; // Default to YES
    NSString *useEphemeralValue = normalizedHeaders[MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY];
    if ([useEphemeralValue isKindOfClass:NSString.class])
    {
        // Case-insensitive comparison for "false" value
        if ([useEphemeralValue caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_FALSE] == NSOrderedSame)
        {
            useEphemeralSession = NO;
        }
        // "true" or any other value defaults to YES
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"ASWebAuth session will use ephemeral mode: %@", useEphemeralSession ? @"YES" : @"NO");
    
    // Check if headers should be included
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    NSString *includeHeadersValue = normalizedHeaders[MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY];
    
    // Case-insensitive comparison for "true" value
    if ([includeHeadersValue caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_TRUE] == NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                         @"Headers should be included in ASWebAuth session");
        
        // Parse headers to attach
        NSString *attachHeadersValue = normalizedHeaders[MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY];
        if ([attachHeadersValue isKindOfClass:NSString.class] && attachHeadersValue.length > 0)
        {
            // Split comma-separated header names
            NSArray<NSString *> *headerNames = [attachHeadersValue componentsSeparatedByString:@","];
            
            for (NSString *headerName in headerNames)
            {
                NSString *trimmedHeaderName = [headerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                // Only allow headers with required prefix
                if (trimmedHeaderName.length == 0 || ![[trimmedHeaderName lowercaseString] hasPrefix:MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX])
                {
                    continue;
                }
                
                // Case-insensitive header lookup using normalized headers
                NSString *headerValue = normalizedHeaders[trimmedHeaderName.lowercaseString];
                
                if (headerValue)
                {
                    additionalHeaders[trimmedHeaderName] = headerValue;
                    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                                     @"Adding header to ASWebAuth: %@ = %@",
                                     trimmedHeaderName, _PII_NULLIFY(headerValue));
                }
                else
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                                     @"Header '%@' specified in attach-headers but not found in response",
                                     trimmedHeaderName);
                }
            }
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                             @"include-headers is true but attach-headers is empty or invalid");
        }
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"Headers will not be included (include-headers != 'true')");
    }
    
    [self handleASWebAuthenticationTransition:handoffUrl
                           additionalHeaders:additionalHeaders.count > 0 ? additionalHeaders : nil
                          useEphemeralSession:useEphemeralSession
                                      purpose:MSIDSystemWebviewPurposeInstallProfile
                             parentController:parentController
                                   completion:completion];
}

#pragma mark - ASWebAuthenticationSession Transition

- (void)handleASWebAuthenticationTransition:(NSURL *)url
                         additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                        useEphemeralSession:(BOOL)useEphemeralSession
                                   purpose:(MSIDSystemWebviewPurpose)purpose
                          parentController:(MSIDViewController *)parentController
                                completion:(void (^)(MSIDWebviewNavigationAction * _Nullable, NSError * _Nullable))completion
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Handling ASWebAuthentication transition");
    
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"ASWebAuthentication transition called with no url, proceeding the flow in embedded webview");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"ASWebAuthentication transition called with no url",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Launch ASWebAuthenticationSession with configuration
    [self.transitionHandler launchASWebAuthenticationSessionWithUrl:url
                                              parentController:parentController
                                             additionalHeaders:additionalHeaders
                                        useEphemeralSession:useEphemeralSession
                                      MSIDSystemWebviewPurpose:purpose
                                                       context:context
                                                    completion:^(MSIDWebviewNavigationAction * _Nonnull action, NSError * _Nonnull error) {
        completion(action, error);
    }];
}

#pragma mark - Helper Methods

- (BOOL)isURLInAllowedDomains:(NSURL *)url
{
    // Domain Allowlist Enforcement (Security-Critical)
    // - Client MUST maintain a static allowlist of domains eligible for ASWebAuthenticationSession
    // - Allowlist evaluation MUST be performed using the host component of the handoff URL
    // - Wildcards SHOULD NOT be used by default
    // - If domain is not allowlisted, client MUST fail the handoff and MUST NOT inject headers
    
    if (!url || !url.host)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"ASWebAuth handoff validation failed: URL or host is nil");
        return NO;
    }
    
    // Extract and normalize host component from the handoff URL
    NSString *host = url.host.lowercaseString;  // Case-insensitive matching per section 6.1
    
    // Exact domain matching (no wildcards)
    NSSet<NSString *> *allowedDomains = MSIDConstants.asWebAuthAllowedDomains;
    
    // Perform exact domain match (case-insensitive via host normalization)
    if ([allowedDomains containsObject:host])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"ASWebAuth handoff domain validated: %@ is in allowlist", host);
        return YES;
    }
    
    // Domain not allowlisted - fail handoff per security requirements
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"ASWebAuth handoff rejected: Domain %@ is not in the static allowlist", host);
    return NO;
}

@end
