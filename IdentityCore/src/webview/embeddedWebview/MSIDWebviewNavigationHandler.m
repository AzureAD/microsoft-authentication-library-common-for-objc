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

#import "MSIDWebviewNavigationHandler.h"
#import "MSIDWebviewNavigationDecision.h"
#import "MSIDWebviewNavigationDecisionResolver.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDSystemWebviewTransitionManager.h"
#import "MSIDRequestContext.h"
#import "MSIDWebviewNavigationDelegate.h"
#import "MSIDWebviewConstants.h"
#import "MSIDConstants.h"
#import "MSIDUXCallbackProvider.h"
#import "MSIDFlightManager.h"

#if !MSID_EXCLUDE_WEBKIT

@interface MSIDWebviewNavigationHandler()

@property (nonatomic) id<MSIDRequestContext> context;
@property (nonatomic) NSDictionary<NSString *, id> *lastResponseHeaders;

@end

@implementation MSIDWebviewNavigationHandler

#pragma mark - Init

- (instancetype)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    return self;
}

#pragma mark - Webview Configuration

- (void)configureWebviewController:(id<MSIDWebviewInteracting>)webviewController
                          delegate:(id<MSIDWebviewNavigationDelegate>)delegate
{
    if (![(id)webviewController isKindOfClass:MSIDOAuth2EmbeddedWebviewController.class])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context,
                          @"Skipping navigation delegate setup: webview is not MSIDOAuth2EmbeddedWebviewController.");
        return;
    }

    ((MSIDOAuth2EmbeddedWebviewController *)webviewController).navigationDelegate = delegate;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Configured embedded webview navigation delegate.");
}

#pragma mark - Navigation Delegate Methods

- (void)handleSpecialRedirectURL:(NSURL *)URL
       embeddedWebviewController:(MSIDOAuth2EmbeddedWebviewController * _Nullable)embeddedWebviewController
                      completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"Handling special redirect: %@", _PII_NULLIFY(URL));

    MSIDWebviewNavigationDecisionResolver *util = [MSIDWebviewNavigationDecisionResolver sharedInstance];
    MSIDWebviewNavigationDecision *navigationDecision = [util resolveDecisionForURL:URL
                                                          embeddedWebviewController:embeddedWebviewController];
    completion(navigationDecision, nil);
}

- (BOOL)processResponseHeadersAndCheckForASWebAuthHandoff:(NSDictionary *)headers
                                              responseURL:(NSURL *)responseURL
{
    // Normalize and capture headers for later use. This also allows for case-insensitive lookup of header values.
    self.lastResponseHeaders = [self normalizeHeaders:headers];

    // TODO: Add telemetry for response headers

    NSString *handoffURLString = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY];
    BOOL hasHandoffHeader = [handoffURLString isKindOfClass:NSString.class] && ((NSString *)handoffURLString).length > 0;

    if (!hasHandoffHeader)
    {
        return NO;
    }

    // Security gate: validate that the response URL is from an allowed origin before proceeding with the hand-off.
    if (![self isAllowedHandoffOrigin:responseURL])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                          @"ASWebAuth hand-off header present but response URL host is not allowed; ignoring hand-off.");
        return NO;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context,
                      @"ASWebAuth hand-off URL detected in response headers from allowed origin.");

    return YES;
}

#if !MSID_EXCLUDE_SYSTEMWV

- (void)performASWebAuthenticationHandoffWithParentController:(MSIDViewController *)parentController
                                                   completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable, NSError * _Nullable))completion
{
    if (!completion)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                          @"performASWebAuthenticationHandoff called with nil completion; ignoring.");
        return;
    }

    // Retrieve the hand-off URL captured by the most recent
    // processResponseHeadersAndCheckForASWebAuthHandoff:responseURL: call.
    id rawHandoffURL = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY];
    NSString *handoffURLString = [rawHandoffURL isKindOfClass:NSString.class] ? (NSString *)rawHandoffURL : nil;
    NSURL *handoffURL = handoffURLString.length > 0 ? [NSURL URLWithString:handoffURLString] : nil;

    if (!handoffURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                          @"performASWebAuthenticationHandoff called but no valid hand-off URL is available in response headers.");
        NSError *missingURLError = MSIDCreateError(MSIDErrorDomain,
                                                   MSIDErrorInternal,
                                                   @"ASWebAuthentication hand-off requested without a valid hand-off URL.",
                                                   nil, nil, nil, self.context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationDecision failWithError:missingURLError], nil);
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context,
                      @"ASWebAuth hand-off URL found, continuing with ASWebAuth session.");
    [self handleASWebAuthenticationHandoffWithURL:handoffURL
                                 parentController:parentController
                                       completion:completion];
}

