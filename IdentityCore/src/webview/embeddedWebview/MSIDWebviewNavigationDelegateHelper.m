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
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDWebviewTransitionHandler.h"
#import "MSIDRequestContext.h"
#import "MSIDWebviewNavigationDelegate.h"
#import "MSIDWebviewConstants.h"

@interface MSIDWebviewNavigationDelegateHelper()

@property (nonatomic) id<MSIDRequestContext> context;
@property (nonatomic) NSDictionary<NSString *, NSString *> *lastResponseHeaders;
@property (nonatomic) MSIDWebviewTransitionHandler *transitionHandler;
@property (nonatomic) MSIDOAuth2EmbeddedWebviewController *embeddedWebview;
@property (nonatomic, weak) MSIDViewController *parentController;

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
                  parentController:(nullable MSIDViewController *)parentController
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Configuring webview controller with navigation delegate helper");
    
    // Set up navigation delegate only if supporrted controller is used
    if ([webviewController isKindOfClass:MSIDOAuth2EmbeddedWebviewController.class])
    {
        self.embeddedWebview = webviewController;
        
        self.embeddedWebview.navigationDelegate = delegate;
        
        // Store weak reference to parent controller for ASWebAuth transitions (if needed)
        self.parentController = parentController;
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                         @"Set up navigationResponseBlock to handle delegate callbacks for special redirects and response header processing.");
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"Webview controller is not EmbeddedWebviewController, skipping navigation delegate setup.");
    }
}

#pragma mark - Navigation Delegate Methods

- (void)handleSpecialRedirectUrl:(NSURL *)url
                    brtEvaluator:(nullable BOOL(^)(void))brtEvaluator
                      brtHandler:(nullable void(^)(void(^)(BOOL success, NSError * _Nullable error)))brtHandler
                         appName:(NSString *)appName
                      appVersion:(NSString *)appVersion
         externalNavigationBlock:(nullable id)externalNavigationBlock
                      completion:(void (^)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion
{
    // Create strong reference to avoid multiple weak property accesses
    id<MSIDRequestContext> context = self.context;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context,
                     @"Helper handling special redirect: %@", _PII_NULLIFY(url));
    
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"Special redirect URL is nil");
        completion(nil, nil);
        return;
    }
    
    // Define the action resolution block - delegate all URL handling to util
    MSIDWebviewNavigationAction * (^resolveAction)(void) = ^MSIDWebviewNavigationAction * {
        MSIDWebviewNavigationActionUtil *util = [MSIDWebviewNavigationActionUtil sharedInstance];
        return [util resolveActionForURL:url
                       webviewController:self.embeddedWebview
                         responseHeaders:self.lastResponseHeaders
                                 appName:appName
                              appVersion:appVersion
                 externalNavigationBlock:externalNavigationBlock];
    };
    
    // Execute with or without BRT based on evaluator
    if (brtEvaluator && brtEvaluator() && brtHandler)
    {
        // BRT needed - acquire it first, then resolve action
        brtHandler(^(__unused BOOL success, __unused NSError *error) {
            MSIDWebviewNavigationAction *action = resolveAction();
            completion(action, nil);
        });
    }
    else
    {
        // No BRT needed - resolve action directly
        MSIDWebviewNavigationAction *action = resolveAction();
        completion(action, nil);
    }
}

- (void)processResponseHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    // Normalize ALL headers (lowercase keys) and store in lastResponseHeaders
    self.lastResponseHeaders = [self normalizeHeaders:headers];
    
    // Check if ASWebAuth handoff URL is present
    NSString *handoffUrlString = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_URL_KEY];
    if ([handoffUrlString isKindOfClass:NSString.class] && handoffUrlString.length > 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, @"ASWebAuth handoff URL found, continuing with ASWebAuth session");
        NSURL *handoffUrl = [NSURL URLWithString:handoffUrlString];
        
        // ASWebAuth handoff detected - handle it
        [self handleASWebAuthenticationHandoffWithURL:handoffUrl
                                 completion: ^(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error)
         {
            [self.embeddedWebview executeWebviewNavigationAction:action
                                                      requestURL:handoffUrl
                                                           error:error];
        }];
    }
    
    // TODO: Add telemetry for response headers
    [self.te]
}

#pragma mark - ASWebAuthentication Handoff Handling

