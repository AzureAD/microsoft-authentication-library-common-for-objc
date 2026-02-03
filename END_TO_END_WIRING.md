# End-to-End Wiring Guide: Special URL Handling Framework

This document provides a comprehensive guide for wiring the special URL handling framework into production code. The framework supports handling of `msauth://` and `browser://` URLs with a state machine architecture separating controller actions from view actions.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Components](#components)
3. [Integration Points](#integration-points)
4. [Complete Flow: Intune Enrollment](#complete-flow-intune-enrollment)
5. [Production Wiring Checklist](#production-wiring-checklist)
6. [Code Examples](#code-examples)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Layer Separation

The framework uses a clean separation between:

- **Controller Actions**: State-machine-driven async operations (e.g., AcquireBRTOnce, RetryInBroker)
- **View Actions**: Operations the embedded webview controller executes (e.g., LoadRequest, OpenASWebAuth, CompleteWithURL)

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Interactive Flow                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  MSIDLocalInteractiveController                  │
│  - Orchestrates authentication flow                              │
│  - Implements MSIDInteractiveWebviewHandler protocol             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│               MSIDOAuth2EmbeddedWebviewController                │
│  - Hosts WKWebView                                               │
│  - Captures HTTP response headers (responseHeaderHandler)        │
│  - Owns MSIDInteractiveWebviewStateMachine                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│             MSIDInteractiveWebviewStateMachine                   │
│  - handleSpecialURL:navigationAction:completion:                 │
│  - Runs controller actions until stable                          │
│  - Resolves view actions via handler                             │
└─────────────────────────────────────────────────────────────────┘
         ↙                                          ↘
┌─────────────────────────┐              ┌──────────────────────────┐
│  Controller Actions     │              │  View Actions            │
│  - AcquireBRTOnce       │              │  - LoadRequest           │
│  - RetryInBroker        │              │  - OpenASWebAuth         │
└─────────────────────────┘              │  - CompleteWithURL       │
                                         └──────────────────────────┘
```

---

## Components

### 1. MSIDWebviewAction (View Actions)

**Purpose**: Represents an action for the webview controller to execute.

**Types**:
- `MSIDWebviewActionTypeNoop` - No operation
- `MSIDWebviewActionTypeLoadRequestInWebview` - Load URL request
- `MSIDWebviewActionTypeOpenASWebAuthenticationSession` - Open system webview
- `MSIDWebviewActionTypeOpenExternalBrowser` - Open Safari
- `MSIDWebviewActionTypeCompleteWithURL` - Complete with URL
- `MSIDWebviewActionTypeFailWithError` - Fail with error

**Key Properties**:
```objc
@property (nonatomic, readonly) MSIDWebviewActionType type;
@property (nonatomic, readonly, nullable) NSURLRequest *request;
@property (nonatomic, readonly, nullable) NSURL *url;
@property (nonatomic, readonly) MSIDSystemWebviewPurpose purpose;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;
```

**Convenience Constructors**:
```objc
+ (instancetype)noopAction;
+ (instancetype)loadRequestAction:(NSURLRequest *)request;
+ (instancetype)openASWebAuthSessionAction:(NSURL *)url purpose:(MSIDSystemWebviewPurpose)purpose;
+ (instancetype)openASWebAuthSessionAction:(NSURL *)url purpose:(MSIDSystemWebviewPurpose)purpose additionalHeaders:(NSDictionary *)headers;
+ (instancetype)openExternalBrowserAction:(NSURL *)url;
+ (instancetype)completeWithURLAction:(NSURL *)url;
+ (instancetype)failWithErrorAction:(NSError *)error;
```

### 2. MSIDInteractiveWebviewState (Session State)

**Purpose**: Tracks state across URL interceptions and controller actions.

**BRT Gate Tracking**:
```objc
@property (nonatomic, assign) BOOL brtGateEncountered;
@property (nonatomic, assign) BOOL brtAttempted;
@property (nonatomic, assign) BOOL brtAcquired;
```

**Per-Intercept State**:
```objc
@property (nonatomic, strong, nullable) NSURL *pendingURL;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *queryParams;
@property (nonatomic, assign) BOOL isGateScheme;
@property (nonatomic, assign) BOOL isRunningInBrokerContext;
```

**HTTP Headers** (Captured from all responses):
```objc
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *responseHeaders;
```

**Policy & Transfer**:
```objc
@property (nonatomic, assign) MSIDWebviewBRTFailurePolicy brtFailurePolicy;
@property (nonatomic, assign) BOOL transferredToBroker;
```

### 3. MSIDInteractiveWebviewHandler (Protocol)

**Purpose**: Handler protocol for policy decisions and action implementations.

**Context & Policy Methods**:
```objc
- (BOOL)isRunningInBrokerContext;
- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;
- (MSIDWebviewBRTFailurePolicy)brtFailurePolicyForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;
- (BOOL)shouldRetryInBrokerForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;
```

**Action Implementations**:
```objc
- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (NSError *)genericBrtError;
- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url completion:(void (^)(BOOL success, NSError *error))completion;
- (void)dismissEmbeddedWebviewIfPresent;
```

**View Resolver & Telemetry**:
```objc
- (MSIDWebviewAction *)viewActionForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state;
- (void)handleWebviewResponseForTelemetry:(NSHTTPURLResponse *)response;
```

### 4. MSIDInteractiveWebviewStateMachine

**Purpose**: Orchestrates controller actions and resolves view actions.

**Key Method**:
```objc
- (void)handleSpecialURL:(NSURL *)url
        navigationAction:(WKNavigationAction *)navigationAction
              completion:(void (^)(MSIDWebviewAction *action, NSError *error))completion;
```

**Flow**:
1. Parse URL and update state
2. Run controller actions until stable (`runUntilStable`)
3. Resolve view action via handler
4. Return action to webview controller

### 5. MSIDSpecialURLViewActionResolver

**Purpose**: Maps special URLs to view actions with header support.

**URL Patterns Handled**:
- `msauth://enroll?cpurl=...` → LoadRequest
- `msauth://compliance?cpurl=...` → LoadRequest
- `msauth://installProfile?url=...&requireASWebAuth=true` → OpenASWebAuth
- `msauth://profileComplete` → CompleteWithURL
- `browser://...` → CompleteWithURL

**Header Handling**:
- Extracts `X-Install-Url` from headers (priority #1)
- Falls back to `url` query param (priority #2)
- Passes `X-Intune-AuthToken` in `additionalHeaders`

### 6. Controller Actions

**MSIDAcquireBRTOnceControllerAction**:
- Calls `handler.acquireBRTTokenWithCompletion:`
- Updates state flags: `brtAttempted`, `brtAcquired`

**MSIDRetryInBrokerControllerAction**:
- Calls `handler.retryInteractiveRequestInBrokerContextForURL:completion:`
- Sets `state.transferredToBroker = YES`
- Calls `handler.dismissEmbeddedWebviewIfPresent`

---

## Integration Points

### Integration Point 1: Webview Controller → State Machine

**Where**: `MSIDOAuth2EmbeddedWebviewController` (or subclass)

**What to Add**:
```objc
@interface MSIDOAuth2EmbeddedWebviewController ()
@property (nonatomic, strong) MSIDInteractiveWebviewStateMachine *stateMachine;
@end

@implementation MSIDOAuth2EmbeddedWebviewController

- (instancetype)initWithConfiguration:(MSIDWebviewConfiguration *)configuration {
    self = [super init];
    if (self) {
        // ... existing init
        
        // NEW: Initialize state machine with handler
        self.stateMachine = [[MSIDInteractiveWebviewStateMachine alloc] initWithHandler:self.handler];
    }
    return self;
}
```

### Integration Point 2: Capture Headers in Navigation Response

**Where**: `decidePolicyForNavigationResponse` in webview controller

**What to Add** (Already implemented):
```objc
- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse 
    decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    // Existing navigationResponseBlock call...
    
    // Capture headers for all HTTP responses
    if (self.responseHeaderHandler && navigationResponse.response)
    {
        self.responseHeaderHandler(navigationResponse.response);
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}
```

**Handler Setup** (Already implemented in MSIDAADWebviewFactory):
```objc
embeddedWebviewController.responseHeaderHandler = ^(NSURLResponse *response) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]])
    {
        strongController.lastResponseHeaders = httpResponse.allHeaderFields;
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, @"Captured HTTP headers for URL: %@", response.URL);
    }
};
```

### Integration Point 3: Intercept Special URLs in Navigation Action

**Where**: `decidePolicyForNavigationAction` in webview controller

**What to Add**:
```objc
- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    // Check if special URL (msauth:// or browser://)
    if ([scheme isEqualToString:@"msauth"] || [scheme isEqualToString:@"browser"])
    {
        // Transfer headers from last response to state
        self.stateMachine.state.responseHeaders = self.lastResponseHeaders;
        
        // Handle via state machine
        __weak typeof(self) weakSelf = self;
        [self.stateMachine handleSpecialURL:url 
                           navigationAction:navigationAction 
                                 completion:^(MSIDWebviewAction *action, NSError *error) {
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            
            if (error) {
                [strongSelf handleError:error];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            
            // Execute the view action
            [strongSelf executeViewAction:action decisionHandler:decisionHandler];
        }];
        return;
    }
    
    // Normal navigation
    decisionHandler(WKNavigationActionPolicyAllow);
}
```

### Integration Point 4: Execute View Actions

**Where**: `MSIDOAuth2EmbeddedWebviewController`

**What to Add**:
```objc
- (void)executeViewAction:(MSIDWebviewAction *)action 
          decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    switch (action.type) {
        case MSIDWebviewActionTypeNoop:
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeLoadRequestInWebview:
            [self.webView loadRequest:action.request];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeOpenASWebAuthenticationSession:
            [self openSystemWebviewWithURL:action.url 
                                   purpose:action.purpose 
                         additionalHeaders:action.additionalHeaders];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeOpenExternalBrowser:
            [[UIApplication sharedApplication] openURL:action.url options:@{} completionHandler:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeCompleteWithURL:
            [self completeWebAuthWithURL:action.url];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeFailWithError:
            [self endWebAuthWithURL:nil error:action.error];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        default:
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
    }
}
```

### Integration Point 5: Implement Handler Protocol

**Where**: `MSIDLocalInteractiveController` (or appropriate controller)

**What to Add**:
```objc
@interface MSIDLocalInteractiveController () <MSIDInteractiveWebviewHandler>
@end

@implementation MSIDLocalInteractiveController

#pragma mark - MSIDInteractiveWebviewHandler

- (BOOL)isRunningInBrokerContext
{
    // Check if we're running in broker or standalone app
    return [MSIDBrokerKeyProvider applicationIsCapableOfBrokerCommunication];
}

- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Policy: Acquire BRT once per session if not already acquired
    return state.brtGateEncountered && !state.brtAttempted;
}

- (MSIDWebviewBRTFailurePolicy)brtFailurePolicyForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Policy: Continue flow even if BRT acquisition fails
    return MSIDWebviewBRTFailurePolicyContinue;
}

- (BOOL)shouldRetryInBrokerForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Retry in broker for profileComplete if not in broker context
    if ([url.host.lowercaseString isEqualToString:@"profilecomplete"] &&
        ![self isRunningInBrokerContext] &&
        !state.transferredToBroker)
    {
        return YES;
    }
    return NO;
}

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    // Implement BRT token acquisition
    // This is a placeholder - actual implementation depends on BRT flow
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(YES, nil);
    });
}

- (NSError *)genericBrtError
{
    return MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"BRT acquisition failed", nil, nil, nil, nil, nil, NO);
}

- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url 
                                          completion:(void (^)(BOOL success, NSError *error))completion
{
    // Transfer to broker interactive flow
    // Implementation depends on broker integration
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Transferring to broker for URL: %@", url);
    
    // Example: Switch to broker interactive controller
    // [self.brokerController acquireTokenInteractivelyWithCompletion:...];
    
    completion(YES, nil);
}

- (void)dismissEmbeddedWebviewIfPresent
{
    // Dismiss the webview controller
    if (self.webviewController) {
        [self.webviewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (MSIDWebviewAction *)viewActionForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Delegate to resolver
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
}

- (void)handleWebviewResponseForTelemetry:(NSHTTPURLResponse *)response
{
    // Extract telemetry headers and log/process
    NSString *telemetryHeader = response.allHeaderFields[@"X-MS-Telemetry"];
    if (telemetryHeader) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Telemetry: %@", telemetryHeader);
        // Process telemetry data...
    }
}

@end
```

### Integration Point 6: System Webview with Headers

**Where**: System webview handler (e.g., `MSIDSystemWebviewHandler`)

**What to Add**:
```objc
- (void)openSystemWebviewWithURL:(NSURL *)url 
                         purpose:(MSIDSystemWebviewPurpose)purpose
               additionalHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    // Note: ASWebAuthenticationSession doesn't support custom HTTP headers directly
    // Headers are available for other purposes (logging, encoding in URL, etc.)
    
    BOOL isEphemeral = (purpose == MSIDSystemWebviewPurposeInstallProfile);
    
    // Log headers for debugging
    if (headers.count > 0) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                         @"Opening ASWebAuth with headers: %@", headers);
    }
    
    // Create and present ASWebAuthenticationSession
    ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc] 
        initWithURL:url 
        callbackURLScheme:@"msauth" 
        completionHandler:^(NSURL *callbackURL, NSError *error) {
            [self handleSystemWebviewCallback:callbackURL error:error];
        }];
    
    if (@available(iOS 13.0, *)) {
        session.prefersEphemeralWebBrowserSession = isEphemeral;
    }
    
    [session start];
}
```

---

## Complete Flow: Intune Enrollment

This section shows the complete end-to-end flow for Intune device enrollment using the framework.

### Sequence Diagram

```
User                WKWebView           Server              StateMachine        Handler             ASWebAuth
 |                     |                  |                      |                  |                   |
 |--Navigate to------->|                  |                      |                  |                   |
 |   Intune portal     |                  |                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |---Auth Request-->|                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |<--msauth://------|                      |                  |                   |
 |                     |   installProfile |                      |                  |                   |
 |                     |   Headers:       |                      |                  |                   |
 |                     |   X-Intune-AuthToken                     |                  |                   |
 |                     |   X-Install-Url  |                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |--decidePolicyForNavigationResponse----->|                  |                   |
 |                     |  (captures headers)                     |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |--decidePolicyForNavigationAction------->|                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                 handleSpecialURL()      |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--isRunningIn---->|                   |
 |                     |                  |                      |  BrokerContext?  |                   |
 |                     |                  |                      |<--No-------------|                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--shouldAcquire-->|                   |
 |                     |                  |                      |  BRT?            |                   |
 |                     |                  |                      |<--No-------------|                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--viewAction----->|                   |
 |                     |                  |                      |  ForSpecialURL   |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |       Resolver extracts:             |
 |                     |                  |                      |       - URL from X-Install-Url       |
 |                     |                  |                      |       - X-Intune-AuthToken           |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |<--OpenASWebAuth--|                   |
 |                     |                  |                      |   Action         |                   |
 |                     |                  |                      |                  |                   |
 |                     |<--Action---------+----------------------|                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |--executeViewAction()                    |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |--openSystemWebview(url, headers)--------|----------------->|------------------>|
 |                     |                  |                      |                  |                   |
 |<--------------------|------------------|----------------------|------------------|-------------------|
 |  Enrollment UI      |                  |                      |                  |                   |
 |  in ASWebAuth       |                  |                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |--Complete---------->|                  |                      |                  |                   |
 |  enrollment         |                  |                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |<--msauth://------|                      |                  |                   |
 |                     |   profileComplete|                      |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |--handleSpecialURL()-------------------->|                  |                   |
 |                     |  (profileComplete)|                     |                  |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--shouldRetry---->|                   |
 |                     |                  |                      |  InBroker?       |                   |
 |                     |                  |                      |<--Yes------------|                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |         RetryInBrokerAction created    |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--retry---------->|                   |
 |                     |                  |                      |  InBroker()      |                   |
 |                     |                  |                      |                  |                   |
 |                     |                  |                      |--dismiss-------->|                   |
 |                     |                  |                      |  Webview()       |                   |
 |                     |                  |                      |                  |                   |
 |                     |<--Dismissed------|----------------------|------------------|                   |
 |                     |                  |                      |                  |                   |
 |<--------------------|------------------|-Broker Interactive Flow Continues-------|                   |
```

### Step-by-Step Code Flow

#### Step 1: User Navigates to Intune
```objc
// Standard WKWebView navigation - no special handling needed
[webView loadRequest:[NSURLRequest requestWithURL:intuneURL]];
```

#### Step 2: Server Responds with msauth://installProfile

**HTTP Response**:
```
HTTP/1.1 302 Found
Location: msauth://installProfile?url=https://backup.url&requireASWebAuth=true
X-Intune-AuthToken: eyJ0eXAiOiJKV1QiLCJhbGc...
X-Install-Url: https://portal.manage.microsoft.com/EnrollmentProfiles/Profile/...
```

#### Step 3: Capture Headers (Already Wired)

```objc
// In decidePolicyForNavigationResponse
- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse 
    decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    // responseHeaderHandler is called
    // → stores headers in self.lastResponseHeaders
    decisionHandler(WKNavigationResponsePolicyAllow);
}
```

#### Step 4: Intercept Navigation Action

```objc
// In decidePolicyForNavigationAction
- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    
    if ([url.scheme.lowercaseString isEqualToString:@"msauth"]) {
        // Transfer captured headers to state
        self.stateMachine.state.responseHeaders = self.lastResponseHeaders;
        
        // Handle via state machine
        [self.stateMachine handleSpecialURL:url 
                           navigationAction:navigationAction 
                                 completion:^(MSIDWebviewAction *action, NSError *error) {
            if (action) {
                [self executeViewAction:action decisionHandler:decisionHandler];
            } else {
                decisionHandler(WKNavigationActionPolicyCancel);
            }
        }];
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}
```

#### Step 5: State Machine Processes URL

```objc
// Inside MSIDInteractiveWebviewStateMachine.handleSpecialURL:
- (void)handleSpecialURL:(NSURL *)url 
        navigationAction:(WKNavigationAction *)navigationAction 
              completion:(void (^)(MSIDWebviewAction *, NSError *))completion
{
    // 1. Update state
    self.state.pendingURL = url;
    self.state.queryParams = [self parseQueryParams:url];
    self.state.isRunningInBrokerContext = [self.handler isRunningInBrokerContext];
    
    // 2. Run controller actions until stable
    [self runUntilStableWithCompletion:^(NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        // 3. Resolve view action
        MSIDWebviewAction *viewAction = [self.handler viewActionForSpecialURL:url state:self.state];
        
        // 4. Return action
        completion(viewAction, nil);
    }];
}
```

#### Step 6: Run Controller Actions

```objc
// Inside runUntilStableWithCompletion:
- (void)runUntilStableWithCompletion:(void (^)(NSError *))completion
{
    // Check if any controller action needs to run
    id<MSIDWebviewControllerAction> nextAction = [self nextControllerActionForState:self.state];
    
    if (!nextAction) {
        // Stable state reached
        completion(nil);
        return;
    }
    
    // Execute controller action
    [nextAction executeWithState:self.state handler:self.handler completion:^(NSError *error) {
        if (error) {
            completion(error);
            return;
        }
        
        // Recurse until stable
        [self runUntilStableWithCompletion:completion];
    }];
}
```

#### Step 7: Resolve View Action

```objc
// Handler delegates to resolver
- (MSIDWebviewAction *)viewActionForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
}

// In MSIDSpecialURLViewActionResolver
+ (MSIDWebviewAction *)resolveActionForURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    NSString *host = url.host.lowercaseString ?: @"";
    
    if ([host isEqualToString:@"installprofile"]) {
        return [self resolveInstallProfileAction:queryParams state:state];
    }
    // ... other patterns
}

+ (MSIDWebviewAction *)resolveInstallProfileAction:(NSDictionary *)queryParams 
                                             state:(MSIDInteractiveWebviewState *)state
{
    // Extract headers from state
    NSDictionary *headers = state.responseHeaders;
    
    // Priority 1: X-Install-Url from headers
    NSString *installURLString = headers[@"X-Install-Url"];
    NSURL *profileURL = installURLString ? [NSURL URLWithString:installURLString] : nil;
    
    // Priority 2: Fallback to url query param
    if (!profileURL) {
        NSString *urlParam = queryParams[@"url"];
        profileURL = urlParam ? [NSURL URLWithString:urlParam] : nil;
    }
    
    // Check if ASWebAuth required
    BOOL requireASWebAuth = [queryParams[@"requireASWebAuthenticationSession"] boolValue];
    
    if (requireASWebAuth && profileURL) {
        // Extract X-Intune-AuthToken for additionalHeaders
        NSString *authToken = headers[@"X-Intune-AuthToken"];
        NSDictionary *authHeaders = authToken ? @{@"X-Intune-AuthToken": authToken} : nil;
        
        // Create action
        return [MSIDWebviewAction openASWebAuthSessionAction:profileURL 
                                                      purpose:MSIDSystemWebviewPurposeInstallProfile
                                            additionalHeaders:authHeaders];
    }
    
    // ... other cases
}
```

#### Step 8: Execute View Action

```objc
// Back in webview controller
- (void)executeViewAction:(MSIDWebviewAction *)action 
          decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    switch (action.type) {
        case MSIDWebviewActionTypeOpenASWebAuthenticationSession:
            // Open system webview with URL and headers
            [self openSystemWebviewWithURL:action.url 
                                   purpose:action.purpose 
                         additionalHeaders:action.additionalHeaders];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
        // ... other cases
    }
}
```

#### Step 9: Open ASWebAuthenticationSession

```objc
- (void)openSystemWebviewWithURL:(NSURL *)url 
                         purpose:(MSIDSystemWebviewPurpose)purpose
               additionalHeaders:(NSDictionary *)headers
{
    BOOL isEphemeral = (purpose == MSIDSystemWebviewPurposeInstallProfile);
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                     @"Opening ASWebAuth for installProfile with URL: %@", url);
    
    // Note: Headers logged but not passed to ASWebAuth API (not supported)
    // Could encode in URL or use for other purposes
    if (headers[@"X-Intune-AuthToken"]) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                         @"X-Intune-AuthToken available for profile installation");
    }
    
    ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc] 
        initWithURL:url 
        callbackURLScheme:@"msauth" 
        completionHandler:^(NSURL *callbackURL, NSError *error) {
            [self handleSystemWebviewCallback:callbackURL error:error];
        }];
    
    if (@available(iOS 13.0, *)) {
        session.prefersEphemeralWebBrowserSession = isEphemeral;
    }
    
    [session start];
}
```

#### Step 10: User Completes Enrollment

User interacts with Intune enrollment UI in ASWebAuthenticationSession and completes profile installation.

#### Step 11: Profile Complete Callback

```objc
- (void)handleSystemWebviewCallback:(NSURL *)callbackURL error:(NSError *)error
{
    if (error) {
        [self endWebAuthWithURL:nil error:error];
        return;
    }
    
    // callbackURL = msauth://profileComplete
    // This triggers another handleSpecialURL cycle
    [self.stateMachine handleSpecialURL:callbackURL 
                       navigationAction:nil 
                             completion:^(MSIDWebviewAction *action, NSError *error) {
        [self executeViewAction:action decisionHandler:nil];
    }];
}
```

#### Step 12: Check Broker Context and Retry

```objc
// In state machine for profileComplete URL
- (void)handleSpecialURL:(NSURL *)url ... {
    // ... state update
    
    // Controller action: shouldRetryInBroker?
    if ([self.handler shouldRetryInBrokerForSpecialURL:url state:self.state]) {
        MSIDRetryInBrokerControllerAction *retryAction = 
            [[MSIDRetryInBrokerControllerAction alloc] initWithURL:url];
        
        [retryAction executeWithState:self.state handler:self.handler completion:^(NSError *error) {
            // state.transferredToBroker = YES
            // Embedded webview dismissed
            // Flow continues in broker
        }];
    }
}
```

---

## Production Wiring Checklist

Use this checklist to wire the framework into production:

### Phase 1: State Machine Integration

- [ ] Add `stateMachine` property to `MSIDOAuth2EmbeddedWebviewController`
- [ ] Initialize state machine in webview controller `init` or factory method
- [ ] Pass handler instance to state machine (implement `MSIDInteractiveWebviewHandler`)
- [ ] Ensure state machine is retained for lifetime of webview session

### Phase 2: Header Capture (✅ Already Done)

- [x] `responseHeaderHandler` property added to webview controller
- [x] Handler set in `MSIDAADWebviewFactory`
- [x] Headers captured for all HTTP responses
- [x] Headers stored in `lastResponseHeaders` property

### Phase 3: Special URL Interception

- [ ] Update `decidePolicyForNavigationAction` to detect special URLs
- [ ] Transfer `lastResponseHeaders` to `stateMachine.state.responseHeaders`
- [ ] Call `stateMachine.handleSpecialURL:completion:` for special URLs
- [ ] Handle completion callback and execute returned action

### Phase 4: View Action Execution

- [ ] Implement `executeViewAction:decisionHandler:` method
- [ ] Handle all action types:
  - [ ] Noop
  - [ ] LoadRequestInWebview
  - [ ] OpenASWebAuthenticationSession
  - [ ] OpenExternalBrowser
  - [ ] CompleteWithURL
  - [ ] FailWithError
- [ ] Ensure proper navigation policy returned

### Phase 5: Handler Protocol Implementation

- [ ] Implement `isRunningInBrokerContext` in interactive controller
- [ ] Implement `shouldAcquireBRTForSpecialURL:state:` policy
- [ ] Implement `brtFailurePolicyForSpecialURL:state:` policy
- [ ] Implement `shouldRetryInBrokerForSpecialURL:state:` policy
- [ ] Implement `acquireBRTTokenWithCompletion:` action
- [ ] Implement `retryInteractiveRequestInBrokerContextForURL:completion:` action
- [ ] Implement `dismissEmbeddedWebviewIfPresent` action
- [ ] Implement `viewActionForSpecialURL:state:` resolver hook
- [ ] Implement `handleWebviewResponseForTelemetry:` telemetry hook

### Phase 6: System Webview Integration

- [ ] Update system webview handler to accept `additionalHeaders` parameter
- [ ] Log headers when opening ASWebAuthenticationSession
- [ ] Handle ephemeral session based on `purpose` parameter
- [ ] Wire callback handling back to state machine for `profileComplete`

### Phase 7: Testing

- [ ] Unit test state machine with mock handler
- [ ] Unit test controller actions
- [ ] Unit test resolver with various URL patterns
- [ ] Integration test full installProfile flow
- [ ] Integration test broker retry flow
- [ ] Test header extraction and passing
- [ ] Test telemetry header processing

### Phase 8: Feature Flags & Rollout

- [ ] Add feature flag to enable/disable new framework
- [ ] Keep existing flow as fallback
- [ ] Gradual rollout with monitoring
- [ ] Verify no regressions in existing flows

---

## Code Examples

### Example: Full Webview Controller Integration

```objc
@interface MSIDOAuth2EmbeddedWebviewController ()
@property (nonatomic, strong) MSIDInteractiveWebviewStateMachine *stateMachine;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *lastResponseHeaders;
@end

@implementation MSIDOAuth2EmbeddedWebviewController

- (instancetype)initWithConfiguration:(MSIDWebviewConfiguration *)configuration 
                              handler:(id<MSIDInteractiveWebviewHandler>)handler
{
    self = [super initWithConfiguration:configuration];
    if (self) {
        _stateMachine = [[MSIDInteractiveWebviewStateMachine alloc] initWithHandler:handler];
    }
    return self;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse 
    decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    // Capture headers (already implemented)
    if (self.responseHeaderHandler && navigationResponse.response) {
        self.responseHeaderHandler(navigationResponse.response);
    }
    
    // Existing navigationResponseBlock...
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView 
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    // Check if special URL
    if ([scheme isEqualToString:@"msauth"] || [scheme isEqualToString:@"browser"]) {
        // Transfer headers to state
        self.stateMachine.state.responseHeaders = self.lastResponseHeaders;
        
        // Handle via state machine
        __weak typeof(self) weakSelf = self;
        [self.stateMachine handleSpecialURL:url 
                           navigationAction:navigationAction 
                                 completion:^(MSIDWebviewAction *action, NSError *error) {
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            
            if (error) {
                [strongSelf endWebAuthWithURL:nil error:error];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            
            [strongSelf executeViewAction:action decisionHandler:decisionHandler];
        }];
        return;
    }
    
    // Normal navigation
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)executeViewAction:(MSIDWebviewAction *)action 
          decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    switch (action.type) {
        case MSIDWebviewActionTypeNoop:
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Executing Noop action");
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeLoadRequestInWebview:
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Loading request in webview");
            [self.webView loadRequest:action.request];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeOpenASWebAuthenticationSession:
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                             @"Opening ASWebAuthenticationSession for purpose: %ld", (long)action.purpose);
            [self openSystemWebviewWithURL:action.url 
                                   purpose:action.purpose 
                         additionalHeaders:action.additionalHeaders];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeOpenExternalBrowser:
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Opening external browser");
            [[UIApplication sharedApplication] openURL:action.url options:@{} completionHandler:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeCompleteWithURL:
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Completing with URL");
            [self completeWebAuthWithURL:action.url];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        case MSIDWebviewActionTypeFailWithError:
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Failing with error: %@", action.error);
            [self endWebAuthWithURL:nil error:action.error];
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
            
        default:
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, @"Unknown action type: %ld", (long)action.type);
            decisionHandler(WKNavigationActionPolicyCancel);
            break;
    }
}

@end
```

### Example: Full Handler Implementation

```objc
@interface MSIDLocalInteractiveController () <MSIDInteractiveWebviewHandler>
@property (nonatomic, strong) MSIDBrokerInteractiveController *brokerController;
@end

@implementation MSIDLocalInteractiveController

#pragma mark - MSIDInteractiveWebviewHandler

- (BOOL)isRunningInBrokerContext
{
    return [MSIDBrokerKeyProvider applicationIsCapableOfBrokerCommunication];
}

- (BOOL)shouldAcquireBRTForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Implement BRT policy
    return state.brtGateEncountered && !state.brtAttempted;
}

- (MSIDWebviewBRTFailurePolicy)brtFailurePolicyForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    return MSIDWebviewBRTFailurePolicyContinue;
}

- (BOOL)shouldRetryInBrokerForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Retry for profileComplete if not in broker
    if ([url.host.lowercaseString isEqualToString:@"profilecomplete"]) {
        return ![self isRunningInBrokerContext] && !state.transferredToBroker;
    }
    return NO;
}

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    // Implement BRT acquisition
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Acquiring BRT token");
    
    // TODO: Actual BRT implementation
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(YES, nil);
    });
}

- (NSError *)genericBrtError
{
    return MSIDCreateError(MSIDErrorDomain, 
                          MSIDErrorInternal, 
                          @"BRT acquisition failed", 
                          nil, nil, nil, nil, nil, NO);
}

- (void)retryInteractiveRequestInBrokerContextForURL:(NSURL *)url 
                                          completion:(void (^)(BOOL success, NSError *error))completion
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                     @"Retrying interactive request in broker context for URL: %@", url);
    
    // Create broker controller if needed
    if (!self.brokerController) {
        self.brokerController = [[MSIDBrokerInteractiveController alloc] 
                                 initWithInteractiveRequestParameters:self.requestParameters
                                 commonRequestParameters:self.commonParameters
                                 tokenRequestProvider:self.tokenRequestProvider];
    }
    
    // Transfer to broker
    [self.brokerController acquireToken:^(MSIDTokenResult *result, NSError *error) {
        if (error) {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, self.context, 
                                 @"Broker retry failed: %@", MSID_PII_LOG_MASKABLE(error));
            completion(NO, error);
        } else {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                             @"Broker retry succeeded");
            completion(YES, nil);
        }
    }];
}

- (void)dismissEmbeddedWebviewIfPresent
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, @"Dismissing embedded webview");
    
    if (self.embeddedWebviewController) {
        [self.embeddedWebviewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (MSIDWebviewAction *)viewActionForSpecialURL:(NSURL *)url state:(MSIDInteractiveWebviewState *)state
{
    // Delegate to resolver
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
}

- (void)handleWebviewResponseForTelemetry:(NSHTTPURLResponse *)response
{
    // Process telemetry headers
    NSString *telemetry = response.allHeaderFields[@"X-MS-Telemetry"];
    if (telemetry) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                         @"Processing telemetry: %@", telemetry);
        // Parse and process telemetry data
    }
}

@end
```

---

## Testing

### Unit Tests for Components

#### Test State Machine
```objc
- (void)testStateMachine_installProfileURL_callsHandlerCorrectly
{
    // Mock handler
    id<MSIDInteractiveWebviewHandler> mockHandler = [OCMockObject mockForProtocol:@protocol(MSIDInteractiveWebviewHandler)];
    
    MSIDInteractiveWebviewStateMachine *stateMachine = [[MSIDInteractiveWebviewStateMachine alloc] 
                                                        initWithHandler:mockHandler];
    
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://example.com&requireASWebAuth=true"];
    
    // Set expectations
    [[[mockHandler expect] andReturnValue:@NO] isRunningInBrokerContext];
    [[[mockHandler expect] andReturnValue:@NO] shouldAcquireBRTForSpecialURL:url state:[OCMArg any]];
    [[[mockHandler expect] andReturn:[MSIDWebviewAction noopAction]] viewActionForSpecialURL:url state:[OCMArg any]];
    
    // Execute
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];
    [stateMachine handleSpecialURL:url 
                  navigationAction:nil 
                        completion:^(MSIDWebviewAction *action, NSError *error) {
        XCTAssertNotNil(action);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [mockHandler verify];
}
```

#### Test Resolver
```objc
- (void)testResolver_installProfileWithHeaders_extractsCorrectly
{
    MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
    state.responseHeaders = @{
        @"X-Install-Url": @"https://actual.url.com",
        @"X-Intune-AuthToken": @"token123"
    };
    
    NSURL *url = [NSURL URLWithString:@"msauth://installProfile?url=https://fallback.url&requireASWebAuth=true"];
    
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:state];
    
    XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
    XCTAssertEqualObjects(action.url.absoluteString, @"https://actual.url.com");
    XCTAssertEqualObjects(action.additionalHeaders[@"X-Intune-AuthToken"], @"token123");
    XCTAssertEqual(action.purpose, MSIDSystemWebviewPurposeInstallProfile);
}
```

### Integration Tests

#### Test Full Flow
```objc
- (void)testFullFlow_installProfileToProfileComplete
{
    // Setup
    MSIDLocalInteractiveController *controller = [[MSIDLocalInteractiveController alloc] init...];
    MSIDOAuth2EmbeddedWebviewController *webviewController = controller.embeddedWebviewController;
    
    // Simulate installProfile response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] 
        initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com"]
        statusCode:302
        HTTPVersion:@"HTTP/1.1"
        headerFields:@{
            @"Location": @"msauth://installProfile?url=https://backup&requireASWebAuth=true",
            @"X-Install-Url": @"https://portal.manage.microsoft.com/...",
            @"X-Intune-AuthToken": @"eyJ0eXAi..."
        }];
    
    // Trigger header capture
    webviewController.responseHeaderHandler(response);
    
    // Trigger navigation
    NSURL *installProfileURL = [NSURL URLWithString:@"msauth://installProfile?url=https://backup&requireASWebAuth=true"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Action executed"];
    [webviewController.stateMachine handleSpecialURL:installProfileURL 
                                    navigationAction:nil 
                                          completion:^(MSIDWebviewAction *action, NSError *error) {
        // Verify action
        XCTAssertEqual(action.type, MSIDWebviewActionTypeOpenASWebAuthenticationSession);
        XCTAssertEqualObjects(action.url.host, @"portal.manage.microsoft.com");
        XCTAssertNotNil(action.additionalHeaders[@"X-Intune-AuthToken"]);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
```

---

## Troubleshooting

### Issue: Headers Not Captured

**Symptoms**: `state.responseHeaders` is nil or empty

**Checks**:
1. Verify `responseHeaderHandler` is set in factory/init
2. Check `decidePolicyForNavigationResponse` calls handler
3. Verify `lastResponseHeaders` is populated
4. Ensure headers transferred to state before `handleSpecialURL`
5. Check response is `NSHTTPURLResponse` (not just `NSURLResponse`)

**Debug**:
```objc
// Add logging
MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, 
                 @"Response headers: %@", httpResponse.allHeaderFields);
```

### Issue: State Machine Not Called

**Symptoms**: Special URLs not intercepted

**Checks**:
1. Verify state machine initialized in webview controller
2. Check `decidePolicyForNavigationAction` detects special URLs
3. Verify scheme comparison is case-insensitive
4. Ensure completion callback is invoked

**Debug**:
```objc
// Add logging
MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                 @"Navigation to URL: %@ scheme: %@", url, url.scheme);
```

### Issue: Wrong URL Used for InstallProfile

**Symptoms**: Opens backup URL instead of X-Install-Url

**Checks**:
1. Verify headers present in state when resolver called
2. Check header key is exactly "X-Install-Url" (case-sensitive)
3. Verify URL string is valid and parseable
4. Check priority logic in resolver

**Debug**:
```objc
// Add logging in resolver
MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                 @"Headers: %@, X-Install-Url: %@", headers, headers[@"X-Install-Url"]);
```

### Issue: ASWebAuthenticationSession Not Opening

**Symptoms**: Action created but nothing happens

**Checks**:
1. Verify `executeViewAction:` handles `OpenASWebAuthenticationSession` case
2. Check `openSystemWebviewWithURL:` implementation
3. Verify ASWebAuth properly initialized and started
4. Check for permission issues (iOS 13+ ephemeral sessions)

**Debug**:
```objc
// Add logging
MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                 @"Opening ASWebAuth with URL: %@ purpose: %ld", url, (long)purpose);
```

### Issue: Broker Retry Not Triggering

**Symptoms**: `profileComplete` doesn't retry in broker

**Checks**:
1. Verify `shouldRetryInBrokerForSpecialURL:` returns YES
2. Check `isRunningInBrokerContext` returns correct value
3. Verify `state.transferredToBroker` is NO initially
4. Check broker controller properly initialized

**Debug**:
```objc
// Add logging in handler
MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                 @"Broker context: %d, transferred: %d, shouldRetry: %d",
                 [self isRunningInBrokerContext], 
                 state.transferredToBroker,
                 [self shouldRetryInBrokerForSpecialURL:url state:state]);
```

---

## Summary

This framework provides a clean, extensible architecture for handling special URLs in embedded webviews:

✅ **Separation of Concerns**: Controller actions vs. view actions  
✅ **State Machine**: Manages complex async flows  
✅ **Protocol-Based**: Flexible handler implementation  
✅ **Header Support**: Captures and uses HTTP response headers  
✅ **Intune Compatible**: Full support for device enrollment flow  
✅ **Telemetry Ready**: Headers available for diagnostic purposes  
✅ **Broker Integration**: Seamless retry in broker context  
✅ **Testable**: Comprehensive unit and integration test support  

**Current Status**: ✅ Framework complete, ⏳ Wiring needed for production

**Next Steps**: Follow the [Production Wiring Checklist](#production-wiring-checklist) to integrate into your authentication flow.

---

**For questions or issues, please refer to the component documentation in:**
- `MSIDWebviewAction.h`
- `MSIDInteractiveWebviewState.h`
- `MSIDInteractiveWebviewHandler.h`
- `MSIDInteractiveWebviewStateMachine.h`
- `MSIDSpecialURLViewActionResolver.h`