#pragma mark - ASWebAuthentication Handoff Handling

- (void)handleASWebAuthenticationHandoffWithURL:(NSURL *)handoffURL
                               parentController:(MSIDViewController *)parentController
                                     completion:(void (^_Nonnull)(MSIDWebviewNavigationDecision * _Nullable navigationDecision, NSError * _Nullable error))completion
{
    // Validate URL format and scheme
    NSError *validationError = nil;
    BOOL isValid = [self isValidHandoffURL:handoffURL
                                     error:&validationError];
    if (!isValid)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                          @"Invalid ASWebAuthentication handoff URL: %@", _PII_NULLIFY(handoffURL.absoluteString));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                         MSIDErrorSessionCanceledProgrammatically,
                                         @"ASWebAuthentication handoff URL is invalid",
                                         nil, nil, validationError, self.context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationDecision failWithError:error], nil);
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"ASWebAuthentication handoff detected: %@", _PII_NULLIFY(handoffURL.absoluteString));
    
    // Extract configuration from ASWebAuth headers
    NSString *callbackURLScheme = [self callbackURLScheme];
    BOOL useEphemeralSession = [self shouldUseEphemeralSession];
    NSDictionary *additionalHeaders = [self extractAdditionalHeadersToForward];
    
    
    [self handleASWebAuthenticationTransition:handoffURL
                            additionalHeaders:additionalHeaders.count > 0 ? additionalHeaders : nil
                               callbackScheme:callbackURLScheme
                          useEphemeralSession:useEphemeralSession
                             parentController:parentController
                                   completion:completion];
}

#pragma mark - ASWebAuthentication Transition Handling

- (void)handleASWebAuthenticationTransition:(NSURL *)URL
                          additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                             callbackScheme:(nonnull NSString *)callbackURLScheme
                        useEphemeralSession:(BOOL)useEphemeralSession
                           parentController:(MSIDViewController *)parentController
                                 completion:(void (^)(MSIDWebviewNavigationDecision * _Nullable, NSError * _Nullable))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Handling ASWebAuthentication transition");
    
    if (!URL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context,
                          @"ASWebAuthentication transition called with no URL, proceeding the flow in embedded webview");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                         @"ASWebAuthentication transition called with no URL",
                                         nil, nil, nil, self.context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationDecision failWithError:error], nil);
        return;
    }
    
    NSString *redirectURI = [NSString stringWithFormat:@"%@://", callbackURLScheme];

    // Schedule the MDM profile-installed reminder *before* handing off to the system
    // browser/Settings, so it can fire while the user is away installing the profile.
    // The post-return `profile_download_complete` callback arrives only after the user is
    // back in Authenticator (foreground), at which point the banner would be suppressed.
    [self scheduleMDMProfileInstalledNotificationIfNeededForURL:URL];

    // Launch ASWebAuthenticationSession with the provided URL and configuration
    [[MSIDSystemWebviewTransitionManager sharedInstance] transitionToSystemWebviewWithURL:URL
                                                                              redirectURI:redirectURI
                                                                         parentController:parentController
                                                                 useAuthenticationSession:YES
                                                                allowSafariViewController:NO
                                                                      useEphemeralSession:useEphemeralSession
                                                                        additionalHeaders:additionalHeaders
                                                                                  context:self.context
                                                                          completionBlock:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
     {
        MSIDWebviewNavigationDecision *navigationDecision;
        
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"[MSIDWebviewNavigationHandler] Transition completed with error: %@", error);
            navigationDecision = [MSIDWebviewNavigationDecision failWithError:error];
        }
        else if (callbackURL)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, self.context, @"[MSIDWebviewNavigationHandler] Transition completed with callback URL: %@", MSID_PII_LOG_MASKABLE(callbackURL));
            navigationDecision = [MSIDWebviewNavigationDecision loadRequest:[NSURLRequest requestWithURL:callbackURL]];
        }
        else
        {
            // Neither URL nor error - unexpected
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"[MSIDWebviewNavigationHandler] Transition completed with neither URL nor error");
            NSError *unexpectedError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                                       @"Transition completed with neither URL nor error",
                                                       nil, nil, nil, self.context.correlationId, nil, YES);
            navigationDecision = [MSIDWebviewNavigationDecision failWithError:unexpectedError];
        }
        
        completion(navigationDecision, nil);
    }];
}