- (void)handleASWebAuthenticationHandoffWithURL:(NSURL *)handoffUrl
                                     completion:(void (^_Nonnull)(MSIDWebviewNavigationAction * _Nullable action, NSError * _Nullable error))completion
{
    // Create local reference to avoid multiple property access overhead
    id<MSIDRequestContext> context = self.context;
    
    // Validate URL format and scheme
    NSError *validationError = nil;
    BOOL isValid = YES;//[self isValidaHandoffURL:handoffUrl
                                      //error:&validationError];
    if (!isValid)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Invalid ASWebAuthentication handoff URL: %@", _PII_NULLIFY(handoffUrl.absoluteString));
        NSError *error = MSIDCreateError(MSIDErrorDomain,
                                MSIDErrorSessionCanceledProgrammatically,
                                @"ASWebAuthentication handoff URL is invalid",
                                nil, nil, validationError,
                                context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"ASWebAuthentication handoff detected: %@", _PII_NULLIFY(handoffUrl.absoluteString));
    
    // Extract configuration from ASWebAuth headers
    NSString *callbackURLScheme = [self callbackURLScheme];
    BOOL useEphemeralSession = [self shouldUseEphemeralSession];
    NSDictionary *additionalHeaders = [self extractAdditionalHeadersToForward];
    
    
    [self handleASWebAuthenticationTransition:handoffUrl
                                embeddedWebview:self.embeddedWebview
                                additionalHeaders:additionalHeaders.count > 0 ? additionalHeaders : nil
                               callbackScheme:callbackURLScheme
                                useEphemeralSession:useEphemeralSession
                                parentController:self.parentController
                                completion:completion];
}

#pragma mark - ASWebAuthentication Transition Handling

- (void)handleASWebAuthenticationTransition:(NSURL *)url
                           embeddedWebview:(MSIDOAuth2EmbeddedWebviewController *)embeddedWebview
                         additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders
                             callbackScheme:(nonnull NSString *)callbackURLScheme
                        useEphemeralSession:(BOOL)useEphemeralSession
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
    
    if (!embeddedWebview)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Cannot suspend webview - no current webview found");
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal,
                                        @"No current webview found for suspension",
                                        nil, nil, nil, context.correlationId, nil, YES);
        completion([MSIDWebviewNavigationAction failWebAuthWithErrorAction:error], nil);
        return;
    }
    
    // Suspend the embedded webview (hide but keep alive)
    [self.transitionHandler suspendEmbeddedWebview:embeddedWebview];
    [self.transitionHandler launchASWebAuthenticationSessionWithUrl:url
                                                   parentController:parentController
                                                  additionalHeaders:additionalHeaders
                                                     callbackScheme:callbackURLScheme
                                                 useEmpheralSession:useEphemeralSession
                                                            context:context
                                                         completion:^(MSIDWebviewNavigationAction * _Nonnull action, NSError * _Nonnull error)
     {
        completion(action, error);
    }];
}

#pragma mark - Private: ASWebAuthentication Handoff Helpers

- (NSDictionary<NSString *, NSString *> *)normalizeHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    NSMutableDictionary<NSString *, NSString *> *normalized = [NSMutableDictionary dictionary];
    
    for (NSString *key in headers.allKeys)
    {
        // Normalize to lowercase for case-insensitive lookup
        normalized[key.lowercaseString] = headers[key];
    }
    
    return [normalized copy];
}

- (BOOL)isValidaHandoffURL:(NSURL *)url
                     error:(NSError *__autoreleasing *)error
{
    id<MSIDRequestContext> context = self.context;
    
    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"Invalid ASWebAuthentication handoff URL: URL is nil");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                    MSIDErrorInvalidASWebAuthenticationURL,
                                    @"ASWebAuthentication handoff URL is nil",
                                    nil, nil, nil,
                                    context.correlationId, nil, YES);
        }
        
        return NO;
    }
    
    // Validate HTTPS scheme
    if ([@"https" caseInsensitiveCompare:url.scheme] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"ASWebAuthentication handoff URL must be HTTPS: %@", _PII_NULLIFY(url.absoluteString));
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                    MSIDErrorInvalidASWebAuthenticationURL,
                                    @"ASWebAuthentication handoff URL must use HTTPS scheme",
                                    nil, nil, nil,
                                    context.correlationId, nil, YES);
        }
        
        return NO;
    }
    
    // Validate domain against allowlist
    if (![self isURLInAllowedDomains:url])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context,
                         @"ASWebAuthentication handoff URL domain not in allowlist: %@", _PII_NULLIFY(url.host));
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                    MSIDErrorInvalidASWebAuthenticationURL,
                                    [NSString stringWithFormat:@"ASWebAuthentication handoff URL domain '%@' is not in the allowed domains list", url.host],
                                    nil, nil, nil,
                                    context.correlationId, nil, YES);
        }
        
        return NO;
    }
    
    return YES;
}

- (BOOL)isURLInAllowedDomains:(NSURL *)url
{
    id<MSIDRequestContext> context = self.context;
    if (!url || !url.host)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"ASWebAuthentication handoff validation failed: URL or host is nil");
        return NO;
    }
    
    // Extract and normalize host component from the handoff URL
    NSString *host = url.host.lowercaseString;
    NSSet<NSString *> *allowedDomains = MSIDASWebAuthenticationConstants.asWebAuthAllowedDomains;
    
    // Check exact match
    if ([allowedDomains containsObject:host])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"ASWebAuthentication handoff domain validated: %@ is in allowlist", host);
        return YES;
    }
    
    // Domain not allowlisted - fail handoff per security requirements
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"ASWebAuthentication handoff rejected: Domain %@ is not in the allowlist", host);
    return NO;
}

- (NSString *)callbackURLScheme
{
    NSString *callbackURLScheme = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_REDIRECT_SCHEME_KEY];
    
    if (![callbackURLScheme isKindOfClass:NSString.class])
    {
        return MSID_SCHEME_MSAUTH; // Default to msauth
    }
    
    id<MSIDRequestContext> context = self.context;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"ASWebAuthentication will use %@ callback URL scheme", callbackURLScheme);
    
    return callbackURLScheme;
}


- (BOOL)shouldUseEphemeralSession
{
    NSString *value = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_USE_EPHEMERAL_KEY];
    
    if (![value isKindOfClass:NSString.class])
    {
        return YES; // Default to ephemeral
    }
    
    // Only return NO if explicitly set to "false"
    BOOL isEphemeral = [value caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_FALSE] != NSOrderedSame;
    
    id<MSIDRequestContext> context = self.context;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"ASWebAuthentication will use %@ session",
                     isEphemeral ? @"ephemeral" : @"persistent");
    
    return isEphemeral;
}

- (nullable NSDictionary<NSString *, NSString *> *)extractAdditionalHeadersToForward
{
    id<MSIDRequestContext> context = self.context;
    NSString *includeHeaders = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_INCLUDE_HEADERS_KEY];
    
    // Only process if explicitly set to "true"
    if ([includeHeaders caseInsensitiveCompare:MSID_ASWEBAUTH_HANDOFF_VALUE_TRUE] != NSOrderedSame)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                         @"Headers will not be included (include-headers != 'true')");
        return nil;
    }
    
    NSString *attachHeadersList = self.lastResponseHeaders[MSID_ASWEBAUTH_HANDOFF_ATTACH_HEADERS_KEY];
    if (![attachHeadersList isKindOfClass:NSString.class] || attachHeadersList.length == 0)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                         @"include-headers is true but attach-headers is empty or invalid");
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context,
                     @"Headers will be included in ASWebAuth session");
    
    return [self buildAdditionalHeadersFromList:attachHeadersList];
}

- (NSDictionary<NSString *, NSString *> *)buildAdditionalHeadersFromList:(NSString *)attachHeadersList
{
    id<MSIDRequestContext> context = self.context;
    NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
    NSArray<NSString *> *headerNames = [attachHeadersList componentsSeparatedByString:@","];
    
    for (NSString *headerName in headerNames)
    {
        NSString *trimmed = [headerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *lowercaseTrimmed = [trimmed lowercaseString];
        
        // Allow only headers with the ASWebAuth handoff prefix
        if (trimmed.length == 0 || ![lowercaseTrimmed hasPrefix:MSID_ASWEBAUTH_HANDOFF_HEADER_PREFIX])
        {
            continue;
        }
        
        // Lookup in asWebAuthHandoffHeaders (already filtered and normalized)
        NSString *headerValue = self.lastResponseHeaders[lowercaseTrimmed];
        
        if (headerValue)
        {
            additionalHeaders[trimmed] = headerValue;
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context,
                             @"Adding header to ASWebAuthentication: %@ = %@",
                             trimmed, _PII_NULLIFY(headerValue));
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                             @"Header '%@' specified in attach-headers but not found in response",
                             trimmed);
        }
    }
    
    return additionalHeaders.count > 0 ? additionalHeaders : nil;
}

@end