// Arms the MDM profile-installed reminder when the profile-download hand-off begins.
//
// This is invoked right before the profile-download ASWebAuthenticationSession is presented,
// i.e. before the user leaves for Settings. A delayed local notification scheduled here fires
// while Authenticator is backgrounded (user still in Settings) so the banner is actually shown.
// Scheduling on the later `profile_download_complete` callback is too late: that callback only
// arrives after the user returns and the app is foreground again, where banners are suppressed.
- (void)scheduleMDMProfileInstalledNotificationIfNeededForURL:(NSURL *)URL
{
    // Only arm for the MDM profile-download hand-off, not for other ASWebAuthenticationSession transitions.
    if ([URL.absoluteString rangeOfString:@"downloadprofile" options:NSCaseInsensitiveSearch].location == NSNotFound)
    {
        return;
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"[ProfileDownload] Detected MDM profile-download hand-off; scheduling profile-installed notification before system webview transition.");

    NSString *delayString = [[MSIDFlightManager sharedInstance] stringForKey:MSID_FLIGHT_MDM_PROFILE_INSTALLED_NOTIFICATION_DELAY];
    NSTimeInterval delay = delayString.length > 0 ? delayString.doubleValue : MSIDMDMProfileInstalledNotificationDefaultDelay;
    if (delay <= 0)
    {
        delay = MSIDMDMProfileInstalledNotificationDefaultDelay;
    }

    id<MSIDUXCallbackProtocol> provider = MSIDUXCallbackProvider.uxCallbackProvider;
    if (provider)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                          @"[ProfileDownload] Scheduling MDM profile-installed notification with delay %.2f seconds.", delay);
        [provider scheduleMDMProfileInstalledNotificationWithDelay:delay];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                          @"[ProfileDownload] No UX callback provider registered; cannot schedule MDM profile-installed notification.");
    }
}

#endif // !MSID_EXCLUDE_SYSTEMWV

#pragma mark - Private: ASWebAuthentication Handoff Helpers

- (NSDictionary<NSString *, id> *)normalizeHeaders:(NSDictionary *)headers
{
    // Lowercase keys for case-insensitive lookup. Values stay as `id` because
    // `allHeaderFields` values aren't guaranteed NSString (e.g. Set-Cookie).
    NSMutableDictionary<NSString *, id> *normalized = [NSMutableDictionary dictionaryWithCapacity:headers.count];
    
    for (id key in headers.allKeys)
    {
        if (![key isKindOfClass:[NSString class]])
        {
            continue;
        }
        
        NSString *stringKey = (NSString *)key;
        id value = headers[stringKey];
        if (!value)
        {
            continue;
        }
        
        normalized[stringKey.lowercaseString] = value;
    }
    
    return [normalized copy];
}

- (BOOL)isAllowedHandoffOrigin:(NSURL *)responseURL
{
    id<MSIDRequestContext> context = self.context;

    if (!responseURL)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"ASWebAuth hand-off rejected: response URL is nil");
        return NO;
    }

    if ([responseURL.scheme caseInsensitiveCompare:@"https"] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"ASWebAuth hand-off rejected: response URL is not HTTPS (scheme=%@)",
                          _PII_NULLIFY(responseURL.scheme));
        return NO;
    }

    // Reuse the same allowlist that gates the hand-off target so issuer and target are
    // held to a single, consistent trust boundary.
    return [self isURLInAllowedDomains:responseURL];
}


- (BOOL)isValidHandoffURL:(NSURL *)URL
                    error:(NSError *__autoreleasing *)error
{
    NSString *logMessage = nil;
    NSString *errorMessage = nil;
    
    if (!URL)
    {
        logMessage   = @"Invalid ASWebAuthentication handoff URL: URL is nil";
        errorMessage = @"ASWebAuthentication handoff URL is nil";
    }
    else if (URL.scheme.length == 0)
    {
        logMessage   = @"Invalid ASWebAuthentication handoff URL: scheme is missing";
        errorMessage = @"ASWebAuthentication handoff URL scheme is missing";
    }
    else if ([URL.scheme caseInsensitiveCompare:@"https"] != NSOrderedSame)
    {
        logMessage   = [NSString stringWithFormat:@"ASWebAuthentication handoff URL must be HTTPS: %@", _PII_NULLIFY(URL.absoluteString)];
        errorMessage = @"ASWebAuthentication handoff URL must use HTTPS scheme";
    }
    else if (![self isURLInAllowedDomains:URL])
    {
        logMessage   = [NSString stringWithFormat:@"ASWebAuthentication handoff URL domain not in allowlist: %@", _PII_NULLIFY(URL.host)];
        errorMessage = [NSString stringWithFormat:@"ASWebAuthentication handoff URL domain '%@' is not in the allowed domains list", URL.host];
    }
    
    // Valid
    if (!errorMessage)
    {
        return YES;
    }
    
    // Invalid - log and populate error
    id<MSIDRequestContext> context = self.context;
    MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"%@", logMessage);
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain,
                                 MSIDErrorInvalidASWebAuthenticationURL,
                                 errorMessage,
                                 nil, nil, nil,
                                 context.correlationId, nil, YES);
    }
    return NO;
}

- (BOOL)isURLInAllowedDomains:(NSURL *)URL
{
    id<MSIDRequestContext> context = self.context;
    
    // URL.host is nil when URL itself is nil, so a single guard covers both.
    // URL.host is nil when URL itself is nil, so a single guard covers both.
    NSString *host = URL.host.lowercaseString;
    if (host.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"ASWebAuthentication handoff rejected: URL host is missing");
        return NO;
    }
    
    NSSet<NSString *> *allowedDomains = MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains;
    BOOL isAllowed = [allowedDomains containsObject:host];
    
    if (isAllowed)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                          @"ASWebAuthentication handoff domain validated: %@ is in allowlist", host);
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"ASWebAuthentication handoff rejected: Domain %@ is not in the allowlist", host);
    }
    
    return isAllowed;
}

- (NSString *)callbackURLScheme
{
    id<MSIDRequestContext> context = self.context;
    id rawValue = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY];
    NSString *trimmed = [rawValue isKindOfClass:NSString.class]
        ? [(NSString *)rawValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : nil;
    
    if (trimmed.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                          @"ASWebAuthentication received a missing or empty callback URL scheme, defaulting to %@",
                          MSID_SCHEME_MSAUTH);
        return MSID_SCHEME_MSAUTH;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                      @"ASWebAuthentication will use %@ callback URL scheme", trimmed);
    return trimmed;
}

- (BOOL)shouldUseEphemeralSession
{
    id value = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY];
    
    // Default to ephemeral; only opt out when the header is explicitly "false".
    BOOL isExplicitlyFalse = [value isKindOfClass:NSString.class]
        && [value caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_FALSE] == NSOrderedSame;
    BOOL isEphemeral = !isExplicitlyFalse;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"ASWebAuthentication will use %@ session",
                      isEphemeral ? @"ephemeral" : @"persistent");
    
    return isEphemeral;
}

- (nullable NSDictionary<NSString *, NSString *> *)extractAdditionalHeadersToForward
{
    id includeHeadersValue = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY];

    // Only process if explicitly set to "true"
    if (![includeHeadersValue isKindOfClass:NSString.class] ||
        [(NSString *)includeHeadersValue caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_TRUE] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context,
                          @"Headers will not be included (include-headers != 'true')");
        return nil;
    }

    id attachHeadersListValue = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY];
    if (![attachHeadersListValue isKindOfClass:NSString.class] || ((NSString *)attachHeadersListValue).length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                          @"include-headers is true but attach-headers is empty or invalid");
        return nil;
    }

    NSString *attachHeadersList = (NSString *)attachHeadersListValue;

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                      @"Headers will be included in ASWebAuth session");

    return [self buildAdditionalHeadersFromList:attachHeadersList];
}

- (NSDictionary<NSString *, NSString *> *)buildAdditionalHeadersFromList:(NSString *)attachHeadersList
{
    NSMutableDictionary<NSString *, NSString *> *additionalHeaders = [NSMutableDictionary dictionary];
    NSArray<NSString *> *headerNames = [attachHeadersList componentsSeparatedByString:@","];
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    
    for (NSString *headerName in headerNames)
    {
        NSString *trimmed = [headerName stringByTrimmingCharactersInSet:whitespace];
        NSString *lowercaseTrimmed = trimmed.lowercaseString;
        
        // Allow only headers with the ASWebAuth handoff prefix
        if (trimmed.length == 0 || ![lowercaseTrimmed hasPrefix:MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX])
        {
            continue;
        }
        
        // Lookup in lastResponseHeaders (already normalized to lowercase keys).
        id rawValue = self.lastResponseHeaders[lowercaseTrimmed];
        NSString *headerValue = [rawValue isKindOfClass:[NSString class]] ? (NSString *)rawValue : nil;
        
        if (headerValue)
        {
            // Use trimmed (original casing from attach-headers) as the forwarded header key.
            // HTTP headers are case-insensitive, so this casing difference from lowercaseTrimmed
            // used for lookup is harmless, but preserves the casing requested by the server.
            additionalHeaders[trimmed] = headerValue;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context,
                              @"Adding header to ASWebAuthentication: %@ = %@",
                              trimmed, _PII_NULLIFY(headerValue));
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context,
                              @"Header '%@' specified in attach-headers but not found in response",
                              trimmed);
        }
    }
    
    return [additionalHeaders copy];
}

@end

#endif
